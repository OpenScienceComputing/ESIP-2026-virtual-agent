#!/usr/bin/env bash
# Set up Claude Code (via AWS Bedrock) + the Jupyter MCP server in a
# coiled-hosted JupyterLab terminal for the ESIP 2026 virtual-agent breakout.
#
# Run this from a terminal INSIDE the JupyterLab launched by
# `coiled notebook start ...`, from within a clone of this repo:
#
#   export BEDROCK_ACCESS_KEY_ID=<shared key id, announced at the event>
#   export BEDROCK_SECRET_ACCESS_KEY=<shared secret key, announced at the event>
#   export JUPYTER_LAB_TOKEN=<the ?token=... value from the browser tab coiled notebook start opened>
#   bash setup_claude_agent.sh
#
# Never hardcode the Bedrock credentials in this file (or any other
# repo-tracked file) - they're read from the environment and written only to
# ~/.profile, which lives outside the repo and is never committed.
#
# On Coiled, Jupyter runs embedded inside the Dask scheduler process itself
# (dask/distributed's `jupyter=True` scheduler option), reachable only
# through Coiled's external https://cluster-xxxx.dask.host/jupyter/ proxy -
# there's no local jupyter-lab/jupyter-server process or runtime connection
# file to discover from inside a terminal. The embedded server itself has no
# token of its own (dask/distributed sets `"token": ""`, relying on Coiled's
# proxy for access control), but the proxy issues its own token, visible in
# the URL Coiled opens in your browser (or via `cluster.jupyter_link` from
# the coiled Python client on your local machine).

set -euo pipefail

if [[ -z "${BEDROCK_ACCESS_KEY_ID:-}" || -z "${BEDROCK_SECRET_ACCESS_KEY:-}" || -z "${JUPYTER_LAB_TOKEN:-}" ]]; then
  echo "ERROR: set BEDROCK_ACCESS_KEY_ID, BEDROCK_SECRET_ACCESS_KEY, and JUPYTER_LAB_TOKEN first, e.g.:" >&2
  echo "  export BEDROCK_ACCESS_KEY_ID=..." >&2
  echo "  export BEDROCK_SECRET_ACCESS_KEY=..." >&2
  echo "  export JUPYTER_LAB_TOKEN=...   # from the browser URL: .../jupyter/lab?token=THIS_PART" >&2
  echo "  bash setup_claude_agent.sh" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 0/4 Making sure new terminals land in the 'base' conda environment"
CONDA_BASE="$(conda info --base 2>/dev/null || true)"
if [[ -n "$CONDA_BASE" && -f "$CONDA_BASE/etc/profile.d/conda.sh" ]]; then
  # shellcheck disable=SC1091
  source "$CONDA_BASE/etc/profile.d/conda.sh"
  if ! grep -q "conda initialize" "$HOME/.bashrc" 2>/dev/null; then
    conda init bash > /dev/null
    echo "    Ran 'conda init bash' - new terminals will have 'conda activate' available."
  fi
  # conda init alone only auto-activates base if this setting is on - some
  # cloud images ship with it off, so new terminals would still start bare.
  conda config --set auto_activate_base true
  conda activate base
  echo "    'base' conda env is active here, and new terminals will auto-activate it too."
else
  echo "    No conda found on PATH - skipping (this step is a nice-to-have, not required for the rest of this script)."
fi

echo "==> 1/4 Writing Bedrock + Claude Code config to ~/.bashrc and ~/.profile"
# ~/.bashrc: sourced by the non-login interactive shells JupyterLab terminals
# spawn - this is what makes new terminals "just work" without a manual step.
# ~/.profile: sourced by login shells (e.g. SSH'ing in directly) - kept too,
# belt-and-suspenders, in case attendees use this repo outside JupyterLab.
PROFILE_MARKER_BEGIN="# --- ESIP-2026-virtual-agent: Claude Code via Bedrock (begin) ---"
PROFILE_MARKER_END="# --- ESIP-2026-virtual-agent: Claude Code via Bedrock (end) ---"
for RC_FILE in "$HOME/.bashrc" "$HOME/.profile"; do
  if grep -qF "$PROFILE_MARKER_BEGIN" "$RC_FILE" 2>/dev/null; then
    echo "    Already configured in $RC_FILE, skipping (edit that file directly to change it)."
  else
    cat >> "$RC_FILE" << EOF

$PROFILE_MARKER_BEGIN
export PATH="\$HOME/.local/bin:\$PATH"
export AWS_ACCESS_KEY_ID="$BEDROCK_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$BEDROCK_SECRET_ACCESS_KEY"
export AWS_REGION=us-west-2
export CLAUDE_CODE_USE_BEDROCK=1
# NOTE: this must be a current Bedrock cross-region inference profile id, not
# an Anthropic model name - check the AWS Bedrock console close to the event
# date, these ids change as new models ship.
export ANTHROPIC_DEFAULT_SONNET_MODEL=us.anthropic.claude-sonnet-4-6
$PROFILE_MARKER_END
EOF
  fi
