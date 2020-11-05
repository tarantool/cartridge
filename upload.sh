#!/bin/bash

URL=https://rocks.tarantool.org
echo "Uploading $1 to $URL"
exec curl --fail -X PUT -F "rockspec=@$1" \
	-u "${ROCKS_USERNAME}:${ROCKS_PASSWORD}" $URL

