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
    'errors == 2.0.1-1',
    'vshard == 0.1.7-1',
    'membership == 2.1.1-1',
    'frontend-core == 4.0.0-1',
}

build = {
    type = 'make',
    build_target = 'all',
    install = {
        lua = {
            ['cluster'] = 'cluster.lua';
            ['cluster.rpc'] = 'cluster/rpc.lua';
            ['cluster.vars'] = 'cluster/vars.lua';
            ['cluster.pool'] = 'cluster/pool.lua';
            ['cluster.auth'] = 'cluster/auth.lua';
            ['cluster.admin'] = 'cluster/admin.lua';
            ['cluster.utils'] = 'cluster/utils.lua';
            ['cluster.webui'] = 'cluster/webui.lua';
            ['cluster.webui.auth'] = 'cluster/webui/auth.lua';
            ['cluster.topology'] = 'cluster/topology.lua';
            ['cluster.bootstrap'] = 'cluster/bootstrap.lua';
            ['cluster.confapplier'] = 'cluster/confapplier.lua';
            ['cluster.cluster-cookie'] = 'cluster/cluster-cookie.lua';
            ['cluster.service-registry'] = 'cluster/service-registry.lua';

            ['cluster.graphql'] = 'cluster/graphql.lua';
            ['cluster.graphql.execute'] = 'cluster/graphql/execute.lua';
            ['cluster.graphql.funcall'] = 'cluster/graphql/funcall.lua';
            ['cluster.graphql.introspection'] = 'cluster/graphql/introspection.lua';
            ['cluster.graphql.parse'] = 'cluster/graphql/parse.lua';
            ['cluster.graphql.rules'] = 'cluster/graphql/rules.lua';
            ['cluster.graphql.schema'] = 'cluster/graphql/schema.lua';
            ['cluster.graphql.types'] = 'cluster/graphql/types.lua';
            ['cluster.graphql.util'] = 'cluster/graphql/util.lua';
            ['cluster.graphql.validate'] = 'cluster/graphql/validate.lua';
        },
    },
    build_variables = {
        version = 'scm-1',
    },
    install_variables = {
        -- Installs lua module:
        -- ['cluster.front-bundle']
        INST_LUADIR="$(LUADIR)",
    },
    copy_directories = {'doc'},
}
