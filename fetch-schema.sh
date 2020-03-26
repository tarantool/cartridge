#!/bin/bash

TARANTOOL_WORKDIR=dev/gql-schema test/entrypoint/srv_basic.lua &
PID=$!

TMP=$(uuidgen).graphql
npx graphql get-schema -o $TMP

OUTPUT="doc/schema.graphql"
diff \
    --ignore-all-space \
    --ignore-blank-lines \
    --ignore-matching-lines "^# timestamp:" \
    $OUTPUT $TMP
DIFF=$?

if [ "$DIFF" -eq 0 ]
then
    echo "GraphQL schema is up to date!"
    rm -f $TMP
else
    echo "GraphQL schema was updated!"
    mv -f $TMP $OUTPUT
fi

kill $PID
exit $DIFF
