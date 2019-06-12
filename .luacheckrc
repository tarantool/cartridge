redefined = false
exclude_files = {
    'cluster/graphql.lua',
    'cluster/graphql/*.lua',
    'webui/build/bundle.lua',
}
new_read_globals = {
    'box',
    table = {
        fields = {
            'maxn',
            'copy',
            'new',
            'clear',
            'move',
            'foreach',
            'sort',
            'remove',
            'foreachi',
            'deepcopy',
            'getn',
            'concat',
            'insert',
        },
    }
}
