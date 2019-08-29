#!/bin/bash

if [ -e ./dev/pids ]
then
    cat ./dev/pids | xargs kill -SIGINT || true
    rm ./dev/pids
fi
