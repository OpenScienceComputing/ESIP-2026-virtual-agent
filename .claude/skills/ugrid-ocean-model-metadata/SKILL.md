---
name: ugrid-ocean-model-metadata
description: Add UGRID Conventions mesh topology metadata to an Icechunk/Zarr datacube built from unstructured-grid ocean circulation model output, so tools like xugrid/uxarray can recognize the mesh. Use this whenever the ingestion source is FVCOM, ADCIRC, SHYFEM, SCHISM, ICON, or Delft3D/D-Flow FM output, or whenever the user mentions an unstructured/triangular-mesh ocean or coastal model, a finite-element/finite-volume ocean model, or wants their virtual dataset to work with xugrid/uxarray. Use this together with (not instead of) `icechunk-datacube-ingestion` - it covers the mesh-metadata step of an otherwise normal ingestion.
---

# Adding UGRID mesh metadata to ocean model datacubes

## Why this matters

Unstructured-grid ocean models store data per node/element of a triangular
(or mixed) mesh, not on a regular lon/lat grid. `hvplot`, `xugrid`, and
`uxarray` can only treat that as a proper mesh - letting you plot it,
regrid it, or run mesh-aware operations - if the dataset carries a UGRID
Conventions mesh topology variable (spec:
https://ugrid-conventions.github.io/ugrid-conventions/). Without it, the
node/element arrays just look like unrelated 1D data to any CF-aware tool.

**Check first whether the source already has this.** Some of these models
write UGRID-compliant output natively - adding a second, conflicting mesh
topology variable is worse than doing nothing. See the per-model notes
below before writing any mapping code.

## The mesh topology variable

A 2D UGRID mesh needs one dummy (scalar, no data) variable with these
attributes, plus the connectivity/coordinate variables it points to:

```python
ds["mesh"] = xr.DataArray(0, attrs={
    "cf_role": "mesh_topology",
    "long_name": "Topology data of 2D unstructured mesh",
    "topology_dimension": 2,
    "node_coordinates": "mesh_node_x mesh_node_y",
    "face_node_connectivity": "mesh_face_nodes",
})
ds["mesh_face_nodes"].attrs.update({
    "cf_role": "face_node_connectivity",
    "start_index": 0,  # or 1 - see indexing note below
})
```

`node_coordinates` and `face_node_connectivity` are the two required
pointers (`edge_node_connectivity`, `face_dimension`, etc. are optional -
only add them if you actually have edge data or a non-standard dimension
order). Name the mesh variable and its pointees whatever you like, but be
consistent between the attribute strings and the actual variable names.

**Indexing**: UGRID connectivity is 0-based by default; a `start_index`
attribute on the connectivity variable overrides that. Every model below
writes 1-based (Fortran-style) node numbers in its raw connectivity array
- either keep that and set `start_index: 1`, or subtract 1 and set
`start_index: 0`. Don't silently renumber without setting the attribute;
xugrid trusts `start_index`, not the raw values.

**This is virtual ingestion - treat the mesh as loadable, not virtual.**
The node coordinates and face-node connectivity array are the same for
every timestep and every file in the collection, and they're small (a few
MB at most, not the bulk data). Per the `icechunk-datacube-ingestion`
skill, pass them as `loadable_variables` (materialized directly into the
Icechunk store) rather than virtual references - there's no benefit to
virtualizing something this small and constant, and it keeps the mesh
readable without dereferencing back to the original files.

## Detecting the source model

Look at global attributes and variable names when you scan the files (step
2-3 of `icechunk-datacube-ingestion`):

| Model | Fingerprint |
|---|---|
| FVCOM | Global attr `source` contains `"FVCOM"`; variables `nv`, `nbe`, `siglay` |
| ADCIRC | Global attr `source`/`model` contains `"ADCIRC"`; variable `adcirc_mesh` present |
| SHYFEM | Global attrs mention SHYFEM/ISMAR-CNR; variable `element_index` |
| SCHISM | Global attrs mention SCHISM; variables prefixed `SCHISM_hgrid*` |
| ICON | Variables `clon`/`clat`/`vlon`/`vlat`/`vertex_of_cell`, often in a *separate* grid file |
| Delft3D / D-Flow FM | Variable `mesh2d` (or similar `mesh*` name) with `cf_role="mesh_topology"` already set |

## Per-model notes

### ADCIRC - already UGRID-compliant, do nothing

