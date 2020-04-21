# Cluster configuration

Cartridge orchestrates a distributed system of Tarantool instances - a
cluster. One of the core concepts is a **clusterwide configuration**.
Every instance in clsuter stores a copy of it. Cartridge manages it to
be identical everywhere by two-phase commit algorithm.

Clusterwide configuration contains the options that must be identical on
every cluster node, such as topology of the cluster, failover and vshard
configuration, authentication params and ACLs, and user-defined config.

Clusterwide configuration doesn't provide instance specific parameters:
ports, workdirs, memory settings etc.

# Clusterwide config managment

## Twophase commit
There is no need to create configuration manually, because managing configuration
lifecycle is a part of `twophase` module. This module is a clusterwide configuration
propagation two-phase algorithm. Main function of this module is a
`private` function `_clusterwide(patch)` which accepts `config patch` and
creates new `configuration` by merging old one with current `patch`. After configuration
creation, instance where `_clusterwide` was called, initiates `twophase commit`
for applying this config on cluster instances by `pool.map_call` (map-reduce).

There are three stages at twohphase algorithm:
- Prepare stage:
  From this stage we can go to `Commit` stage if there was no errors and to `Abort` stage
  if error occures at some instances during `map_call`.
  So if error occures at this stage config won't be applied on cluster instances
  (rollbacks to previous config - `config.backup`)

- Commit stage:
  This stage is final.
  If there was no error - config applied.
  But if error occures at this stage on some instances, then this cluster instances
  will be at unconsistent state and there is no way exept manually instances recover.

- Abort stage:
  This stage is final.
  Abort config changes on instances and rollbacks to previous config.

`Twophase` module has `public` wrapper for `_clusterwide` - function `thwophase.patch_clusterwide(patch)`,
also `patch_clusterwide` is a part of public `cartridge` API named `cartridge.config_patch_clusterwide`

# ClusterWideconfig representation

`ClusterWideConfig` configuration is a Lua object in terms OOP programming
You can read more in doc about ClusterWideConfig.

We metioned in `doc` that `ClusterWideConfig` stores data in two formats:
- yaml encoded data
- unmarshalled data

`ClusterWideConfig` contains two tables `_plaintext` (yaml encoded data) and `_luatables`.
`_luatables` is a dynamic `ClusterWideConfig` part - it's unmarshalled `_plaintext` cache
with lazy initialization. When `_paintext` part was updated, `_luatables` invalidates,
and at the next access to `_luatables` data by `ClusterWideConfig` methods this table
will be recreated.


Also `ClusterWideConfig` supports nested configuration files.

### Raw representation

Lets extend example `config` from doc:
```lua
tarantool> cfg = ClusterwideConfig.new({
         >     -- two files in folder
         >     ['text']        = 'Lorem ipsum dolor sit amet',
         >     ['forex.yml']   = '{EURRUB_TOM: 70.33, USDRUB_TOM: 63.18}',
         > })
...

tarantool> cfg
---
- _plaintext:
    forex.yml: '{EURRUB_TOM: 70.33, USDRUB_TOM: 63.18}'
    text: Lorem ipsum dolor sit amet
  locked: false
  _luatables:
    forex.yml: '{EURRUB_TOM: 70.33, USDRUB_TOM: 63.18}'
    forex:
      EURRUB_TOM: 70.33
      USDRUB_TOM: 63.18
    text: Lorem ipsum dolor sit amet
...
```

### Filesystem representation

On filesystem `ClusterWideConfig` is represented by a `File tree`.
So `ClusterWideConfig` supports nested configuration files.
To create nested configuration files, just add section to
`ClusterWideConfig` with path_delimiter `/` (as showd before).

Lets add nested configuration data to previous config:
```lua
tarantool> cfg:set_plaintext('files/files1', 'file1 data')
tarantool> cfg:set_plaintext('files/files2', 'file2 data')
```

This is how config represents on filesystem.
```
|- config_dir
            |- forex.yml
            |- text
            |- files
                   |- file1
                   |- file2
```

# Applying config API

API for apply new config:
- Lua
- Http and Graphql
- Luatest

## Lua API
- `cartridge.config_patch_clusterwide(patch)`
- `cartridge.config_get_deepcopy(section_name)`
- `cartridge.config_get_readonly(section_name)`

This functions are useful for creating custom `cartridge` roles, or custom http handlers,
when you need to store data at `ClusterWideConfig`.

