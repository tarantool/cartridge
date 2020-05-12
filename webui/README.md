# Cartridge frontend documentation

## Emittable frontend core events

Events dispatchable by module `cartridge`:

`cluster:login:done` - Emits after succesful authorization. Provides object describing auth state and username.

`cluster:logout:done` - Emits after succesful logging out.
