local errors = require('errors')
errors.deprecate(
    "Module `cartridge.graphql.funcall` is deprecated." ..
    " Use `require('cartridge.funcall')` instead."
)

require('cartridge.funcall')
