#!/bin/bash

set -e

./taptest.lua
.rocks/bin/luatest -v

# lint
.rocks/bin/luacheck cluster-scm-1.rockspec

# collect coverage
.rocks/bin/luacov-console ./cluster
.rocks/bin/luacov-console -s > coverage_result.txt
.rocks/bin/luacov-console -s