ADCIRC's own NetCDF writer (`netcdfio.F90`) has written UGRID metadata
since ~2013: a dummy `adcirc_mesh` variable with `cf_role="mesh_topology"`,
`topology_dimension=2`, `node_coordinates="x y"`,
`face_node_connectivity="element"`; the `element` variable itself carries
`cf_role="face_node_connectivity"` and `start_index=1`. Just verify it
opens correctly with xugrid (see below) - don't add anything.

### Delft3D / D-Flow FM - already UGRID-compliant, do nothing

Deltares co-originated the UGRID conventions, and D-Flow FM output
(`*_map.nc`) is UGRID-native: a `mesh2d` variable with
`cf_role="mesh_topology"` and the usual pointers, alongside some
Deltares-specific extension attributes (e.g. `layer_dimension`) that
aren't part of the core spec but don't interfere with it. Verify with
xugrid; don't add anything.

### SCHISM - check for the `iof_ugrid` flag first

If the run had `iof_ugrid > 0` set in `param.nml`, the combined output
already has a UGRID mesh topology variable named `SCHISM_hgrid`
(`cf_role="mesh_topology"`), with node coordinates
`SCHISM_hgrid_node_x`/`SCHISM_hgrid_node_y` and connectivity
`SCHISM_hgrid_face_nodes`. Check for `SCHISM_hgrid` in the dataset's
variables before doing anything - if it's there, you're done. If the
output predates that option or was combined without it, you'll see the
same `SCHISM_hgrid*`-prefixed variables but without a proper mesh topology
variable pointing at them - in that case just add the mesh topology
variable pointing at the existing `SCHISM_hgrid_node_x`/`_node_y`/
`_face_nodes` variables rather than renaming anything.

### FVCOM - needs the mapping

Raw variables: `nv` (face-node connectivity, dims `(three, nele)`,
1-based), node coordinates `lon`/`lat` (or `x`/`y` if the run is in a
projected/Cartesian grid rather than geographic - check which are
present), and separately `lonc`/`latc` (element/face center coordinates -
useful as `face_coordinates` but not `node_coordinates`). Map:

```python
ds["nv"].attrs.update({"cf_role": "face_node_connectivity", "start_index": 1})
ds["mesh"] = xr.DataArray(0, attrs={
    "cf_role": "mesh_topology",
    "topology_dimension": 2,
    "node_coordinates": "lon lat",
    "face_node_connectivity": "nv",
    "face_coordinates": "lonc latc",
})
```

`nv`'s dimension order in the raw file is often `(three, nele)`
(Fortran-style) rather than the `(nele, three)` UGRID expects for
`face_dimension` to default correctly - check with `ds["nv"].dims` and
either transpose or set `face_dimension` explicitly to whichever dimension
is actually the element count.

### SHYFEM - needs the mapping

Raw variables: `element_index` (face-node connectivity, 1-based - seen in
practice as dims `(nele, three)`) and node coordinates `longitude`/
`latitude`. Map:

```python
ds["element_index"].attrs.update({"cf_role": "face_node_connectivity", "start_index": 1})
ds["mesh"] = xr.DataArray(0, attrs={
    "cf_role": "mesh_topology",
    "topology_dimension": 2,
    "node_coordinates": "longitude latitude",
    "face_node_connectivity": "element_index",
})
```

SHYFEM output is CF-compliant but not UGRID-native - there's no existing
mesh topology variable to check for first, unlike SCHISM/ADCIRC/Delft3D.

### ICON - needs the mapping, and probably a separate grid file

**Lower confidence than the models above - verify against the actual
files before trusting this blindly.** ICON output files are usually cell
values only, referencing a *separate* grid-description file (via a global
attribute or the `uuidOfHGrid`/grid-file convention) rather than embedding
node/vertex coordinates inline. The grid file itself has `clon`/`clat`
(cell/face center coordinates, radians), `vlon`/`vlat` (node/vertex
coordinates, radians), and `vertex_of_cell` (face-node connectivity, dims
`(3, ncells)`, counter-clockwise). You'll likely need to open both the
data file and its grid file and join them before you have enough to build
the mesh topology variable - ask the user which grid file corresponds to
their data if it isn't obvious from the file's attributes. Convert
`vlon`/`vlat` from radians to degrees if the rest of the datacube is in
degrees, and check counter-clockwise-vs-clockwise winding expectations
against whatever tool you're targeting.

## Verify the result

Confirm xugrid actually recognizes the mesh before calling this done:

```python
import xugrid as xr_ugrid
uds = xr_ugrid.open_dataset(store)  # or xr_ugrid.UgridDataset.from_dataset(ds)
uds.ugrid.grid  # should describe the mesh, not raise
```
