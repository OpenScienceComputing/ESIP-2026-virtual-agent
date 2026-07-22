# ESIP-2026-virtual-agent

Notebooks and scripts supporting a breakout group at the ESIP 2026 Summer Meeting, where participants will use agentic coding to create workflows that build virtual Icechunk and Arraylake datasets.

**Date:** Tuesday, July 28, 2026

> This branch (`skypilot-explore`) provisions the notebook VM directly on AWS with [SkyPilot](https://skypilot.co/) — no Coiled account/workspace needed. There's also a [`main`](https://github.com/OpenScienceComputing/ESIP-2026-virtual-agent) branch that uses [Coiled](https://www.coiled.io/) instead. Both are viable; this branch is newer and more validated as of this writing.

## Overview

You'll use [SkyPilot](https://skypilot.co/) to launch a JupyterLab VM on AWS, then use [Claude Code](https://claude.com/claude-code) from a terminal on that VM — routed through AWS Bedrock, billed via ESIP's AWS credits — to build a notebook that virtualizes a collection of NetCDF, GeoTIFF, or GRIB files into an Icechunk or Arraylake store.

## Prerequisites

- A Linux machine (or WSL, or macOS) — your own laptop, or a GitHub Codespace — with Python 3 and `pip`. Virtually every machine already has this; no conda/mamba needed for this step.
- The shared Bedrock AWS credentials, announced at the start of the breakout — don't share or commit them. These are the *only* credentials you need: they authenticate SkyPilot (to launch the VM), Claude Code (to reach Bedrock), and notebook code (to write to S3).

### Don't have a Linux/WSL/macOS machine? Use a GitHub Codespace

Requires your own (free) GitHub account — the Codespace runs under your account and against your own free monthly Codespaces hours, not the repo owner's. Plenty for this workshop, just not unlimited.

1. Go to this branch on GitHub: https://github.com/OpenScienceComputing/ESIP-2026-virtual-agent/tree/skypilot-explore
2. Click the green **Code** button → **Codespaces** tab → **Create codespace on skypilot-explore**.
3. Wait for it to build, then open a terminal in the Codespace. The repo is already cloned there (Codespaces does this automatically) at `/workspaces/ESIP-2026-virtual-agent` — `cd` there, **skip Step 1 below**, and continue with Step 2.

(Or, with the [`gh` CLI](https://cli.github.com/) installed locally: `gh codespace create --repo OpenScienceComputing/ESIP-2026-virtual-agent --branch skypilot-explore && gh codespace code`.)

Either way, make sure the Codespace actually opened on `skypilot-explore`, not `main` — the default branch is the Coiled-based version and doesn't have `notebook.sky.yaml`.

## Step 1 — Clone this repo

Skip this step if you're on a Codespace — it's already cloned (see above). Otherwise:

```bash
git clone --branch skypilot-explore https://github.com/OpenScienceComputing/ESIP-2026-virtual-agent.git
cd ESIP-2026-virtual-agent
```

The `--branch skypilot-explore` matters — the default branch (`main`) is the Coiled-based version and doesn't have `notebook.sky.yaml` at all.

You need this locally before launching anything — the VM launch config (`notebook.sky.yaml`) lives here, and this whole directory gets synced to the VM automatically when you launch.

## Step 2 — Install SkyPilot and authenticate

```bash
python3 -m pip install --user "skypilot[aws]"
export PATH="$HOME/.local/bin:$PATH"
export AWS_ACCESS_KEY_ID=<shared key id, announced at the event>
export AWS_SECRET_ACCESS_KEY=<shared secret key, announced at the event>
sky check aws
```

`sky check aws` should report AWS as enabled. No account, no login, no invite — SkyPilot just needs valid AWS credentials, which you already have.

## Step 3 — Launch a notebook VM on AWS

```bash
export MACHINE_NAME="${GITHUB_USER:-$USER}-esip2026"
export JUPYTER_TOKEN=$(python3 -c 'import secrets; print(secrets.token_hex(16))')
sky launch -c "$MACHINE_NAME" notebook.sky.yaml --env JUPYTER_TOKEN -y -d
```

`MACHINE_NAME` picks up your GitHub username automatically on a Codespace (`$GITHUB_USER`, set by Codespaces itself) or your system username elsewhere (`$USER`) — this is how we'll tell everyone's machines apart in the shared AWS account. `export MACHINE_NAME=whatever-you-like-esip2026` instead if you'd rather set it explicitly.

`-d` (`--detach-run`) is required — without it, `sky launch` would wait for JupyterLab (a long-running server) to exit, which never happens, and just hang your terminal instead of returning control.

This takes a few minutes (VM boot + installing the environment) — **around 5–7 minutes end to end**, not instant. Check progress and get the URL once it's ready:

```bash
sky status "$MACHINE_NAME" --endpoint 8888
```

Once that prints an address, open `http://<that address>/lab?token=$JUPYTER_TOKEN` in your browser (run `echo $JUPYTER_TOKEN` if you need to see the token again).

By default this launches wherever SkyPilot finds AWS capacity (commonly `us-east-1`, matching most AWS Open Data and this workshop's S3 bucket). To pin a region — e.g. if your source data is in `us-west-2` — add `--infra aws/us-west-2` to the `sky launch` command.

## Step 4 — Set up Claude Code

Open a terminal on the VM — either SSH in (`ssh "$MACHINE_NAME"`, using the alias SkyPilot just set up for you) or use the Terminal tile in the JupyterLab launcher you just opened. Either way, land in `~/sky_workdir` (this repo, already synced there):

```bash
cd ~/sky_workdir
export BEDROCK_ACCESS_KEY_ID=<shared key id, announced at the event>
export BEDROCK_SECRET_ACCESS_KEY=<shared secret key, announced at the event>
bash setup_claude_agent.sh
```

Then open a **new** terminal (SSH in again, or a new JupyterLab Terminal tile) — that's what picks up everything the script just configured:

```bash
cd ~/sky_workdir
claude
```

`claude` must be run from inside this repo, not your home directory — that's what makes it pick up this repo's `CLAUDE.md` and `.claude/skills/`.

This installs Claude Code, points it at AWS Bedrock, and writes the same credentials to `~/.aws/credentials` (so notebook code you run — not just Claude Code itself — can write to S3 with them). See `setup_claude_agent.sh` for details.

Claude Code edits `.ipynb` files with its built-in notebook-editing tool and runs them with `jupyter nbconvert --execute` to verify real outputs (see `CLAUDE.md`/`AGENTS.md`) — there's no live Jupyter MCP connection set up on these VMs for this workshop.

## Step 5 — Build your virtual dataset

Look at [`examples/taranto-icechunk-append.ipynb`](examples/taranto-icechunk-append.ipynb) (and the script-form [`taranto-icechunk-tubitak-append.py`](examples/taranto-icechunk-tubitak-append.py)) for a worked example of a real virtual Icechunk workflow (create-or-append, date-diffing, per-file normalization before concat). Both target a different workshop's storage, so read them for the pattern rather than running them directly — see [`examples/README.md`](examples/README.md).

Then, in `claude`, describe the NetCDF/GeoTIFF/GRIB collection you want to turn into a virtual Icechunk or Arraylake store. The `icechunk-datacube-ingestion` skill vendored in this repo (`.claude/skills/`, from [earth-mover/agent-skills](https://github.com/earth-mover/agent-skills)) will guide Claude Code through gathering requirements, scanning your data, planning the ingestion, and validating the result.

Sample prompt to get started:

> Let's create a virtual icechunk dataset for the NOAA CDR NDVI data on AWS Open Data. Let's start with just a few files as a smoke test, and write the repo to s3://esip2026-breakout/\<your name\> object storage so anyone can access

Write your Icechunk store under `s3://esip2026-breakout/<your-name-or-dataset>/`, in `us-east-1` — a bucket dedicated to this workshop, writable by the shared credentials (reads are public bucket-wide). Use this regardless of which region you launched your VM in: virtual references are tiny (just manifests, not copies of the source data), so the store's own region doesn't matter the way the VM's region does.

## When you're done

```bash
sky down "${MACHINE_NAME:-${GITHUB_USER:-$USER}-esip2026}"
```

Tears down the VM immediately. If you forget, `notebook.sky.yaml` sets a 30-minute idle auto-shutdown as a safety net, but don't rely on it — clean up when you're finished.

## Beyond this workshop

For your own future scientific work, also check out [Claude Science](https://claude.com/product/claude-science), Anthropic's AI workbench for research (databases, compute, and reusable skills for genomics, proteomics, structural biology, and more). It's a different product from Claude Code — built for Claude.ai Pro/Max/Team/Enterprise plans rather than the Bedrock-billed setup used here — so it's not part of this breakout, but worth knowing about.
