# Examples

## `taranto-icechunk-append.ipynb`

A worked example of a real, non-trivial virtual Icechunk workflow: creating
or incrementally appending a virtual Icechunk store built from a collection
of NetCDF forecast files with `virtualizarr`. It's copied verbatim from a
prior workshop and targets that workshop's S3-compatible storage (a
`protocoast.env` dotenv file, a `protocoast-data` bucket) — **it will not run
as-is against this workshop's AWS environment.**

Read it for the pattern, not to execute it:

- Date-diffing (`set_repo` vs. `set_cloud`) to make repeated append runs
  idempotent and cheap — only new dates get virtualized and written.
- `ObjectStoreRegistry` / `HDFParser` / `VirtualChunkContainer` setup for
  virtual (manifest-only) reads.
- Per-file normalization (`fix_ds`) before `xr.concat`, and the
  `coords="minimal", compat="override", combine_attrs="override"` settings
  virtual datasets need.
- `Repository.open(...)` falling back to `Repository.create(...)`, then
  `writable_session` + `ds.vz.to_icechunk(...)` + `commit(...)`.

For building your own notebook against your own NetCDF, GeoTIFF, or GRIB
data, ask Claude Code to ingest it — the `icechunk-datacube-ingestion` skill
in `.claude/skills/` will guide the process end to end.
