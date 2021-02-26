local errors = require('errors')
errors.deprecate(
    "Module `cartridge.graphql.parse` is deprecated." ..
    " Use `require('graphql.parse')` instead."
)

return require('graphql.parse')
