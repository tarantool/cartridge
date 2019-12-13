package = 'cartridge'
version = 'scm-1'
source  = {
    url = 'git+https://github.com/tarantool/cartridge.git',
    branch = 'master',
}
dependencies = {
    'lua >= 5.1',
    'ddl == 1.0.0-1',
    'http == 1.0.5-1',
    'checks == 3.0.1-1',
    'lulpeg == 0.1.2-1',
    'errors == 2.1.1-1',
    'vshard == 0.1.14-1',
    'membership == 2.1.4-1',
    'frontend-core == 6.2.0-1',
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
    copy_directories = {'doc'},
}
