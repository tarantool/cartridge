# Clusterwide configuration

Cartridge orchestrates a distributed system of Tarantool instances - a
cluster. One of the core concepts is a **clusterwide configuration**.
Every instance in cluster stores a copy of it.

Clusterwide configuration contains the options that must be identical on
every cluster node, such as topology of the cluster, failover and vshard
configuration, authentication parameters and ACLs, and user-defined
configuration.

Clusterwide configuration doesn't provide instance specific parameters:
ports, workdirs, memory settings etc.

## Internal representation

On file system clusterwide configuration is represented by a **file
tree**. Inside `workdir` of any configured instance one can find the
following directory:

```text
config/
├── auth.yml
├── topology.yml
└── vshard_groups.yml
```

This is the clusterwide configuration with three default **config
sections** - `auth`, `topology`, and `vshard_groups`.

Due to historical reasons clusterwide configuration has two appearances:
old-style single-file `config.yml` with all sections combined, and
modern multi-file representation mentioned above. Before cartridge v2.0
it used to look as follows, and this representation is still used in
HTTP API and luatest helpers.

```yaml
# config.yml
---
auth: {...}
topology: {...}
vshard_groups: {...}
...
```

Beyond these essential sections clusterwide configuration may be used
for storing some other role-specific data. Clusterwide configuration
supports YAML as well as plain text sections. It can also be organized
in nested subdirectories.

In Lua it's represented by `ClusterwideConfig` object (a table with
metamethods). Refer to `cartridge.clusterwide-config` module
documentation for more details.

## Two-phase commit

Cartridge manages clusterwide configuration to be identical everywhere
by two-phase commit algorithm implemented in `cartridge.twophase`
module. Modification of clusterwide configuration implies applying it on
every instance in the cluster.

Almost every modyfication of cluster parameters triggers it:
joining/expelling a server, editing replicaset roles, managing users,
setting failover and vshard configuration.

Two-phase commit require all instances to be alive and healthy,
otherwise it returns an error.

For more details, please, refer to the
`cartridge.config_patch_clusterwide` API reference.

## Managing role-specific data

Beside system sections clusterwide configuration may be used for storing
some other **role-specific data**. It supports YAML as well as plain
text sections. And it can also be organized in nested subdirectories.

Role-specific sections are used by some third-party roles, i.e.
[sharded-queue](https://github.com/tarantool/sharded-queue) and
[cartridge-extensions](https://github.com/tarantool/cartridge-extensions).

A user can influence clusterwide configuration in various ways. One can
alter configuration using Lua, HTTP or GraphQL API. Also there are
Luatest helpers available.

### HTTP API

It works with old-style single-file representation only. It's useful
when there are only few sections needed.

Example:

```bash
cat > config.yml << CONFIG
---
custom_section: {}
...
CONFIG
```

Upload new config:

```bash
curl -v "localhost:8081/admin/config" -X PUT --data-binary @config.yml
```

Download it:

```bash
curl -v "localhost:8081/admin/config" -o config.yml
```

It's suitable for role-specific sections only. System sections
(`topology`, `auth`, `vshard_groups`, `users_acl`) can't be neither
uploaded nor downloaded.

### GraphQL API

GraphQL API, by contrast, is only suitable for managing plain-text
sections in modern multi-file appearance. It is mostly used by WebUI,
but sometimes it's also helpful in tests:

```lua
g.cluster.main_server:graphql({query = [[
    mutation($sections: [ConfigSectionInput!]) {
        cluster {
            config(sections: $sections) {
                filename
                content
            }
        }
    }]],
    variables = {sections = {
      {
        filename = 'custom_section.yml',
        content = '---\n{}\n...',
      }
    }}
})
```

Unlike HTTP API, GraphQL affects only sections mentioned in query. All
other sections remain unchanged.

Similar to HTTP API, GraphQL `cluster {config}` query isn't suitable for
managing system sections.

### Lua API

It's not the most convenient way to configure third-party role, but it
may be useful for the role developer. Please, refer to according API
reference:

- `cartridge.config_patch_clusterwide`
- `cartridge.config_get_deepcopy`
- `cartridge.config_get_readonly`

Example (from `sharded-queue`, simplified):

```lua
function create_tube(tube_name, tube_opts)
    local tubes = cartridge.config_get_deepcopy('tubes') or {}
    tubes[tube_name] = tube_opts or {}

    return cartridge.config_patch_clusterwide({tubes = tubes})
end

local function validate_config(conf)
    local tubes = conf.tubes or {}
    for tube_name, tube_opts in pairs(tubes) do
        -- validate tube_opts
    end
    return true
end

local function apply_config(conf, opts)
    if opts.is_master then
        local tubes = cfg.tubes or {}
        -- create tubes according to the configuration
    end
    return true
end
```

### Luatest helpers

Cartridge test helpers provide methods for configuration management:

- `cartridge.test-helpers.cluster:upload_config`,
- `cartridge.test-helpers.cluster:download_config`.

Internally they wrap HTTP API.

Example:

```lua
g.before_all(function()
    g.cluster = helpers.Cluster.new(...)
    g.cluster:upload_config({some_section = 'some_value'})
    t.assert_equals(
        g.cluster:download_config(),
        {some_section = 'some_value'}
    )
end)
```
