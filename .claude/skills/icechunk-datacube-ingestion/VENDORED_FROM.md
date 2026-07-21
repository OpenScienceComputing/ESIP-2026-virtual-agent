Vendored from https://github.com/earth-mover/agent-skills at commit
`1b3c994161a84aace30fccabd1ccd9bdc01d5cc9` (icechunk-datacube-ingestion/).

`formats/HDF5.md` is an empty stub upstream at this commit — that's not a
copy error, the file genuinely has 0 bytes in the source repo.

`SKILL.md` links to three format docs that don't exist anywhere upstream
(checked both this pinned commit and current `main` as of 2026-07-21):
`formats/NETCDF3.md`, `formats/KERCHUNK.md`, `formats/PARQUET.md`. It also
has one broken self-reference: the "Giving up" section links
`./formats/UNSUPPORTED.md`, but the real file is
`UNSUPPORTED-FILE-FORMAT.md`. These are upstream bugs in Earthmover's skill,
not vendoring errors here. Left as-is (not patched) since none of NetCDF3,
Kerchunk, or Parquet are in scope for this workshop's NetCDF/TIFF/GRIB
target formats — worth re-checking on refresh in case Earthmover fixes it
upstream, and possibly worth filing as an issue against
earth-mover/agent-skills.

To refresh: re-download `SKILL.md`, `COLLECT-DATACUBE-INGESTION-REQUIREMENTS.md`,
and everything under `formats/` from the current `main` branch and update the
commit hash above.
