# Cartridge frontend documentation

## Configurable parameters via frontend core variables

`cartridge_refresh_interval` - Cluster topology refresh interval.

`cartridge_stat_period` - Refresh period for all cluster stats
(includes issues, suggestions and server stats).

`cartridge_hide_all_rw` - Hide 'Make all instances writeable' configuration field
('Create replica set' and 'Edit replica set' forms).

## Emittable frontend core events

Events dispatchable by module `cartridge`:

`cluster:login:done` - Emits after successful authorization.
Provides object describing auth state and username.

`cluster:logout:done` - Emits after successful logging out.
