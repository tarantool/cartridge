#!/bin/sh

set -e

if [ -z "$ENTERPRISE_ROCKS_SERVER" ]
then
	ENTERPRISE_ROCKS_SERVER=$1
fi

if [ -z "$ENTERPRISE_ROCKS_SERVER" ]
then
	ENTERPRISE_ROCKS_SERVER="file://rocks"
fi

tarantoolctl rocks install http 1.0.5 --server=$ENTERPRISE_ROCKS_SERVER
tarantoolctl rocks install lua-term 0.7 --server=$ENTERPRISE_ROCKS_SERVER
tarantoolctl rocks make --server=$ENTERPRISE_ROCKS_SERVER
