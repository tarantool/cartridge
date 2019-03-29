#!/usr/bin/env tarantool

local admin = require('cluster.admin')
local gql_types = require('cluster.graphql.types')

local statistics_schema = {
    kind = gql_types.object({
        name = 'ServerStat',
        description = 'Slab allocator statistics.' ..
            ' This can be used to monitor the total' ..
            ' memory usage (in bytes) and memory fragmentation.',
        fields = {
            items_size = {
                kind = gql_types.long.nonNull,
                description =
                    'The total amount of memory' ..
                    ' (including allocated, but currently free slabs)' ..
                    ' used only for tuples, no indexes',
            },
            items_used = {
                kind = gql_types.long.nonNull,
                description =
                    'The efficient amount of memory' ..
                    ' (omitting allocated, but currently free slabs)' ..
                    ' used only for tuples, no indexes',
            },
            items_used_ratio = {
                kind = gql_types.string.nonNull,
                description =
                    '= items_used / slab_count * slab_size' ..
                    ' (these are slabs used only for tuples, no indexes)',
            },

            quota_size = {
                kind = gql_types.long.nonNull,
                description =
                    'The maximum amount of memory that the slab allocator' ..
                    ' can use for both tuples and indexes' ..
                    ' (as configured in the memtx_memory parameter)',
            },
            quota_used = {
                kind = gql_types.long.nonNull,
                description =
                    'The amount of memory that is already distributed' ..
                    ' to the slab allocator',
            },
            quota_used_ratio = {
                kind = gql_types.string.nonNull,
                description =
                    '= quota_used / quota_size',
            },

            arena_size = {
                kind = gql_types.long.nonNull,
                description =
                    'The total memory used for tuples and indexes together' ..
                    ' (including allocated, but currently free slabs)',
            },
            arena_used = {
                kind = gql_types.long.nonNull,
                description =
                    'The efficient memory used for storing' ..
                    ' tuples and indexes together' ..
                    ' (omitting allocated, but currently free slabs)',
            },
            arena_used_ratio = {
                kind = gql_types.string.nonNull,
                description =
                    '= arena_used / arena_size',
            },
        }
    }),
    arguments = {},
    resolve = function(root, _)
        return admin.get_stat(root.uri)
    end,
}

return {
    schema = statistics_schema,
}
