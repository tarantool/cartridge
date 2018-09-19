#!/bin/sh

set -e

if [ -z "$ENTERPRISE_ROCKS_SERVER" ]
then
	ENTERPRISE_ROCKS_SERVER=$1
fi

if [ -z "$ENTERPRISE_ROCKS_SERVER" ]
then
	echo "Usage: $0 ENTERPRISE_ROCKS_SERVER"
	echo "Hint: use "
	echo "    export ENTERPRISE_ROCKS_SERVER=file:///path/to/enterprise/rocks/repo"
	exit 1
fi

tarantoolctl rocks install http 1.0.5
tarantoolctl rocks install lua-term 0.7
tarantoolctl rocks make --server=$ENTERPRISE_ROCKS_SERVER
