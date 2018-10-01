#!/bin/sh

set -e

if [ -n "$1" ]
then
    ROCKS_SERVER=$1
fi

if [ -z "$ROCKS_SERVER" ]
then
    echo "Usage: $0 ROCKS_SERVER"
    exit 1
fi

tarantoolctl rocks --server=$ROCKS_SERVER install http 1.0.5
tarantoolctl rocks --server=$ROCKS_SERVER make
