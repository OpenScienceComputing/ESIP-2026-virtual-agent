@AGENTS.md

## Claude Code

For editing `.ipynb` files, use the Jupyter MCP — it runs against the live `base` kernel so you can execute cells and verify real outputs, and it writes through nbformat so git diffs stay clean. Do not use the built-in `NotebookEdit` tool: it cannot execute code and collapses cell source into a single JSON string, which mangles notebook diffs.

Task-specific guidance lives in skills under `.claude/skills/` and loads automatically when relevant. `icechunk-datacube-ingestion` (vendored from [earth-mover/agent-skills](https://github.com/earth-mover/agent-skills)) covers ingesting NetCDF/HDF5/TIFF/GRIB/Zarr collections into an Icechunk or Arraylake datacube — see `.claude/skills/icechunk-datacube-ingestion/SKILL.md`.
