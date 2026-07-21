---
name: hdf5-netcdf4-icechunk-ingestion
description: How to read/parse/ingest HDF5/NetCDF4 files into Icechunk. Use whenever the user is doing an ingestion into Icechunk or Arraylake and HDF5 or NetCDF4 files are encountered.
---

This file is empty upstream in earth-mover/agent-skills as of 2026-07;
this content was written locally to fill the gap for NetCDF/HDF5, since
that's a common format for scientific array data. See `VENDORED_FROM.md` in
the parent skill directory.

## Reading HDF5/NetCDF4 as native chunks

Use `xarray.open_dataset`/`open_mfdataset` with the `h5netcdf` or `netcdf4`
engine, then write with `ds.to_zarr(icechunk_session.store, ...)`.

## Reading HDF5/NetCDF4 as virtual chunks

Use `virtualizarr.parsers.HDFParser` with `open_virtual_dataset`:

```python
from virtualizarr import open_virtual_dataset
from virtualizarr.parsers import HDFParser

vds = open_virtual_dataset(
    url=file_url,
    registry=registry,
    parser=HDFParser(),
    loadable_variables=["time"],  # small/coord variables that need decoding
    decode_times=True,            # only works on variables also in loadable_variables
)
```

- `loadable_variables`: `None` (default) loads only dimension coordinates into
  memory; `[]` keeps everything virtual; a list of names loads just those.
  Load a variable when it's small (coords, scalar metadata), needs decoding
  (e.g. `time`), or has inconsistent chunking across files that would
  otherwise break the manifest.
- `decode_times=True` decodes CF time variables, but only for variables also
  listed in `loadable_variables` — you can't decode a variable that's still
  virtual.

## Registry, and virtual chunk container setup

Virtual ingestion needs three separate places to agree on the same bucket
URL — easy to get out of sync, and the failure mode is often a vague read
error rather than an obvious auth error:

1. `ObjectStoreRegistry` (from `obspec_utils.registry`, or Arraylake's
   `.get_obstore_for_bucket()`) mapping a URL prefix (e.g. `s3://bucket`) to
   an `obstore` store — `open_virtual_dataset` needs this to read chunk data
   referenced by the manifest.
2. The Icechunk repo's `VirtualChunkContainer` (set via
   `config.set_virtual_chunk_container(...)`) needs a matching `url_prefix`
   and its own store instance for the same bucket.
3. `authorize_virtual_chunk_access` must be passed a matching credentials
   dict when calling `Repository.open()`/`Repository.create()`.

## Use the `.vz` accessor, not `.virtualize`

`virtualizarr` renamed its xarray accessor from `.virtualize` to `.vz`.
`.virtualize` still works but is deprecated and raises a warning on every
access. Use `ds.vz.to_icechunk(...)`.

## Homogeneity requirements — check before virtualizing, not after

Virtualization only works if all files share the same chunk shape, codec,
and dtype per variable, using codecs Zarr actually recognizes. Spot-check a
sample file with `h5py` before running a big virtualization job:

```python
import h5py
with h5py.File("file.nc", "r") as f:
    var = f["temperature"]
    print(var.chunks, var.compression, var.dtype)
```

Mixed chunk sizes or unsupported compression fail with confusing errors deep
inside the concat/write step — checking a sample file first is cheaper than
debugging a partial write.

## Normalize each file's dataset before concatenating

Real-world NetCDF/HDF5 collections are rarely concat-ready as-is. Write a
`fix_ds(ds)` helper and apply it per-file, before `xr.concat`. Typical fixes:
renaming a forecast time variable into a proper reference-time/lead-time
encoding, dropping redundant coordinate variables/indexes that would
otherwise conflict across files, and `ds.set_coords([...])` on variables
that should be coordinates but load as data variables.

## Concatenating virtual (manifest-only) datasets

`xr.concat` on datasets from `open_virtual_dataset` needs looser settings
than a normal xarray concat, since these are chunk manifests, not loaded
arrays:

```python
xr.concat(
    ds_list, dim="time",
    coords="minimal", compat="override", combine_attrs="override",
)
```

Without these, concat raises confusing errors trying to compare manifest
references as if they were real array values. If combining different
variable groups on the same time axis, concat each group separately then
`xr.merge([...], compat="override")`.

## Create vs. append vs. commit

- Try `Repository.open(storage, config, authorize_virtual_chunk_access=...)`
  first; fall back to `Repository.create(...)` only if opening fails.
- First write: `writable_session("main")` → `ds.vz.to_icechunk(session.store)`
  — no `append_dim`.
- Subsequent writes: same, but with `append_dim="time"` (or whatever the
  concat dimension is).
- Always `session.commit(message)`, and verify with
  `next(repo.ancestry(branch="main"))` afterward.
