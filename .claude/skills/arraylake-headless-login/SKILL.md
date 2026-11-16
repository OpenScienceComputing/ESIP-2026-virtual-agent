---
name: arraylake-headless-login
description: Log in to Arraylake / Earthmover from a terminal with no usable browser (WSL, SSH, VM, container) using `arraylake auth login --no-browser`, and recover the activation URL when a spinner scrolls it away. Use whenever `arraylake auth login` hangs on "Waiting for login...", the login URL or device code disappears off screen, an Arraylake call fails with 403 `invalid_grant` / "Unknown or invalid refresh token", `arraylake auth status` says "Not logged in", or a Client()/Repo call to app.earthmover.io fails on auth before you can inspect a repo.
---

# Logging in to Arraylake without a browser

## The problem

`arraylake auth login` defaults to `--browser`: it starts an Auth0 device-code
flow, tries to open a browser window itself, and prints a panel that only shows
a code to *match* — never a URL:

```
╭──────────────── Login ─────────────────╮
│ Ensure the code in your browser matches:│
│              ╭───────────╮              │
│              │ WDMV-RVQB │              │
```

On WSL, SSH sessions, VMs, and containers no browser opens, so that code is
useless — there is nothing to match it against. Meanwhile a `rich` spinner
starts redrawing `⠧ Waiting for login...` forever, which in a scrollback buffer
buries the panel. That is the "it scrolled away before I could act" symptom.

## The fix

Add `--no-browser`. It prints a **complete activation URL with the code already
embedded**, so there is no code to type and nothing to match:

```
https://earthmover-production.us.auth0.com/activate?user_code=MRCN-JWCX
```

Open that in any browser, on any machine, and approve. The CLI is polling in the
background; when you approve, it exchanges the code for a token and exits.

```bash
arraylake auth login --no-browser
```

Leave the command running while you approve — killing it aborts the flow and the
code goes stale, even if the browser page said success.

If the CLI is not on `PATH` (it usually lives in a conda/micromamba env rather
than the base one), call it by full path, e.g.:

```bash
~/miniforge3/envs/arraylake/bin/arraylake auth login --no-browser
```

## Verifying

```bash
arraylake auth status
```

Prints the API endpoint and your identity when it worked, or
`⚠️ Not logged in, please log in with: arraylake auth login` when it did not.
Check this before concluding a login succeeded — the browser saying "you may
close this window" only means Auth0 is happy, not that the local token landed.

## When the token is merely stale

An expired session surfaces from the Python client, not the CLI, and the message
names Auth0 rather than Arraylake:

```
ArraylakeClientError Error response 403 while requesting
URL('https://earthmover-production.us.auth0.com/oauth/token').
{"error":"invalid_grant","error_description":"Unknown or invalid refresh token."}
```

`arraylake auth refresh` cannot fix this one. Refresh needs a valid refresh
token, and that is exactly what has been rejected — so go straight to
`arraylake auth login --no-browser`. Tokens live in `~/.arraylake/token.json`
(per API endpoint); a stale file there is the usual cause.

Use `refresh` only for an access token that has aged out while the refresh token
is still good, which fails differently (no `invalid_grant`).

## Capturing the URL when you cannot see the terminal

Running the flow yourself (as an agent, or when the spinner still clobbers
output) means grabbing the URL out of a log. Two things make this fiddly, and
both are worth knowing before improvising:

- **The spinner rewrites the same line thousands of times.** `tail` on the log
  shows only `Waiting for login...`. The URL is near the *head*.
- **Output is wrapped in terminal escapes.** URLs may be OSC-8 hyperlinks
  (`ESC ] 8 ; ; <url>`), so a `sed` that only strips CSI (`ESC [ ... letter`)
  sequences leaves mangled text and can hide the URL entirely. Extracting bare
  strings and matching the URL pattern is far more robust than trying to
  pretty-print the panel.

`scripts/al-login.sh` handles both. Run it as a **background** task, because it
blocks until the user approves:

```bash
.claude/skills/arraylake-headless-login/scripts/al-login.sh
```

It writes a pty-backed log (default `~/.cache/arraylake-login.log`) and prints
the activation URL as soon as it appears. To read the URL from another call:

```bash
strings ~/.cache/arraylake-login.log \
  | grep -oE 'https://[^ ]*activate\?user_code=[A-Za-z0-9-]+' | head -1
```

Then give that URL to the user and wait — you cannot approve it for them.

Post the URL as the *first* thing you say and then stop; don't queue up other
work while it is pending. The code expires in about 15 minutes, and a user who
sees the link only after you finish a long edit may find it already dead.
`AL_LOGIN_TIMEOUT` overrides the wait if you need a shorter one.

### Two traps when scripting this

**Never clean up with `pkill -f "arraylake auth login"`.** `pkill -f` matches
against full command lines, and the shell running your command has that very
string in its own argv — the pattern you typed is part of it. So the pkill kills
its own parent shell, and the whole call dies (exit 144) before anything else
runs. It looks exactly like a sandbox or permissions failure, which sends you
debugging the wrong thing. Use a pattern that cannot match itself:

```bash
pkill -f 'arraylake[ ]auth[ ]login'   # brackets: literal text never appears in argv
```

**Do not add `&` yourself.** A `script -c "..." &` nested inside an
already-backgrounded shell dies when the outer shell exits. Let the harness run
`al-login.sh` as a background task; the script does its own internal
backgrounding and waits correctly.

## Scope note

This covers authentication only. Once `arraylake auth status` is clean, an
expired-credentials error is no longer the explanation for a repo that looks
broken — a repo whose data appears missing while auth is fine is a different
problem (for virtual Icechunk stores, usually the referenced source objects,
not the login).
