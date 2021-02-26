local errors = require('errors')
errors.deprecate(
    "Module `cartridge.graphql.schema` is deprecated." ..
    " Use `require('graphql.schema')` instead."
)

return require('graphql.schema')
