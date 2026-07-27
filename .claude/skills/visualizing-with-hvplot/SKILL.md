---
name: visualizing-with-hvplot
description: How to visualize an xarray Dataset/DataArray (e.g. opened from an Icechunk or Arraylake store) with hvplot. Use whenever the user asks to plot, visualize, or explore data that was just read with xarray - especially gridded (lon/lat) or time series data from a virtual/native Icechunk store, and unstructured-mesh/UGRID data (e.g. from FVCOM, ADCIRC, SCHISM, SHYFEM, ICON, Delft3D) which needs xugrid + `.hvplot.trimesh` instead of `.hvplot.quadmesh`.
---

# Visualizing xarray data with hvplot

## Don't narrate CF/NetCDF encoding internals

`scale_factor`, `add_offset`, `_FillValue`, etc. are NetCDF/CF packing
conventions. xarray decodes them automatically when opening a dataset
(`decode_cf`/`mask_and_scale`, on by default) - the resulting values are
already the real, physical ones. Don't explain these attributes to the user
or narrate that decoding is happening; it's an internal implementation
detail they don't need, not something notable about their data.

## `rasterize=True` for gridded plots, not time series

For 2D gridded plots (`kind="image"`, `kind="quadmesh"`), always pass
`rasterize=True`:

```python
ds["var"].hvplot.quadmesh(x="lon", y="lat", rasterize=True)
```

Without it, hvplot tries to render every cell as an individual vector
element - fine for a small array, but it can freeze or crash the browser
once a grid gets into the hundreds of thousands/millions of cells, which is
common for the kind of data this workshop works with.

Don't add `rasterize=True` to 1D time series line/scatter plots
(`kind="line"`, `kind="scatter"` over a time axis) - there's no equivalent
cell-count blowup, and rasterizing a line plot can make it look worse than
just plotting it directly.

## `geo=True` + `tiles="OSM"` for lon/lat plots

When the plot's x/y axes are geographic coordinates (`lon`/`lat`,
`longitude`/`latitude`), pass both `geo=True` (correct geographic
projection handling, via geoviews/cartopy) and `tiles="OSM"` (an
OpenStreetMap basemap for spatial context):

```python
ds["var"].hvplot.quadmesh(
    x="lon", y="lat", rasterize=True, geo=True, tiles="OSM",
)
```

Skip `geo=True`/`tiles` for plots that aren't on a geographic coordinate
system (e.g. a time series, or a plot over model grid indices rather than
lon/lat).

## UGRID-compliant (unstructured mesh) data needs xugrid + `.hvplot.trimesh`

If the dataset has UGRID Conventions mesh topology metadata (e.g. built
with the `ugrid-ocean-model-metadata` skill, or already-native output from
ADCIRC/Delft3D/SCHISM) - `ds.hvplot.quadmesh(...)` won't work, since
there's no regular x/y grid to plot against. Convert to an xugrid dataset
first, then use `.hvplot.trimesh`, not `.hvplot.quadmesh`:

```python
import xugrid as xu
import hvplot.xugrid  # registers the .hvplot accessor on xugrid objects

uds = xu.UgridDataset(ds)
uds["hs"].hvplot.trimesh(
    geo=True, rasterize=True, tiles="CartoLight", cmap="viridis",
)
```

The `rasterize=True` and `geo=True`/`tiles` guidance above applies here
too - a mesh plot has the same cell-count blowup risk as a quadmesh, and
the same need for geographic projection handling when the mesh is in
lon/lat.
