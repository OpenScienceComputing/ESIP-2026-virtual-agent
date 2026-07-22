---
name: visualizing-with-hvplot
description: How to visualize an xarray Dataset/DataArray (e.g. opened from an Icechunk or Arraylake store) with hvplot. Use whenever the user asks to plot, visualize, or explore data that was just read with xarray - especially gridded (lon/lat) or time series data from a virtual/native Icechunk store.
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
