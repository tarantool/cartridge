#!/bin/bash

mkdir -p ./dev
export HOSTNAME='localhost'
ALIAS='router'     BINARY_PORT=3301 TARANTOOL_HTTP_PORT=8081 CONSOLE_SOCK=/tmp/1.sock tarantool init.lua & echo $! >> ./dev/pids
ALIAS='s1-master'  BINARY_PORT=3302 TARANTOOL_HTTP_PORT=8082 CONSOLE_SOCK=/tmp/2.sock tarantool init.lua & echo $! >> ./dev/pids
ALIAS='s1-replica' BINARY_PORT=3303 TARANTOOL_HTTP_PORT=8083 CONSOLE_SOCK=/tmp/3.sock tarantool init.lua & echo $! >> ./dev/pids
ALIAS='s2-master'  BINARY_PORT=3304 TARANTOOL_HTTP_PORT=8084 CONSOLE_SOCK=/tmp/4.sock tarantool init.lua & echo $! >> ./dev/pids
ALIAS='s2-replica' BINARY_PORT=3305 TARANTOOL_HTTP_PORT=8085 CONSOLE_SOCk=/tmp/5.sock tarantool init.lua & echo $! >> ./dev/pids
sleep 2.5
echo "All instances started!"
