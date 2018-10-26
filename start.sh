#!/usr/bin/env bash

mkdir -p ./dev/output/

ALIAS=srv-1 WORKDIR=dev/3301 ADVERTISE_URI=localhost:3301 HTTP_PORT=8081 ./pytest/instance.lua &
ALIAS=srv-2 WORKDIR=dev/3302 ADVERTISE_URI=localhost:3302 HTTP_PORT=8082 ./pytest/instance.lua &
ALIAS=srv-3 WORKDIR=dev/3303 ADVERTISE_URI=localhost:3303 HTTP_PORT=8083 ./pytest/instance.lua &
ALIAS=srv-4 WORKDIR=dev/3304 ADVERTISE_URI=localhost:3304 HTTP_PORT=8084 ./pytest/instance.lua &
ALIAS=srv-5 WORKDIR=dev/3305 ADVERTISE_URI=localhost:3305 HTTP_PORT=8085 ./pytest/instance.lua &

echo "All instances stared!"

