#!/usr/bin/env bash
# Set up Claude Code (via AWS Bedrock) on a SkyPilot-launched notebook VM
# for the ESIP 2026 virtual-agent breakout.
#
# notebook.sky.yaml already runs this automatically during VM setup, using
# the same AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY passed to `sky launch`
# via --env - attendees don't need to run this by hand. It's here as a
# standalone script mainly for manual re-runs/troubleshooting. To run it
# yourself, from ~/sky_workdir (this repo) on the VM:
#
#   export AWS_ACCESS_KEY_ID=<shared key id, announced at the event>
#   export AWS_SECRET_ACCESS_KEY=<shared secret key, announced at the event>
#   bash setup_claude_agent.sh
#
# Never hardcode these credentials in this file (or any other repo-tracked
# file) - they're read from the environment and written only to ~/.profile,
# ~/.bashrc, and ~/.aws/, none of which live in the repo or get committed.
#
# Claude Code edits .ipynb files with its built-in NotebookEdit tool, and
# verifies them with `jupyter nbconvert --execute` (see AGENTS.md), rather
# than a live Jupyter MCP connection - kept simple/proven for this workshop.

set -euo pipefail

if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo "ERROR: set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY first, e.g.:" >&2
  echo "  export AWS_ACCESS_KEY_ID=..." >&2
  echo "  export AWS_SECRET_ACCESS_KEY=..." >&2
  echo "  bash setup_claude_agent.sh" >&2
  exit 1
fi

echo "==> 0/3 Making sure new terminals can find the esip2026 Python environment"
# notebook.sky.yaml creates a micromamba environment named 'esip2026' during
# setup - put its bin/ on PATH so a bare python/pip/jupyter resolves to it.
ENV_BIN="$HOME/micromamba/envs/esip2026/bin"
if [[ -d "$ENV_BIN" ]]; then
  echo "    Found the environment at $ENV_BIN"
else
  echo "    WARNING: $ENV_BIN not found - was this VM launched from notebook.sky.yaml?" >&2
  ENV_BIN=""
fi
ENV_BIN_PREFIX=""
[[ -n "$ENV_BIN" ]] && ENV_BIN_PREFIX="$ENV_BIN:"

echo "==> 1/3 Writing Bedrock + Claude Code config to ~/.bashrc and ~/.profile"
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
export PATH="\$HOME/.local/bin:$ENV_BIN_PREFIX\$PATH"
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
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
# Don't rely on `source ~/.bashrc` alone - most .bashrc templates early-return
# for non-interactive shells, which this script may be running as (e.g. when
# notebook.sky.yaml's setup: step calls it). Export PATH directly too, so the
# Claude Code install below sees it regardless of execution context.
export PATH="$HOME/.local/bin:$ENV_BIN_PREFIX$PATH"

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
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
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

echo "==> 2/3 Installing Claude Code (native installer, no Node.js needed)"
curl -fsSL https://claude.ai/install.sh | bash

echo "==> 3/3 Done"
echo
echo "The icechunk-datacube-ingestion skill is already available in this repo"
echo "at .claude/skills/ - no separate install step needed."
echo
echo "Next steps:"
echo "  Open a new terminal - SSH in again, or use the JupyterLab launcher's Terminal tile - then:"
echo "  cd ~/sky_workdir"
echo "  claude"
