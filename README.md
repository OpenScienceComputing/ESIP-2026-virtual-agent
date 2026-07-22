# ESIP-2026-virtual-agent

Notebooks and scripts supporting a breakout group at the ESIP 2026 Summer Meeting, where participants will use agentic coding to create workflows that build virtual Icechunk and Arraylake datasets.

**Date:** Tuesday, July 28, 2026

> Note: the shared Coiled group token in `.secrets/` expires ~2026-07-31, so it's valid through the event — no need to regenerate.

## Overview

You'll run a remote JupyterLab server on AWS via [Coiled](https://www.coiled.io/), then use [Claude Code](https://claude.com/claude-code) from a terminal inside that JupyterLab — routed through AWS Bedrock, billed via ESIP's AWS credits — to build a notebook that virtualizes a collection of NetCDF, GeoTIFF, or GRIB files into an Icechunk or Arraylake store.

## Prerequisites

- A Linux machine (or WSL, or macOS) — your own laptop, or a GitHub Codespace — with Python 3 and `pip`. Virtually every machine already has this; no conda/mamba needed for this step.
- The shared Coiled group token and shared Bedrock AWS credentials, both announced at the start of the breakout — don't share or commit them.

### Don't have a Linux/WSL/macOS machine? Use a GitHub Codespace

Requires your own (free) GitHub account — the Codespace runs under your account and against your own free monthly Codespaces hours, not the repo owner's. Plenty for this workshop, just not unlimited.

1. Go to this repo on GitHub: https://github.com/OpenScienceComputing/ESIP-2026-virtual-agent
2. Click the green **Code** button → **Codespaces** tab → **Create codespace on main**.
3. Wait for it to build, then open a terminal in the Codespace and continue with Step 1 below.

(Or, with the [`gh` CLI](https://cli.github.com/) installed locally: `gh codespace create --repo OpenScienceComputing/ESIP-2026-virtual-agent && gh codespace code`.)

## Step 1 — Install and authenticate Coiled

```bash
python3 -m pip install --user coiled
export PATH="$HOME/.local/bin:$PATH"
export DASK_COILED__TOKEN=<group-api-token>
```

`pip install` here is deliberate — a `conda create -c conda-forge coiled` install works too, but conda's dependency solve can take several minutes (especially on Codespaces), where `pip install` finishes in seconds since `coiled` is a plain Python package. The `export PATH` line only applies to your current terminal; add it to `~/.bashrc`/`~/.profile` if you want it to persist across new terminals, or just re-run it each time.

`export DASK_COILED__TOKEN=...` alone is enough to authenticate — no `coiled login` step needed.

## Step 2 — Launch a remote JupyterLab on AWS

Give it a `--name` that identifies you — this is how we'll tell everyone's machines apart in the shared `esip-lab` workspace.

Pick `--region` based on where your source data lives — `us-east-1` for most AWS Open Data (including the NOAA CDR sample data below), `us-west-2` if you're working with `esip-qhub-public`. Either works; matching region to data avoids cross-region latency/egress:

```bash
coiled notebook start --name <your-name>-esip2026 --region us-east-1 --vm-type m5.xlarge --workspace esip-lab --disk-size 50GB --software esip-notebook
```

The first time you actually launch a VM from a given machine, Coiled prints a one-time device-authorization link, even though the group token itself is already active:

```
Visit the following page to authorize this computer:
  https://cloud.coiled.io/activate-token?id=...
Validation code: ...
```

Open it and confirm — this is per-machine, not per-command, so it won't happen again on this same machine.

(Swap `--region us-west-2` if that's where your data is.)

## Step 3 — Clone this repo

In the JupyterLab launcher that just opened, select Terminal:

```bash
git clone https://github.com/OpenScienceComputing/ESIP-2026-virtual-agent.git
cd ESIP-2026-virtual-agent
```

## Step 4 — Set up Claude Code

```bash
export BEDROCK_ACCESS_KEY_ID=<shared key id, announced at the event>
export BEDROCK_SECRET_ACCESS_KEY=<shared secret key, announced at the event>
bash setup_claude_agent.sh
```

Then **close this terminal and open a new one from the JupyterLab launcher** — that's what picks up everything the script just configured. In the new terminal:

```bash
cd ESIP-2026-virtual-agent
claude
```

`claude` must be run from inside this repo, not your home directory — that's what makes it pick up this repo's `CLAUDE.md` and `.claude/skills/`.

This installs Claude Code, points it at AWS Bedrock, and writes the `bedrock-class` credentials to `~/.aws/credentials` (so notebook code you run — not just Claude Code itself — can write to S3 with them, ahead of the VM's own instance role). See `setup_claude_agent.sh` for details.

Claude Code edits `.ipynb` files with its built-in notebook-editing tool and runs them with `jupyter nbconvert --execute` to verify real outputs (see `CLAUDE.md`/`AGENTS.md`) — there's no live Jupyter MCP connection on these VMs. Coiled runs Jupyter embedded inside the Dask scheduler process, reachable only through a per-cluster external proxy with its own token, which wasn't worth the reliability cost for this workshop.

## Step 5 — Build your virtual dataset

Look at [`examples/taranto-icechunk-append.ipynb`](examples/taranto-icechunk-append.ipynb) (and the script-form [`taranto-icechunk-tubitak-append.py`](examples/taranto-icechunk-tubitak-append.py)) for a worked example of a real virtual Icechunk workflow (create-or-append, date-diffing, per-file normalization before concat). Both target a different workshop's storage, so read them for the pattern rather than running them directly — see [`examples/README.md`](examples/README.md).

Then, in `claude`, describe the NetCDF/GeoTIFF/GRIB collection you want to turn into a virtual Icechunk or Arraylake store. The `icechunk-datacube-ingestion` skill vendored in this repo (`.claude/skills/`, from [earth-mover/agent-skills](https://github.com/earth-mover/agent-skills)) will guide Claude Code through gathering requirements, scanning your data, planning the ingestion, and validating the result.

Sample prompt to get started:

> Let's create a virtual icechunk dataset for the NOAA CDR NDVI data on AWS Open Data. Let's start with just a few files as a smoke test, and write the repo to s3://esip2026-breakout/\<your name\> object storage so anyone can access

Write your Icechunk store under `s3://esip2026-breakout/<your-name-or-dataset>/`, in `us-east-1` — a bucket dedicated to this workshop, writable by the shared `bedrock-class` credentials (reads are public bucket-wide). Use this regardless of which `--region` you launched your notebook in: virtual references are tiny (just manifests, not copies of the source data), so the store's own region doesn't matter the way the notebook VM's region does.

## Beyond this workshop

For your own future scientific work, also check out [Claude Science](https://claude.com/product/claude-science), Anthropic's AI workbench for research (databases, compute, and reusable skills for genomics, proteomics, structural biology, and more). It's a different product from Claude Code — built for Claude.ai Pro/Max/Team/Enterprise plans rather than the Bedrock-billed setup used here — so it's not part of this breakout, but worth knowing about.
