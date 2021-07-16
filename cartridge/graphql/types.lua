local errors = require('errors')
errors.deprecate(
    "Module `cartridge.graphql.types` is deprecated." ..
    " Use `require('graphql.types')` instead."
)

return require('graphql.types')
