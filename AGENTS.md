# ESIP 2026 virtual-agent breakout — Agent Instructions

## Python environment

- The `esip-notebook` Coiled software environment (already has `icechunk`, `virtualizarr`, `xarray`, `obstore`, `rioxarray`, and everything else these notebooks need) is installed at `$CONDA_PREFIX` — check `echo $CONDA_PREFIX` if unsure (it's set ambiently by Coiled, commonly `/opt/coiled/env`). Do not create a new environment or `pip install` packages unless explicitly asked.
- **Do not use `conda run -n base ...` or `conda activate base`** — there is no environment actually named `base` on these VMs, and `conda run -n base` fails with a `libmamba: prefix does not exist` error even though the real environment works fine. `setup_claude_agent.sh` puts `$CONDA_PREFIX/bin` on `PATH` for new terminals, so a bare `python`/`pip`/`jupyter` should already resolve correctly. If `python` still isn't right (e.g. `import xarray` fails, or `which python` doesn't point under `$CONDA_PREFIX`), run scripts via the full path instead: `$CONDA_PREFIX/bin/python <script>`.
- Edit notebook cells with the built-in `NotebookEdit` tool — there's no live Jupyter kernel connection available on these VMs (see CLAUDE.md).
- To actually run a notebook and capture real outputs/errors, execute it in place: `jupyter nbconvert --execute --to notebook --inplace <notebook>` (or `$CONDA_PREFIX/bin/jupyter` if `jupyter` isn't resolving correctly). For a quick check without touching the tracked file, use `--output-dir /tmp` instead of `--inplace`.

## Working discipline

- **Debug by hypothesis, not by guessing.** When something breaks, read the actual traceback, form a specific hypothesis about the cause, and test that hypothesis before changing code. Don't apply speculative fixes and hope.
- **Verify before claiming done.** Don't say a script or notebook works until you've actually run it and seen it succeed. Report what you ran and what it produced; if something failed or was skipped, say so.
