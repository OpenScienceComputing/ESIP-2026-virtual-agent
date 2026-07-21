#!/usr/bin/env bash
# Passed to `coiled notebook start --host-setup-script host_setup.sh`.
# Coiled runs this ON THE VM during its setup process, before anyone opens a
# terminal - it just pre-clones this repo so attendees skip a manual `git
# clone` step. It intentionally does NOT touch Claude Code, Bedrock, or the
# Jupyter MCP server (see setup_claude_agent.sh for that) - JupyterLab isn't
# necessarily up yet at this point in VM setup, so anything that depends on
# a running Jupyter server has to stay a step attendees run themselves,
# after they have a terminal open.

set -euo pipefail

REPO_DIR="$HOME/ESIP-2026-virtual-agent"

if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" pull --ff-only
else
  git clone https://github.com/OpenScienceComputing/ESIP-2026-virtual-agent.git "$REPO_DIR"
fi
