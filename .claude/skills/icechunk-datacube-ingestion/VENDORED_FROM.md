Vendored from https://github.com/earth-mover/agent-skills at commit
`1b3c994161a84aace30fccabd1ccd9bdc01d5cc9` (icechunk-datacube-ingestion/).

`formats/HDF5.md` was an empty stub upstream at this commit — not a copy
error, the file genuinely had 0 bytes in the source repo. **This one file
has been patched locally** with NetCDF/HDF5 guidance adapted from
`~/.claude/skills/building-virtual-icechunk-stores` (personal, not repo
content), since NetCDF/HDF5 is one of this workshop's three target formats.
A PR upstreaming this fix was opened:
https://github.com/earth-mover/agent-skills/pull/3. If/when it merges, this
local patch can be dropped on the next refresh.

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

`COLLECT-DATACUBE-INGESTION-REQUIREMENTS.md` asked "virtual or native?"
once, then a generic schema/organization question with no branching logic —
so the agent could end up asking chunk-size/shape questions after the user
already chose virtual ingestion, which can't be rechunked without switching
to native. **Patched locally** to scope that question by the earlier
answer. PR upstreaming this fix:
https://github.com/earth-mover/agent-skills/pull/4.

To refresh: re-download `SKILL.md`, `COLLECT-DATACUBE-INGESTION-REQUIREMENTS.md`,
and everything under `formats/` from the current `main` branch and update the
commit hash above — re-apply the two local patches above if their PRs
haven't merged yet.
