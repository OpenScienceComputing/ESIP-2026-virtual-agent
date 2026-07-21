# ESIP-2026-virtual-agent

Notebooks and scripts supporting a breakout group at the ESIP 2026 Summer Meeting, where participants will use agentic coding to create workflows that build virtual Icechunk and Arraylake datasets.

**Date:** Tuesday, July 28, 2026

> Note: the shared Coiled group token in `.secrets/` expires ~2026-07-31, so it's valid through the event — no need to regenerate.

## Overview

You'll run a remote JupyterLab server on AWS via [Coiled](https://www.coiled.io/), then use [Claude Code](https://claude.com/claude-code) from a terminal inside that JupyterLab — routed through AWS Bedrock, billed via ESIP's AWS credits — to build a notebook that virtualizes a collection of NetCDF, GeoTIFF, or GRIB files into an Icechunk or Arraylake store.

## Prerequisites

- A Linux machine (or WSL, or macOS) — your own laptop, or a GitHub Codespace — with `conda` (or `mamba`/`miniforge`) installed. GitHub Codespaces' default image already includes conda, so nothing to install there.
- The shared Coiled group token and shared Bedrock AWS credentials, both announced at the start of the breakout — don't share or commit them.

**No conda?** Install [micromamba](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html) instead (Linux/WSL/macOS):

```bash
"${SHELL}" <(curl -L https://micro.mamba.pm/install.sh)
```

Accept shell initialization when prompted, then open a new terminal. Everywhere below that says `conda create`/`conda activate`, substitute `micromamba create`/`micromamba activate`.

### Don't have a Linux/WSL/macOS machine? Use a GitHub Codespace

1. Go to this repo on GitHub: https://github.com/OpenScienceComputing/ESIP-2026-virtual-agent
2. Click the green **Code** button → **Codespaces** tab → **Create codespace on main**.
3. Wait for it to build, then open a terminal in the Codespace (it's a full Linux environment with conda preinstalled — see above) and continue with Step 1 below.

(Or, with the [`gh` CLI](https://cli.github.com/) installed locally: `gh codespace create --repo OpenScienceComputing/ESIP-2026-virtual-agent && gh codespace code`.)

## Step 1 — Install and authenticate Coiled

```bash
conda create -n coiled -c conda-forge coiled -y
conda activate coiled
coiled login --token <group-api-token>
```

This will print a one-time device-authorization link like:

```
Visit the following page to authorize this computer:
  https://cloud.coiled.io/activate-token?id=...
Validation code: ...
```

Open that link, confirm, and it saves credentials to `~/.config/dask/coiled.yaml` — this only happens once per machine/Codespace, not on every command.

## Step 2 — Launch a remote JupyterLab on AWS

```bash
coiled notebook start --region us-west-2 --vm-type m5.xlarge --workspace esip-lab --disk-size 50GB --software esip-notebook
```

## Step 3 — Clone this repo

In a terminal inside the JupyterLab that just opened:

```bash
git clone https://github.com/OpenScienceComputing/ESIP-2026-virtual-agent.git
cd ESIP-2026-virtual-agent
```

## Step 4 — Set up Claude Code

Still in that terminal:

```bash
export BEDROCK_ACCESS_KEY_ID=<shared key id, announced at the event>
export BEDROCK_SECRET_ACCESS_KEY=<shared secret key, announced at the event>
bash setup_claude_agent.sh
source ~/.profile
claude
```

This installs Claude Code, points it at AWS Bedrock, installs the [Jupyter MCP server](https://github.com/datalayer/jupyter-mcp-server) so Claude Code can read/edit/execute cells against your live JupyterLab kernel, and generates a `.mcp.json` for this repo (not committed — it holds a live Jupyter token). See `setup_claude_agent.sh` for details.

## Step 5 — Build your virtual dataset

Look at [`examples/taranto-icechunk-append.ipynb`](examples/taranto-icechunk-append.ipynb) for a worked example of a real virtual Icechunk workflow (create-or-append, date-diffing, per-file normalization before concat). It targets a different workshop's storage, so read it for the pattern rather than running it directly — see [`examples/README.md`](examples/README.md).

Then, in `claude`, describe the NetCDF/GeoTIFF/GRIB collection you want to turn into a virtual Icechunk or Arraylake store. The `icechunk-datacube-ingestion` skill vendored in this repo (`.claude/skills/`, from [earth-mover/agent-skills](https://github.com/earth-mover/agent-skills)) will guide Claude Code through gathering requirements, scanning your data, planning the ingestion, and validating the result.

Write your Icechunk store under `s3://esip-qhub-public/esip2026-breakout/<your-name-or-dataset>/` — the shared `bedrock-class` credentials are scoped to write only under that prefix (reads are public bucket-wide).
