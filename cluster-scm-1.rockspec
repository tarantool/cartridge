package = 'cluster'
version = 'scm-1'
source  = {
    url = 'git+ssh://git@gitlab.com:tarantool/enterprise/cluster.git',
    branch = 'master',
}
dependencies = {
    'lua >= 5.1',
    'checks == 2.1.1-1',
    'lulpeg == 0.1.2-1',
    'errors == 1.0.0-1',
    'vshard == 0.1.7-1',
    'membership == 2.1.0-1',
}

build = {
    type = 'make';
    install = {
        lua = {
            ['cluster'] = 'cluster.lua';
            ['cluster.vars'] = 'cluster/vars.lua';
            ['cluster.pool'] = 'cluster/pool.lua';
            ['cluster.admin'] = 'cluster/admin.lua';
            ['cluster.utils'] = 'cluster/utils.lua';
            ['cluster.webui'] = 'cluster/webui.lua';
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
    install_variables = {
        -- Installs lua module:
        -- ['cluster.webui-static']
        INST_LUADIR="$(LUADIR)",
    },
}
