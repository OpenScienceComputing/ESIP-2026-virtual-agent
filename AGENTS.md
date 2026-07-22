# ESIP 2026 virtual-agent breakout — Agent Instructions

## Python environment

- The `esip2026` micromamba environment (already has `icechunk`, `virtualizarr`, `xarray`, `obstore`, `rioxarray`, `hvplot`, `geoviews`, `gribberish`, `virtual_tiff`, and everything else these notebooks need) was created by `notebook.sky.yaml` during VM setup, at `~/micromamba/envs/esip2026`. Do not create a new environment or `pip install` packages unless explicitly asked.
- `setup_claude_agent.sh` puts that environment's `bin/` on `PATH` for new terminals, so a bare `python`/`pip`/`jupyter` should already resolve correctly. If not (e.g. `import xarray` fails, or `which python` doesn't point under `~/micromamba/envs/esip2026`), either run `micromamba activate esip2026` first, or use the full path: `~/micromamba/envs/esip2026/bin/python <script>`.
- Create/edit notebook cells with `nbformat` via a Python script, not the built-in `NotebookEdit` tool — there's no live Jupyter kernel connection available on these VMs, and `NotebookEdit` has been observed to mangle multi-line cell source (see CLAUDE.md for the `nbformat` pattern).
- To actually run a notebook and capture real outputs/errors, execute it in place: `jupyter nbconvert --execute --to notebook --inplace <notebook>`. For a quick check without touching the tracked file, use `--output-dir /tmp` instead of `--inplace`.

## Working discipline

- **Debug by hypothesis, not by guessing.** When something breaks, read the actual traceback, form a specific hypothesis about the cause, and test that hypothesis before changing code. Don't apply speculative fixes and hope.
- **Verify before claiming done.** Don't say a script or notebook works until you've actually run it and seen it succeed. Report what you ran and what it produced; if something failed or was skipped, say so.
