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

Requires your own (free) GitHub account — the Codespace runs under your account and against your own free monthly Codespaces hours, not the repo owner's. Plenty for this workshop, just not unlimited. Make sure you're signed in at github.com first — the **Codespaces** tab in the next step won't show up if you're logged out.

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

Pick the AWS region your source data actually lives in — compute close to the data, not wherever happens to have spare capacity. `us-east-1` covers most AWS Open Data (including the NOAA CDR sample data below) and this workshop's own S3 bucket; use `us-west-2` if you're working with `esip-qhub-public` instead.

```bash
export MACHINE_NAME="${GITHUB_USER:-$USER}-esip2026"
export JUPYTER_TOKEN=$(python3 -c 'import secrets; print(secrets.token_hex(16))')
sky launch -c "$MACHINE_NAME" notebook.sky.yaml --infra aws/us-east-1 \
  --env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY --env JUPYTER_TOKEN -y -d
```

(Swap `--infra aws/us-west-2` if that's where your data is. `--infra` is required, not optional — without it SkyPilot picks whatever AWS region happens to have capacity, which may not be near your data.)

`MACHINE_NAME` picks up your GitHub username automatically on a Codespace (`$GITHUB_USER`, set by Codespaces itself) or your system username elsewhere (`$USER`) — this is how we'll tell everyone's machines apart in the shared AWS account. `export MACHINE_NAME=whatever-you-like-esip2026` instead if you'd rather set it explicitly.

`--env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY` (no `=value`) pass through the credentials you already exported in Step 2 — the same ones authenticating SkyPilot itself. The VM uses them to install and configure Claude Code automatically during setup, so you never have to type them a second time.

`-d` (`--detach-run`) is required — without it, `sky launch` would wait for JupyterLab (a long-running server) to exit, which never happens, and just hang your terminal instead of returning control.

This takes a few minutes (VM boot + installing the environment + Claude Code) — **around 5–8 minutes end to end**, not instant. Once it's up, tunnel to it over SSH rather than exposing it on a public port — this keeps the Jupyter token off the open internet and avoids the browser's "not secure" warning entirely, since traffic goes through the already-encrypted SSH connection SkyPilot set up for you:

```bash
ssh -f -N -L 8888:localhost:8888 "$MACHINE_NAME"
echo "http://localhost:8888/lab?token=$JUPYTER_TOKEN"
echo "Token (paste this if prompted): $JUPYTER_TOKEN"
```

Open that URL in your browser. If the `ssh` command fails (connection refused), the VM isn't ready yet — wait a bit and retry. A `bind [127.0.0.1]:8888: Address already in use` warning is harmless (a dual-stack IPv4/IPv6 quirk) as long as the URL loads — ignore it. The tunnel runs in the background (`-f`) for as long as you need it; find and kill it with `pkill -f "8888:localhost:8888"` when you're done, or it'll close on its own when the VM shuts down.

**On a Codespace**, you'll likely see a "Your application running on port 8888 is available" notification pop up instead — click its **Open in Browser** button rather than (or in addition to) pasting the URL yourself. Either way, the `?token=...` in the URL may not carry through — Codespaces forwards `localhost` ports through its own GitHub-authentication redirect, which can strip the query string, landing you on Jupyter's login page instead of going straight in. If that happens, just paste the token printed above into that page once — Jupyter remembers you for the rest of the session after that.

## Step 4 — Use Claude Code

Claude Code is already installed and configured by the time the VM is up — Step 3's launch command set that up automatically. Just open a terminal on the VM — either SSH in (`ssh "$MACHINE_NAME"`, using the alias SkyPilot just set up for you) or use the Terminal tile in the JupyterLab launcher you just opened — and land in `~/sky_workdir` (this repo, already synced there):

```bash
cd ~/sky_workdir
claude
```

`claude` must be run from inside this repo, not your home directory — that's what makes it pick up this repo's `CLAUDE.md` and `.claude/skills/`.

The first time you run it, Claude Code will ask "Do you trust the files in this folder?" — say yes, this is the repo you just cloned.

If `claude` isn't found or Bedrock doesn't work, the automatic setup may have been skipped (e.g. you launched without the `--env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY` flags) — run it by hand: `export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... && bash ~/sky_workdir/setup_claude_agent.sh`, then open a new terminal.

Claude Code edits `.ipynb` files with its built-in notebook-editing tool and runs them with `jupyter nbconvert --execute` to verify real outputs (see `CLAUDE.md`/`AGENTS.md`) — there's no live Jupyter MCP connection set up on these VMs for this workshop.

## Step 5 — Build your virtual dataset

Look at [`examples/taranto-icechunk-append.ipynb`](examples/taranto-icechunk-append.ipynb) (and the script-form [`taranto-icechunk-tubitak-append.py`](examples/taranto-icechunk-tubitak-append.py)) for a worked example of a real virtual Icechunk workflow (create-or-append, date-diffing, per-file normalization before concat). Both target a different workshop's storage, so read them for the pattern rather than running them directly — see [`examples/README.md`](examples/README.md).

Then, in `claude`, describe the NetCDF/GeoTIFF/GRIB collection you want to turn into a virtual Icechunk or Arraylake store. The `icechunk-datacube-ingestion` skill vendored in this repo (`.claude/skills/`, from [earth-mover/agent-skills](https://github.com/earth-mover/agent-skills)) will guide Claude Code through gathering requirements, scanning your data, planning the ingestion, and validating the result.

Sample prompt to get started:

> Let's create a virtual icechunk dataset for the NOAA CDR NDVI data on AWS Open Data. Let's start with just a few files as a smoke test, and write the repo to s3://esip2026-breakout/\<your name\> object storage so anyone can access

Once that succeeds, try:

> Make a notebook that visualizes the icechunk using hvplot

Write your Icechunk store under `s3://esip2026-breakout/<your-name-or-dataset>/`, in `us-east-1` — a bucket dedicated to this workshop, writable by the shared credentials (reads are public bucket-wide). Use this regardless of which region you launched your VM in: virtual references are tiny (just manifests, not copies of the source data), so the store's own region doesn't matter the way the VM's region does.

Don't be alarmed if Claude Code hits errors along the way and keeps iterating — reading a traceback, adjusting, and retrying is normal agentic behavior, not a sign something is broken. Let it keep working.

If you close your terminal or come back later, just `cd ~/sky_workdir && claude` again — it's the same repo, and you can ask it to re-run the notebook it built for you rather than remembering the exact command yourself.

## When you're done

```bash
sky down "${MACHINE_NAME:-${GITHUB_USER:-$USER}-esip2026}"
```

Tears down the VM immediately. If you forget, `notebook.sky.yaml` sets a 30-minute idle auto-shutdown as a safety net, but don't rely on it — clean up when you're finished.

## Beyond this workshop

For your own future scientific work, also check out [Claude Science](https://claude.com/product/claude-science), Anthropic's AI workbench for research (databases, compute, and reusable skills for genomics, proteomics, structural biology, and more). It's a different product from Claude Code — built for Claude.ai Pro/Max/Team/Enterprise plans rather than the Bedrock-billed setup used here — so it's not part of this breakout, but worth knowing about.
