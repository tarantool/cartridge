#!/bin/bash

WORKDIR=dev/gql-schema test/integration/instance.lua &
PID=$!

TMP=$(mktemp --suffix .graphql)
graphql get-schema -o $TMP

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
