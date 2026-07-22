@AGENTS.md

## Claude Code

Edit `.ipynb` files with the built-in `NotebookEdit` tool. There's no live Jupyter MCP connection on these VMs — Coiled runs Jupyter embedded inside the Dask scheduler process, reachable only through a per-cluster external proxy URL with its own token, which wasn't worth the reliability cost for this workshop. To actually run a notebook and see real outputs/errors (not just edit source), execute it with `nbconvert` — see AGENTS.md.

Task-specific guidance lives in skills under `.claude/skills/` and loads automatically when relevant:

- `icechunk-datacube-ingestion` (vendored from [earth-mover/agent-skills](https://github.com/earth-mover/agent-skills)) covers ingesting NetCDF/HDF5/TIFF/GRIB/Zarr collections into an Icechunk or Arraylake datacube — see `.claude/skills/icechunk-datacube-ingestion/SKILL.md`.
- `visualizing-with-hvplot` covers plotting the resulting xarray data with hvplot (when to use `rasterize=True`, `geo=True`/`tiles="OSM"`, and not narrating CF encoding internals) — see `.claude/skills/visualizing-with-hvplot/SKILL.md`.
