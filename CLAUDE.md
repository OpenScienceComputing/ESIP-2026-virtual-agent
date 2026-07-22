@AGENTS.md

## Claude Code

There's no live Jupyter MCP connection set up on these VMs for this workshop, kept simple/proven rather than wired up. To actually run a notebook and see real outputs/errors (not just edit source), execute it with `nbconvert` — see AGENTS.md.

**Do not use the built-in `NotebookEdit` tool for multi-line cell content.** It has been observed to mangle cell source — literal `\n` characters (and stray quote characters) end up baked into the rendered cell instead of real line breaks. Instead, create/edit notebooks with a short Python script using `nbformat` (a standard `nbconvert` dependency, always available here):

```python
import nbformat as nbf

nb = nbf.v4.new_notebook()
nb["cells"] = [
    nbf.v4.new_markdown_cell("# A title\n\nSome explanation."),
    nbf.v4.new_code_cell("import xarray as xr\nds = xr.open_zarr(...)"),
]
nbf.write(nb, "notebook.ipynb")
```

Cell source can be a real multi-line Python string (triple-quoted, or with actual `\n` inside a normal string — both work fine here since Python and `nbformat` handle the escaping correctly, unlike `NotebookEdit`). To edit an existing notebook, `nbf.read(path, as_version=4)`, modify `nb["cells"]`, then `nbf.write(nb, path)`. After writing, spot-check by reading the file back and confirming no literal `\n`/`\\n` shows up in any cell's rendered source before considering the notebook done.

Task-specific guidance lives in skills under `.claude/skills/` and loads automatically when relevant:

- `icechunk-datacube-ingestion` (vendored from [earth-mover/agent-skills](https://github.com/earth-mover/agent-skills)) covers ingesting NetCDF/HDF5/TIFF/GRIB/Zarr collections into an Icechunk or Arraylake datacube — see `.claude/skills/icechunk-datacube-ingestion/SKILL.md`.
- `visualizing-with-hvplot` covers plotting the resulting xarray data with hvplot (when to use `rasterize=True`, `geo=True`/`tiles="OSM"`, and not narrating CF encoding internals) — see `.claude/skills/visualizing-with-hvplot/SKILL.md`.
