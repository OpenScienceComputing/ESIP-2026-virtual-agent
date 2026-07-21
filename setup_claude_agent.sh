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
pip install --quiet jupyter-mcp-server

JUPYTER_INFO="$(python3 - << 'PY'
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
)" || { echo "ERROR: could not detect a running Jupyter server - run this from a JupyterLab terminal." >&2; exit 1; }

JUPYTER_URL="$(sed -n '1p' <<< "$JUPYTER_INFO")"
JUPYTER_TOKEN="$(sed -n '2p' <<< "$JUPYTER_INFO")"
MCP_TOKEN="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"

# NOTE: verify this against the currently-installed jupyter-mcp-server's own
# --help/docs before the event - its env var names and required MCP_TOKEN
# handshake have changed across recent releases.
cat > "$REPO_ROOT/.mcp.json" << EOF
{
  "mcpServers": {
    "jupyter": {
      "command": "jupyter-mcp-server",
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
