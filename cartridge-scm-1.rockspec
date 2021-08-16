package = 'cartridge'
version = 'scm-1'
source  = {
    url = 'git+https://github.com/tarantool/cartridge.git',
    branch = 'master',
}
dependencies = {
    'lua >= 5.1',
    'ddl == 1.5.0-1',
    'http == 1.1.0-1',
    'checks == 3.1.0-1',
    'errors == 2.2.1-1',
    'vshard == 0.1.18-1',
    'membership == 2.4.0-1',
    'frontend-core == 7.10.0-1',
    'graphql == 0.1.1-1',
}

external_dependencies = {
    TARANTOOL = {
        header = 'tarantool/module.h',
    },
}

build = {
    type = 'cmake',
    variables = {
        TARANTOOL_DIR = '$(TARANTOOL_DIR)',
        TARANTOOL_INSTALL_LIBDIR = '$(LIBDIR)',
        TARANTOOL_INSTALL_LUADIR = '$(LUADIR)',
        TARANTOOL_INSTALL_BINDIR = '$(BINDIR)',
    },
    copy_directories = {'doc'},
}
