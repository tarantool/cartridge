#!/bin/bash

SCRIPT=./test/integration/srv_basic.lua

if [[ -n "$1" ]]
then
	SCRIPT="$1"
fi

mkdir -p ./dev
$SCRIPT --alias srv-1 --workdir dev/3301 --advertise-uri localhost:3301 --http-port 8081 & echo $! >> ./dev/pids
$SCRIPT --alias srv-2 --workdir dev/3302 --advertise-uri localhost:3302 --http-port 8082 & echo $! >> ./dev/pids
$SCRIPT --alias srv-3 --workdir dev/3303 --advertise-uri localhost:3303 --http-port 8083 & echo $! >> ./dev/pids
$SCRIPT --alias srv-4 --workdir dev/3304 --advertise-uri localhost:3304 --http-port 8084 & echo $! >> ./dev/pids
$SCRIPT --alias srv-5 --workdir dev/3305 --advertise-uri localhost:3305 --http-port 8085 & echo $! >> ./dev/pids
sleep 1.5
echo "All instances started!"
