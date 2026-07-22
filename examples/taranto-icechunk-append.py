#!/usr/bin/env python
# coding: utf-8

# # Appending to an Icechunk Store with Virtual References
# This notebook demonstrates how to append to an icechunk store.

# In[1]:


import warnings

import fsspec
import icechunk

import xarray as xr
from obstore.store import S3Store

from virtualizarr import open_virtual_dataset
from virtualizarr.parsers import HDFParser
from virtualizarr.registry import ObjectStoreRegistry

warnings.filterwarnings("ignore", category=UserWarning)


# In[2]:


import virtualizarr
print(icechunk.__version__)
print(virtualizarr.__version__)


# In[3]:


# load AWS credentials for Pangeo-EOSC storage as environment vars
from dotenv import load_dotenv
import os
_ = load_dotenv(f'{os.environ["HOME"]}/dotenv/protocoast.env')

# Define storage
storage_endpoint = os.environ['ENDPOINT_URL']
storage_bucket = 'protocoast-data'
storage_name = 'taranto-icechunk-test2'


# In[4]:


fs = fsspec.filesystem('s3', anon=False, endpoint_url=storage_endpoint, skip_instance_cache=True, use_listings_cache=False)


# In[5]:


flist = fs.glob('s3://protocoast-data/full_dataset/shyfem/taranto/forecast/*/*nos*.nc')
flist = [f's3://{f}' for f in flist]

print(len(flist))
print(flist[-1])


# ### Define our Virtualizarr `Parser` and `ObjectStoreRegistry`

# In[7]:


bucket = "s3://protocoast-data"
store = S3Store(bucket=storage_bucket, endpoint=storage_endpoint, region="not-used", allow_http=True)
registry = ObjectStoreRegistry({bucket: store})
parser = HDFParser()


# ## Create virtual datasets with VirtualiZarr's `open_virtual_dataset`

# In[8]:


ds_list = [
    open_virtual_dataset(
        url=url,
        parser=parser,
        registry=registry,
        loadable_variables=["time"],
    )
    for url in flist[-1:]
]





# In[10]:


def fix_ds(ds):
    ds = ds.rename_vars(time='valid_time')
    ds = ds.rename_dims(time='step')
    step = (ds.valid_time - ds.valid_time[0]).assign_attrs({"standard_name": "forecast_period"})
    time = ds.valid_time[0].assign_attrs({"standard_name": "forecast_reference_time"})
    ds = ds.assign_coords(step=step, time=time)
    ds = ds.drop_indexes("valid_time")
    ds = ds.drop_vars('valid_time')
    return ds


# In[11]:


ds_list = [fix_ds(ds) for ds in ds_list]


# In[12]:


combined_nos = xr.concat(
    ds_list,
    dim="time",
    coords="minimal",
    compat="override",
    combine_attrs="override",
)


# In[13]:


flist = fs.glob('s3://protocoast-data/full_dataset/shyfem/taranto/forecast/*/*ous*.nc')
flist = [f's3://{f}' for f in flist]
print(flist[-1])


# In[14]:


ds_list = [
    open_virtual_dataset(
        url=url,
        parser=parser,
        registry=registry,
        loadable_variables=["time"],
    )
    for url in flist[-1:]
]


# In[15]:




# In[16]:


ds_list = [fix_ds(ds) for ds in ds_list]


# In[17]:


combined_ous = xr.concat(
    ds_list,
    dim="time",
    coords="minimal",
    compat="override",
    combine_attrs="override",
)


# In[18]:


ds = xr.merge([combined_nos, combined_ous], compat='override')


# ## Initialize the Icechunk Store
# We need configure the `virtual_chunk_container` as make sure the icechunk container credentials allow for anonymous access. 
# Details on this can be found [here](https://icechunk.io/en/stable/virtual/).

# In[19]:


storage = icechunk.s3_storage(
    bucket=storage_bucket,
    prefix=f"icechunk/{storage_name}",
    from_env=True,
    endpoint_url=storage_endpoint,
    region='not-used',   # N/A for Pangeo-EOSC bucket, but required param
    force_path_style=True,
                                allow_http=True)


# In[20]:


config = icechunk.RepositoryConfig.default()

config.set_virtual_chunk_container(
    icechunk.VirtualChunkContainer(
        url_prefix=f"s3://{storage_bucket}/",
        store=icechunk.s3_store(region="not-used", anonymous=False, s3_compatible=True, 
                                force_path_style=True, endpoint_url=storage_endpoint,
                                allow_http=True),
    ),
)


# In[21]:


credentials = icechunk.containers_credentials({f"s3://{storage_bucket}/": icechunk.s3_credentials(anonymous=False)})

repo = icechunk.Repository.open(storage, config, authorize_virtual_chunk_access=credentials)

#read_session = read_repo.readonly_session("main")


# In[22]:


append_session = repo.writable_session("main")


# In[23]:


ds.virtualize.to_icechunk(append_session.store, append_dim="time")


# In[24]:


append_session.commit("wrote last day of data")


# # Check that it worked!
# Let's create a read-only icechunk session and pass in the authorization credentials for the[ Virtual Chunk Containers](https://icechunk.io/en/latest/configuration/#virtual-chunk-credentials) to Icechunk.

# In[25]:


credentials = icechunk.containers_credentials(
    {f"s3://{storage_bucket}/": icechunk.s3_credentials(anonymous=False)})

read_repo = icechunk.Repository.open(
    storage, config, authorize_virtual_chunk_access=credentials)

read_session = read_repo.readonly_session("main")


# In[26]:


ds = xr.open_zarr(read_session.store, consolidated=False, zarr_format=3)


# In[27]:


print(ds)

