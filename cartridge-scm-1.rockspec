package = 'cartridge'
version = 'scm-1'
source  = {
    url = 'git+https://github.com/tarantool/cartridge.git',
    branch = 'master',
}
dependencies = {
    'lua >= 5.1',
    'http == 1.0.5-1',
    'checks == 3.0.1-1',
    'lulpeg == 0.1.2-1',
    'errors == 2.1.1-1',
    'vshard == 0.1.9-1',
    'membership == 2.1.4-1',
    'frontend-core == 6.0.1-1',
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
            ['cartridge'] = 'cartridge.lua',
            ['cartridge.rpc'] = 'cartridge/rpc.lua',
            ['cartridge.vars'] = 'cartridge/vars.lua',
            ['cartridge.pool'] = 'cartridge/pool.lua',
            ['cartridge.auth'] = 'cartridge/auth.lua',
            ['cartridge.auth-backend'] = 'cartridge/auth-backend.lua',
            ['cartridge.admin'] = 'cartridge/admin.lua',
            ['cartridge.utils'] = 'cartridge/utils.lua',
            ['cartridge.webui'] = 'cartridge/webui.lua',
            ['cartridge.webui.api-auth'] = 'cartridge/webui/api-auth.lua',
            ['cartridge.webui.api-config'] = 'cartridge/webui/api-config.lua',
            ['cartridge.webui.api-vshard'] = 'cartridge/webui/api-vshard.lua',
            ['cartridge.webui.api-topology'] = 'cartridge/webui/api-topology.lua',
            ['cartridge.webui.gql-stat'] = 'cartridge/webui/gql-stat.lua',
            ['cartridge.webui.gql-boxinfo'] = 'cartridge/webui/gql-boxinfo.lua',
            ['cartridge.feedback'] = 'cartridge/feedback.lua',
            ['cartridge.argparse'] = 'cartridge/argparse.lua',
            ['cartridge.topology'] = 'cartridge/topology.lua',
            ['cartridge.bootstrap'] = 'cartridge/bootstrap.lua',
            ['cartridge.confapplier'] = 'cartridge/confapplier.lua',
            ['cartridge.remote-control'] = 'cartridge/remote-control.lua',
            ['cartridge.cluster-cookie'] = 'cartridge/cluster-cookie.lua',
            ['cartridge.service-registry'] = 'cartridge/service-registry.lua',
            ['cartridge.label-utils'] = 'cartridge/label-utils.lua',

            ['cartridge.vshard-utils'] = 'cartridge/vshard-utils.lua',
            ['cartridge.roles.vshard-router'] = 'cartridge/roles/vshard-router.lua',
            ['cartridge.roles.vshard-storage'] = 'cartridge/roles/vshard-storage.lua',

            ['cartridge.graphql'] = 'cartridge/graphql.lua',
            ['cartridge.graphql.execute'] = 'cartridge/graphql/execute.lua',
            ['cartridge.graphql.funcall'] = 'cartridge/graphql/funcall.lua',
            ['cartridge.graphql.introspection'] = 'cartridge/graphql/introspection.lua',
            ['cartridge.graphql.parse'] = 'cartridge/graphql/parse.lua',
            ['cartridge.graphql.rules'] = 'cartridge/graphql/rules.lua',
            ['cartridge.graphql.schema'] = 'cartridge/graphql/schema.lua',
            ['cartridge.graphql.types'] = 'cartridge/graphql/types.lua',
            ['cartridge.graphql.util'] = 'cartridge/graphql/util.lua',
            ['cartridge.graphql.validate'] = 'cartridge/graphql/validate.lua',
            ['cartridge.front-bundle'] = 'webui/build/bundle.lua',

            ['cartridge.test-helpers'] = 'cartridge/test-helpers.lua',
            ['cartridge.test-helpers.server'] = 'cartridge/test-helpers/server.lua',
            ['cartridge.test-helpers.cluster'] = 'cartridge/test-helpers/cluster.lua',
        },
    },
    copy_directories = {'doc'},
}
