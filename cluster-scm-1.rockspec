package = 'cluster'
version = 'scm-1'
source  = {
    url = 'git+ssh://git@gitlab.com:tarantool/enterprise/cluster.git',
    branch = 'master',
}
dependencies = {
    'lua >= 5.1',
    'http == 1.0.5-1',
    'checks == 3.0.0-1',
    'lulpeg == 0.1.2-1',
    'errors == 2.1.1-1',
    'vshard == 0.1.9-1',
    'membership == 2.1.1-1',
    'frontend-core == 5.0.1-1',
}

external_dependencies = {
    TARANTOOL = {
        header = 'tarantool/module.h',
    },
}

build = {
    type = 'cmake',
    variables = {
        version = 'scm-1',
        BUILD_DOC = '$(BUILD_DOC)',
        TARANTOOL_DIR = '$(TARANTOOL_DIR)',
        TARANTOOL_INSTALL_LIBDIR = '$(LIBDIR)',
        TARANTOOL_INSTALL_LUADIR = '$(LUADIR)',
    },
    install = {
        lua = {
            ['cluster'] = 'cluster.lua',
            ['cluster.rpc'] = 'cluster/rpc.lua',
            ['cluster.vars'] = 'cluster/vars.lua',
            ['cluster.pool'] = 'cluster/pool.lua',
            ['cluster.auth'] = 'cluster/auth.lua',
            ['cluster.admin'] = 'cluster/admin.lua',
            ['cluster.utils'] = 'cluster/utils.lua',
            ['cluster.webui'] = 'cluster/webui.lua',
            ['cluster.webui.api-auth'] = 'cluster/webui/api-auth.lua',
            ['cluster.webui.api-config'] = 'cluster/webui/api-config.lua',
            ['cluster.webui.api-vshard'] = 'cluster/webui/api-vshard.lua',
            ['cluster.webui.api-topology'] = 'cluster/webui/api-topology.lua',
            ['cluster.webui.gql-stat'] = 'cluster/webui/gql-stat.lua',
            ['cluster.webui.gql-boxinfo'] = 'cluster/webui/gql-boxinfo.lua',
            ['cluster.topology'] = 'cluster/topology.lua',
            ['cluster.bootstrap'] = 'cluster/bootstrap.lua',
            ['cluster.confapplier'] = 'cluster/confapplier.lua',
            ['cluster.cluster-cookie'] = 'cluster/cluster-cookie.lua',
            ['cluster.service-registry'] = 'cluster/service-registry.lua',
            ['cluster.label-utils'] = 'cluster/label-utils.lua',

            ['cluster.vshard-utils'] = 'cluster/vshard-utils.lua',
            ['cluster.roles.vshard-router'] = 'cluster/roles/vshard-router.lua',
            ['cluster.roles.vshard-storage'] = 'cluster/roles/vshard-storage.lua',

            ['cluster.graphql'] = 'cluster/graphql.lua',
            ['cluster.graphql.execute'] = 'cluster/graphql/execute.lua',
            ['cluster.graphql.funcall'] = 'cluster/graphql/funcall.lua',
            ['cluster.graphql.introspection'] = 'cluster/graphql/introspection.lua',
            ['cluster.graphql.parse'] = 'cluster/graphql/parse.lua',
            ['cluster.graphql.rules'] = 'cluster/graphql/rules.lua',
            ['cluster.graphql.schema'] = 'cluster/graphql/schema.lua',
            ['cluster.graphql.types'] = 'cluster/graphql/types.lua',
            ['cluster.graphql.util'] = 'cluster/graphql/util.lua',
            ['cluster.graphql.validate'] = 'cluster/graphql/validate.lua',
            ['cluster.front-bundle'] = 'webui/build/bundle.lua',
        },
    },
    copy_directories = {'doc'},
}
