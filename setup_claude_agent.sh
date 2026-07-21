#!/usr/bin/env bash
# Set up Claude Code (via AWS Bedrock) + the Jupyter MCP server in a
# coiled-hosted JupyterLab terminal for the ESIP 2026 virtual-agent breakout.
#
# Run this from a terminal INSIDE the JupyterLab launched by
# `coiled notebook start ...`, from within a clone of this repo:
#
#   export BEDROCK_ACCESS_KEY_ID=<shared key id, announced at the event>
#   export BEDROCK_SECRET_ACCESS_KEY=<shared secret key, announced at the event>
#   bash setup_claude_agent.sh
#
# Never hardcode the Bedrock credentials in this file (or any other
# repo-tracked file) - they're read from the environment and written only to
# ~/.profile, which lives outside the repo and is never committed.

set -euo pipefail

if [[ -z "${BEDROCK_ACCESS_KEY_ID:-}" || -z "${BEDROCK_SECRET_ACCESS_KEY:-}" ]]; then
  echo "ERROR: set BEDROCK_ACCESS_KEY_ID and BEDROCK_SECRET_ACCESS_KEY first, e.g.:" >&2
  echo "  export BEDROCK_ACCESS_KEY_ID=..." >&2
  echo "  export BEDROCK_SECRET_ACCESS_KEY=..." >&2
  echo "  bash setup_claude_agent.sh" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 0/4 Making sure 'conda activate' works in JupyterLab terminals"
CONDA_BASE="$(conda info --base 2>/dev/null || true)"
if [[ -n "$CONDA_BASE" && -f "$CONDA_BASE/etc/profile.d/conda.sh" ]]; then
  # shellcheck disable=SC1091
  source "$CONDA_BASE/etc/profile.d/conda.sh"
  if ! grep -q "conda initialize" "$HOME/.bashrc" 2>/dev/null; then
    conda init bash > /dev/null
    echo "    Ran 'conda init bash' - new terminals will have 'conda activate' available (this one already does, via the sourced hook above)."
  fi
else
  echo "    No conda found on PATH - skipping (this step is a nice-to-have, not required for the rest of this script)."
fi

echo "==> 1/4 Writing Bedrock + Claude Code config to ~/.profile"
PROFILE_MARKER_BEGIN="# --- ESIP-2026-virtual-agent: Claude Code via Bedrock (begin) ---"
PROFILE_MARKER_END="# --- ESIP-2026-virtual-agent: Claude Code via Bedrock (end) ---"
if grep -qF "$PROFILE_MARKER_BEGIN" "$HOME/.profile" 2>/dev/null; then
  echo "    Already configured in ~/.profile, skipping (edit that file directly to change it)."
else
  cat >> "$HOME/.profile" << EOF

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
# shellcheck disable=SC1090
source "$HOME/.profile"

echo "==> 2/4 Installing Claude Code (native installer, no Node.js needed)"
curl -fsSL https://claude.ai/install.sh | bash

echo "==> 3/4 Installing jupyter-mcp-server and registering it for this repo"

# Don't trust whatever `python3` this terminal happens to resolve to - it may
# be a different conda env (or no env at all) than the one actually running
# JupyterLab, which is why server discovery could silently find nothing.
# Instead, find the running Jupyter process and resolve its *actual*
# interpreter via /proc, so pip/detection below definitely match the server.
JUPYTER_PID="$(pgrep -f 'jupyter-lab|jupyter-server|jupyter-notebook' | head -1 || true)"
if [[ -z "$JUPYTER_PID" ]]; then
  echo "ERROR: no running Jupyter process found (pgrep found nothing) - run this from a JupyterLab terminal." >&2
  exit 1
fi
JUPYTER_PYTHON="$(readlink -f "/proc/$JUPYTER_PID/exe")"
echo "    Found Jupyter server (pid $JUPYTER_PID), using its Python: $JUPYTER_PYTHON"

"$JUPYTER_PYTHON" -m pip install --quiet jupyter-mcp-server

JUPYTER_INFO="$("$JUPYTER_PYTHON" - << 'PY'
import sys
try:
    from jupyter_server.serverapp import list_running_servers
except ImportError:
    from notebook.notebookapp import list_running_servers

servers = list(list_running_servers())
if not servers:
    sys.exit("no running Jupyter server found")

s = servers[0]
host = s.get("hostname") or "127.0.0.1"
if host in ("0.0.0.0", "*", ""):
    host = "127.0.0.1"
print(f"http://{host}:{s['port']}")
print(s.get("token", ""))
PY
)" || { echo "ERROR: could not read the running Jupyter server's connection info." >&2; exit 1; }

JUPYTER_URL="$(sed -n '1p' <<< "$JUPYTER_INFO")"
JUPYTER_TOKEN="$(sed -n '2p' <<< "$JUPYTER_INFO")"
MCP_TOKEN="$("$JUPYTER_PYTHON" -c 'import secrets; print(secrets.token_hex(32))')"
# jupyter-mcp-server's console script lands next to the interpreter we used to pip-install it.
JUPYTER_MCP_BIN="$(dirname "$JUPYTER_PYTHON")/jupyter-mcp-server"

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
echo "  source ~/.profile"
echo "  claude"