done
# shellcheck disable=SC1090,SC1091
source "$HOME/.bashrc"

# Also write ~/.aws/credentials (not just shell env vars). This matters
# because the Jupyter kernel notebooks actually execute in was already
# running before this script ran - it never sourced ~/.bashrc, so it can't
# see AWS_ACCESS_KEY_ID/SECRET set above. boto3/obstore/icechunk etc. all
# re-read ~/.aws/credentials on every call (unlike env vars, which are fixed
# at process start), and it's checked before the VM's own EC2 instance role
# in the default credential chain - so this covers the kernel too, no matter
# when it started.
mkdir -p "$HOME/.aws"
AWS_MARKER_BEGIN="# --- ESIP-2026-virtual-agent: bedrock-class credentials (begin) ---"
AWS_MARKER_END="# --- ESIP-2026-virtual-agent: bedrock-class credentials (end) ---"
if grep -qF "$AWS_MARKER_BEGIN" "$HOME/.aws/credentials" 2>/dev/null; then
  echo "    Already configured in ~/.aws/credentials, skipping (edit that file directly to change it)."
else
  cat >> "$HOME/.aws/credentials" << EOF

$AWS_MARKER_BEGIN
[default]
aws_access_key_id = $BEDROCK_ACCESS_KEY_ID
aws_secret_access_key = $BEDROCK_SECRET_ACCESS_KEY
$AWS_MARKER_END
EOF
fi
if ! grep -qF "$AWS_MARKER_BEGIN" "$HOME/.aws/config" 2>/dev/null; then
  cat >> "$HOME/.aws/config" << EOF

$AWS_MARKER_BEGIN
[default]
region = us-west-2
$AWS_MARKER_END
EOF
fi

echo "==> 2/4 Installing Claude Code (native installer, no Node.js needed)"
curl -fsSL https://claude.ai/install.sh | bash

echo "==> 3/4 Installing jupyter-mcp-server and registering it for this repo"

# jupyter-mcp-server is a pure network client (HTTP/websocket to JUPYTER_URL)
# - it doesn't need to run in the same env/process as the Jupyter server, so
# just install it into whatever's active here (base, per AGENTS.md).
pip install --quiet jupyter-mcp-server

# Derive the external Coiled proxy hostname (https://cluster-xxxx.dask.host)
# from the dashboard link env var Coiled sets on the VM; the embedded
# Jupyter server is only reachable through this proxy, not locally.
if [[ -z "${DASK_DISTRIBUTED__DASHBOARD__LINK:-}" ]]; then
  echo "ERROR: DASK_DISTRIBUTED__DASHBOARD__LINK is not set - can't derive the cluster's external URL. Are you on a coiled notebook VM?" >&2
  exit 1
fi
CLUSTER_HOST="$(grep -oE 'https://[^/]+' <<< "$DASK_DISTRIBUTED__DASHBOARD__LINK" | head -1)"
JUPYTER_URL="${CLUSTER_HOST}/jupyter/"
JUPYTER_TOKEN="$JUPYTER_LAB_TOKEN"
MCP_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
JUPYTER_MCP_BIN="$(command -v jupyter-mcp-server)"

echo "    Jupyter URL: $JUPYTER_URL"

# NOTE: verify this against the currently-installed jupyter-mcp-server's own
# --help/docs before the event - its env var names and required MCP_TOKEN
# handshake have changed across recent releases.
cat > "$REPO_ROOT/.mcp.json" << EOF
{
  "mcpServers": {
    "jupyter": {
      "command": "$JUPYTER_MCP_BIN",
      "env": {
        "JUPYTER_URL": "$JUPYTER_URL",
        "JUPYTER_TOKEN": "$JUPYTER_TOKEN",
        "MCP_TOKEN": "$MCP_TOKEN",
        "ALLOW_IMG_OUTPUT": "true"
      }
    }
  }
}
EOF
echo "    Wrote $REPO_ROOT/.mcp.json (git-ignored - contains a live Jupyter token)"

echo "==> 4/4 Done"
echo
echo "The icechunk-datacube-ingestion skill is already available in this repo"
echo "at .claude/skills/ - no separate install step needed."
echo
echo "Next steps:"
echo "  Open a new terminal (it'll pick up ~/.bashrc automatically), or run 'source ~/.bashrc' in this one, then:"
echo "  cd $REPO_ROOT"
echo "  claude"
