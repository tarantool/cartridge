local errors = require('errors')
errors.deprecate(
    "Module `cartridge.graphql.execute` is deprecated." ..
    " Use `require('graphql.execute')` instead."
)

return require('graphql.execute')
