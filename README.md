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

Requires your own (free) GitHub account — the Codespace runs under your account and against your own free monthly Codespaces hours, not the repo owner's. Plenty for this workshop, just not unlimited.

1. Go to this repo on GitHub: https://github.com/OpenScienceComputing/ESIP-2026-virtual-agent
2. Click the green **Code** button → **Codespaces** tab → **Create codespace on main**.
3. Wait for it to build, then open a terminal in the Codespace (it's a full Linux environment with conda preinstalled — see above) and continue with Step 1 below.

(Or, with the [`gh` CLI](https://cli.github.com/) installed locally: `gh codespace create --repo OpenScienceComputing/ESIP-2026-virtual-agent && gh codespace code`.)

## Step 1 — Install and authenticate Coiled

```bash
conda create -n coiled -c conda-forge coiled -y
conda init bash
source ~/.bashrc
conda activate coiled
coiled login --token <group-api-token>
```

(`conda init bash` + `source ~/.bashrc` is a one-time step — a fresh shell won't let you `conda activate` at all otherwise, failing with something like "Your shell has not been properly configured to use 'conda activate'". You'll only need to do this once per machine/Codespace.)

This will print a one-time device-authorization link like:

```
Visit the following page to authorize this computer:
  https://cloud.coiled.io/activate-token?id=...
Validation code: ...
```

Open that link, confirm, and it saves credentials to `~/.config/dask/coiled.yaml` — this only happens once per machine/Codespace, not on every command.

## Step 2 — Launch a remote JupyterLab on AWS

First grab the setup script that pre-clones this repo onto the VM:

```bash
curl -O https://raw.githubusercontent.com/OpenScienceComputing/ESIP-2026-virtual-agent/main/host_setup.sh
```

Then launch, with a `--name` that identifies you — this is how we'll tell everyone's machines apart in the shared `esip-lab` workspace:

```bash
coiled notebook start --name <your-name>-esip2026 --region us-west-2 --vm-type m5.xlarge --workspace esip-lab --disk-size 50GB --software esip-notebook --host-setup-script host_setup.sh
```

## Step 3 — Open this repo

`--host-setup-script` should have already cloned this repo to `~/ESIP-2026-virtual-agent` on the VM before it even finished booting. In a terminal inside the JupyterLab that just opened:

```bash
cd ~/ESIP-2026-virtual-agent
```

If that directory doesn't exist (e.g. the host-setup step didn't run for some reason), just clone it yourself instead:

```bash
git clone https://github.com/OpenScienceComputing/ESIP-2026-virtual-agent.git ~/ESIP-2026-virtual-agent
cd ~/ESIP-2026-virtual-agent
```

## Step 4 — Set up Claude Code

First find your notebook's Jupyter token: look at the browser tab that opened automatically when you ran `coiled notebook start` — the URL looks like `https://cluster-xxxx.dask.host/jupyter/lab?token=THIS_PART`. Copy the part after `token=`.

(Why: on Coiled, Jupyter runs embedded inside the Dask scheduler process, reachable only through Coiled's external proxy — there's no local Jupyter process or token to auto-detect from inside a terminal.)

Then, still in that terminal:

```bash
export BEDROCK_ACCESS_KEY_ID=<shared key id, announced at the event>
export BEDROCK_SECRET_ACCESS_KEY=<shared secret key, announced at the event>
export JUPYTER_LAB_TOKEN=<the token you just copied>
bash setup_claude_agent.sh
source ~/.bashrc
cd ~/ESIP-2026-virtual-agent   # if you opened a new terminal, you'll need this to get back here
claude
```

`claude` must be run from inside this repo, not your home directory — that's what makes it pick up this repo's `CLAUDE.md`, `.claude/skills/`, and `.mcp.json`.

This installs Claude Code, points it at AWS Bedrock, writes the `bedrock-class` credentials to `~/.aws/credentials` (so notebook code you run — not just Claude Code itself — can write to S3 with them, ahead of the VM's own instance role), installs the [Jupyter MCP server](https://github.com/datalayer/jupyter-mcp-server) so Claude Code can read/edit/execute cells against your live JupyterLab kernel, and generates a `.mcp.json` for this repo (not committed — it holds a live Jupyter token). See `setup_claude_agent.sh` for details.

## Step 5 — Build your virtual dataset

Look at [`examples/taranto-icechunk-append.ipynb`](examples/taranto-icechunk-append.ipynb) for a worked example of a real virtual Icechunk workflow (create-or-append, date-diffing, per-file normalization before concat). It targets a different workshop's storage, so read it for the pattern rather than running it directly — see [`examples/README.md`](examples/README.md).

Then, in `claude`, describe the NetCDF/GeoTIFF/GRIB collection you want to turn into a virtual Icechunk or Arraylake store. The `icechunk-datacube-ingestion` skill vendored in this repo (`.claude/skills/`, from [earth-mover/agent-skills](https://github.com/earth-mover/agent-skills)) will guide Claude Code through gathering requirements, scanning your data, planning the ingestion, and validating the result.

Sample prompt to get started:

> Let's create a virtual icechunk dataset for the NOAA CDR NDVI data on AWS Open Data. Let's start with just a few files as a smoke test. I'd like others to be able to open the icechunk.

## Beyond this workshop

For your own future scientific work, also check out [Claude Science](https://claude.com/product/claude-science), Anthropic's AI workbench for research (databases, compute, and reusable skills for genomics, proteomics, structural biology, and more). It's a different product from Claude Code — built for Claude.ai Pro/Max/Team/Enterprise plans rather than the Bedrock-billed setup used here — so it's not part of this breakout, but worth knowing about.

Write your Icechunk store under `s3://esip-qhub-public/esip2026-breakout/<your-name-or-dataset>/` — the shared `bedrock-class` credentials are scoped to write only under that prefix (reads are public bucket-wide).
