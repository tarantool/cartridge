## Try Cartridge

According to @artur-barsegyan's proposal we'll implement new cartridge
role - `extensions`.

All `extensions/*.lua` files will be loaded as Lua modules.
They'll be accessible through

```lua
local extensions = require('cartridge').service_get('extensions')
local banking = extensions.get('banking') -- TODO ban cycle deps
```

Also `extensions/config.yml` describes how to export those modules in
serverless style. For now we'll support the only event `binary`:

```yml
functions:
  transfer_money:
    module: banking
    handler: transfer_money
    events:
    - binary:
      # It'll assign _G.__transfer_money = banking.transfer_money
        path: __transfer_money
```
