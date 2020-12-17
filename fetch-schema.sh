#!/bin/bash

pushd $(dirname "${BASH_SOURCE[0]}")
tarantool <<LAUNCHER_SCRIPT &
    httpd = require('http.server').new("localhost", 8080)
    httpd:start()
    require('cartridge.webui').init(httpd)
LAUNCHER_SCRIPT
trap "kill %1" EXIT

CHECKSUMS=$(md5sum \
    doc/schema.graphql \
    webui/graphql.schema.json \
    webui/src/generated/graphql-typing.js \
)

npx graphql get-schema -o doc/schema.graphql
sed -i '/^# timestamp:/d' doc/schema.graphql

npm run graphqlgen --prefix=webui

echo
echo "Checking changes"

if (md5sum -c - <<< "$CHECKSUMS"); then
    echo "Everything is up to date!"
else
    echo "Generated sources were updated!"
    exit 1
fi
