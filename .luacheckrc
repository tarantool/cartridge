redefined = false
ignore = {
	"542", -- empty if branch
}
include_files = {
    '*.lua',
    'test/**/*.lua',
    'cartridge/**/*.lua',
    '*.rockspec',
    '.luacheckrc',
}
exclude_files = {
    '.rocks',
    'cartridge/graphql.lua',
    'cartridge/graphql/*.lua',
}
