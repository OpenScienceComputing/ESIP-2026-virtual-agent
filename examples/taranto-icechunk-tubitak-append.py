"""
Append Taranto SHYFEM forecast data to an Icechunk store using date-based set logic.

Methodology:
  set_repo  = dates already present in the Icechunk store's time coordinate
  set_cloud = dates available in the S3 bucket (NOS files)
  new_dates = set_cloud - set_repo  ->  only these are written
"""

import warnings
import os
import pandas as pd
import fsspec
import xarray as xr
import icechunk
from obstore.store import S3Store
from virtualizarr import open_virtual_dataset
from virtualizarr.parsers import HDFParser
from obspec_utils.registry import ObjectStoreRegistry
from dotenv import load_dotenv

warnings.filterwarnings("ignore", category=UserWarning)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
_ = load_dotenv(f'{os.environ["HOME"]}/dotenv/protocoast.env', override=True)

storage_endpoint = os.environ['ENDPOINT_URL']
storage_bucket = 'protocoast-data'
storage_name = 'taranto-icechunk-tubitak-v2'
bucket_url = f"s3://{storage_bucket}"

fs = fsspec.filesystem('s3', anon=False, endpoint_url=storage_endpoint,
                       skip_instance_cache=True, use_listings_cache=False)

# ---------------------------------------------------------------------------
# Icechunk storage / config
# ---------------------------------------------------------------------------
storage = icechunk.s3_storage(
    bucket=storage_bucket,
    prefix=f"icechunk/{storage_name}",
    from_env=True,
    endpoint_url=storage_endpoint,
    region='not-used',
    force_path_style=True,
)

config = icechunk.RepositoryConfig.default()
config.set_virtual_chunk_container(
    icechunk.VirtualChunkContainer(
        url_prefix=f"{bucket_url}/",
        store=icechunk.s3_store(
            region="not-used",
            anonymous=False,
            s3_compatible=True,
            force_path_style=True,
            endpoint_url=storage_endpoint,
        ),
    ),
)

credentials = icechunk.containers_credentials(
    {f"{bucket_url}/": icechunk.s3_credentials(anonymous=False)}
)

store_obj = S3Store(
    bucket=storage_bucket,
    endpoint=storage_endpoint,
    region="not-used",
)
registry = ObjectStoreRegistry({bucket_url: store_obj})
parser = HDFParser()

# ---------------------------------------------------------------------------
# Step 1: Build set_repo and set_cloud
# ---------------------------------------------------------------------------
try:
    repo = icechunk.Repository.open(storage, config, authorize_virtual_chunk_access=credentials)
    session = repo.readonly_session("main")
    ds = xr.open_zarr(session.store, consolidated=False, chunks={})

    if 'time' in ds.coords:
        dates = pd.to_datetime(ds.time.values) + pd.Timedelta(days=1)
        set_repo = set(dates.strftime('%Y%m%d'))
    else:
        set_repo = set()

except Exception as e:
    print(f"Repo access failed or empty ({e}). Assuming set_repo is empty.")
    repo = None
    set_repo = set()

print(f"set_repo: {len(set_repo)} dates found.")

print("Scanning S3 for NOS files...")
nos_files = fs.glob(f'{storage_bucket}/full_dataset/shyfem/taranto/forecast/*/*nos*.nc')

date_to_files_map = {}
set_cloud = set()

for f in nos_files:
    try:
        date_str = f.split('/')[-2]
        set_cloud.add(date_str)
        base_dir = os.path.dirname(f)
        date_to_files_map[date_str] = {
            'nos': f's3://{f}',
            'ous': f's3://{base_dir}/taranto_ous_{date_str}_nc4.nc',
        }
    except IndexError:
        pass

print(f"set_cloud: {len(set_cloud)} dates found.")

new_dates = sorted(set_cloud - set_repo)
print(f"Dates to process: {len(new_dates)}")
if new_dates:
    print(f"Range: {new_dates[0]} to {new_dates[-1]}")

# ---------------------------------------------------------------------------
# Step 2: Virtualize new data
# ---------------------------------------------------------------------------
def fix_ds(ds):
    """Standardize dimensions and coordinates for the Taranto dataset."""
    ds = ds.rename_vars(time='valid_time')
    ds = ds.rename_dims(time='step')
    step = (ds.valid_time - ds.valid_time[0]).assign_attrs({"standard_name": "forecast_period"})
    time = ds.valid_time[0].assign_attrs({"standard_name": "forecast_reference_time"})
    ds = ds.assign_coords(step=step, time=time)
    ds = ds.drop_indexes("valid_time")
    ds = ds.drop_vars('valid_time')
    ds = ds.set_coords(['latitude', 'longitude', 'element_index', 'topology', 'total_depth'])
    return ds


ds_final = None

if new_dates:
    nos_urls = [date_to_files_map[d]['nos'] for d in new_dates]
    ous_urls = [date_to_files_map[d]['ous'] for d in new_dates]

    print(f"Virtualizing {len(nos_urls)} NOS files...")
    nos_list = [
        fix_ds(open_virtual_dataset(url, parser=parser, registry=registry, loadable_variables=["time"]))
        for url in nos_urls
    ]
    combined_nos = xr.concat(nos_list, dim="time", coords="minimal",
                              compat="override", combine_attrs="override")

    print(f"Virtualizing {len(ous_urls)} OUS files...")
    ous_list = [
        fix_ds(open_virtual_dataset(url, parser=parser, registry=registry, loadable_variables=["time"]))
        for url in ous_urls
    ]
    combined_ous = xr.concat(ous_list, dim="time", coords="minimal",
                              compat="override", combine_attrs="override")

    ds_final = xr.merge([combined_nos, combined_ous], compat='override')

    # Add CF-UGRID topology metadata so downstream tools don't need to
    ds_final = ds_final.assign({"mesh_topology": xr.DataArray(0, attrs={
        "cf_role": "mesh_topology",
        "topology_dimension": 2,
        "node_coordinates": "longitude latitude",
        "face_node_connectivity": "element_index",
        "face_dimension": "element",
    })})
    ds_final["element_index"].attrs.update({"cf_role": "face_node_connectivity", "start_index": 1})
    for var in ds_final.data_vars:
        if "node" in ds_final[var].dims:
            ds_final[var].attrs["mesh"] = "mesh_topology"
            ds_final[var].attrs["location"] = "node"

    print("Datasets merged and ready for writing to Icechunk.")

else:
    print("No new dates found. Nothing to do.")

# ---------------------------------------------------------------------------
# Step 3: Create or append to Icechunk
# ---------------------------------------------------------------------------
if ds_final is not None:
    if repo is None:
        repo = icechunk.Repository.create(storage, config, authorize_virtual_chunk_access=credentials)
        session = repo.writable_session("main")
        print(f"Writing {len(ds_final.time)} time steps to new Icechunk store...")
        ds_final.virtualize.to_icechunk(session.store)
        msg = f"Initialized with forecast data: {new_dates[0]} to {new_dates[-1]}"
    else:
        session = repo.writable_session("main")
        print(f"Appending {len(ds_final.time)} time steps to Icechunk store...")
        ds_final.virtualize.to_icechunk(session.store, append_dim="time")
        msg = f"Appended forecast data: {new_dates[0]} to {new_dates[-1]}"

    session.commit(msg)
    print(f"Commit successful: '{msg}'")

    latest = next(repo.ancestry(branch="main"))
    print(f"Latest commit [{latest.written_at}]: {latest.message}")

else:
    print("Nothing to append.")