There are also many API endpoints that implicitly calls `patch_clusterwide()`
Some of them:
- Auth: `auth.set_params()`
- Users acl: `add_user`/`edit_user`/`remove_user`
- Topology: `edit_topology` (and deprecated `edit_server`/`expel_server`/`join_server`/`edit_replicaset`)
- Vshard: `vshard-utils.edit_vshard_options()`, `cartridge.admin_bootstrap_vshard()`
- Failover: `lua_api_failover.set_failover_params()`
- DDL: `cartridge_get_schema`/`cartridge_set_schema`

## HTTP and graphql API

Both graphql API and HTTP API don't quering/modifying following cluster sections (named `system_sections`)
- auth, auth.yml,
- topology, topology.yml
- users_acl, users_acl.yml
- vshard, vshard.yml,
- vshard_groups, vshard_groups.yml

Sections has duplicates with/without `.yml` extension, because new ClusterwideConfig works with
`.yml` extension and sections without extension we have to save for backward compatibility.

This sections can't be modified by raw update/download config, but `cartridge` gives public
`graphql`.
Some of them:
- Auth: `add_user`/`edit_user`/`remove_user`
- Topology: `edit_topology` (and deprecated `edit_server`/`expel_server`/`join_server`/`edit_replicaset`) and failover gql endoints

## Graphql API

### Graphql types

```graphql
"""A section of clusterwide configuration"""
type ConfigSection {
  filename: String!
  content: String!
}

"""A section of clusterwide configuration"""
input ConfigSectionInput {
  filename: String!
  content: String
}
```

### Quering config sections:

```graphql
"""Applies updated config on cluster"""
mutation {
  cluster {
    config(sections: [ConfigSectionInput]): [ConfigSection]!
  }
}

"""Get cluster config sections"""
query {
  cluster {
    config(sections: [String!]): [ConfigSection]!
  }
}
```

### Examples

Add example quering and settign, also may be show system section
```graphql
###################################################################
# Upload section
mutation {
  cluster {
    config(sections: [{filename: "file", content: "data"}]) {
      filename
      content
    }
	}
}

# Result of this mutation
{
  "data": {
    "cluster": {
      "config": [{
          "filename": "file",
          "content": "data"
      }]
    }
  }
}

############################################################################
# Upload system secton raises an error
mutation {
  cluster {
    config(sections: [{filename: "vshard.yml", content: "data"}]) {}
	}
}

# Result
{
  "errors": [
    {
      "message": "uploading system section \"vshard.yml\" is forbidden",
    } ...
  ]
}

# Quering sections
query {
  cluster {
    config {
      filename
      content
    }
  }
}

# Result of this query
{
  "data": {
    "cluster": {
      "config": [{
          "filename": "file",
          "content": "data"
      }]
    }
  }
}
```

## HTTP API

Currently supported only uploading/downloading yaml config.

### Upload config:

`HTTP PUT /admin/config`

Example of use:

Lets create config at `~/config.yml`, and fill it with data:

```yml
key: value
```

After upload this config to cluster:

```bash
you@yourmachine $ curl -X PUT http://localhost:8081/admin/config --upload-file ~/config.yml # path to config
```

After that instance logs will be like that:

```log
srv-1 | 2020-04-16 01:39:58.974 [99441] main/147/http/127.0.0.1:64126 api-config.lua:160 W> Config uploaded
srv-1 | 2020-04-16 01:39:58.976 [99441] main/147/http/127.0.0.1:64126 twophase.lua:200 W> Updating config clusterwide...
srv-1 | 2020-04-16 01:39:58.977 [99441] main/147/http/127.0.0.1:64126 twophase.lua:260 W> Clusterwide config didn't change, skipping
```

### Download config:

`HTTP GET /admin/config`

Example of use:

```bash
you@yourmachine $ curl http://localhost:8081/admin/config
---
key: value
...
```

### Luatest API

`cartridge.test_helpers.server` extends basic `luatest.server` with some useful methods, one of
them is `upload_config` - it's a wrapper over `HTTP PUT /admin/config`.

```lua
-- @tparam string|table config - table will be encoded as yaml and posted to /admin/config.
function Server:upload_config(config)
    ...
end
```

Also `cartridge.test_helpers.cluster` has the same method for uploading config
(it's a shortcut for `cluster.main_server:upload_config(config)`).

```lua
function Cluster:upload_config(config)
    ...
end
```

Example of use:

```lua
-- create cluster
g.before_all = function()
  g.cluster = helpers.Cluster.new(...)
end

...

local custom_config = {
  ['custom_config'] = {
      ['Ultimate Question of Life, the Universe, and Everything'] = 42
  }
}
g.cluster:upload_config(custom_config)
```
