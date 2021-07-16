local errors = require('errors')
errors.deprecate(
    "Module `cartridge.graphql.validate` is deprecated." ..
    " Use `require('graphql.validate')` instead."
)

return require('graphql.validate')
