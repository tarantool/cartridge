#!/bin/bash

set -e

WORKDIR=dev/gql-schema test/integration/instance.lua &
PID=$!
graphql get-schema -o doc/schema.graphql
kill $PID
