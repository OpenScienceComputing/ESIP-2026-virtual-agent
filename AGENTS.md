# ESIP 2026 virtual-agent breakout — Agent Instructions

## Python environment

- Use the `base` conda environment to run Python — the `esip-notebook` Coiled software environment is baked in as `base` on these VMs, so it already has `icechunk`, `virtualizarr`, `xarray`, `obstore`, `rioxarray`, and everything else these notebooks need. Do not create a new environment or `pip install` packages unless explicitly asked.
- Run scripts with `conda run -n base python <script>`.
- Edit notebook cells with the built-in `NotebookEdit` tool — there's no live Jupyter kernel connection available on these VMs (see CLAUDE.md).
- To actually run a notebook and capture real outputs/errors, execute it in place: `conda run -n base jupyter nbconvert --execute --to notebook --inplace <notebook>`. For a quick check without touching the tracked file, use `--output-dir /tmp` instead of `--inplace`.

## Working discipline

- **Debug by hypothesis, not by guessing.** When something breaks, read the actual traceback, form a specific hypothesis about the cause, and test that hypothesis before changing code. Don't apply speculative fixes and hope.
- **Verify before claiming done.** Don't say a script or notebook works until you've actually run it and seen it succeed. Report what you ran and what it produced; if something failed or was skipped, say so.
