local fio = require('fio')
local conf_lib = require('conf')
local topology = require('topology')
local consts = require('topology.client.consts')

-- Settings
local topology_name = "cartridge"
local conf_endpoint = "localhost:2379"
local conf_driver = "etcd"
local datadir = fio.tempdir('/tmp')

-- Create a configuration client.
local urls = { conf_endpoint }
local conf_client = conf_lib.new({driver = conf_driver, endpoints = urls})
assert(conf_client ~= nil)

-- Create a topology.
local t = topology.new(conf_client, topology_name, true, {
    bucket_count = 10000,
    replication_connect_quorum = 1,
})
assert(t ~= nil)

-- Create replicasets.
local replicaset_1_name = 'R'
local replicaset_2_name = 'S-A'
local replicaset_3_name = 'S-B'
t:new_replicaset(replicaset_1_name, {
    weight = 1,
})
t:new_replicaset(replicaset_2_name, {
    weight = 1,
})

-- Create instances.
t:new_instance('cartridge-srv-1', replicaset_1_name, {
    box_cfg = {
        listen = '127.0.0.1:3301',
        work_dir = fio.pathjoin(datadir, 'srv-1_workdir'),
        memtx_dir = fio.pathjoin(datadir, 'srv-1_workdir'),
    },
    advertise_uri = 'storage:storage@127.0.0.1:3301',
    zone = 1,
})
t:new_instance('cartridge-srv-2', replicaset_2_name, {
    box_cfg = {
        listen = '127.0.0.1:3302',
        work_dir = fio.pathjoin(datadir, 'srv-2_workdir'),
        memtx_dir = fio.pathjoin(datadir, 'srv-2_workdir'),
    },
    advertise_uri = 'storage:storage@127.0.0.1:3302',
    zone = 1,
})
t:new_instance('cartridge-srv-3', replicaset_2_name, {
    box_cfg = {
        listen = '127.0.0.1:3303',
        work_dir = fio.pathjoin(datadir, 'srv-3_workdir'),
        memtx_dir = fio.pathjoin(datadir, 'srv-3_workdir'),
    },
    advertise_uri = 'storage:storage@127.0.0.1:3303',
    zone = 1,
})
t:new_instance('cartridge-srv-4', replicaset_3_name, {
    box_cfg = {
        listen = '127.0.0.1:3304',
        work_dir = fio.pathjoin(datadir, 'srv-4_workdir'),
        memtx_dir = fio.pathjoin(datadir, 'srv-4_workdir'),
    },
    advertise_uri = 'storage:storage@127.0.0.1:3304',
    zone = 1,
})
t:new_instance('cartridge-srv-5', replicaset_3_name, {
    box_cfg = {
        listen = '127.0.0.1:3305',
        work_dir = fio.pathjoin(datadir, 'srv-5_workdir'),
        memtx_dir = fio.pathjoin(datadir, 'srv-5_workdir'),
    },
    advertise_uri = 'storage:storage@127.0.0.1:3305',
    zone = 1,
})
