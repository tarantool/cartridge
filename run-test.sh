#!/bin/bash

set -e

# lint
.rocks/bin/luacheck .

# run tests
./taptest.lua
.rocks/bin/luatest -v

# collect coverage
# .rocks/bin/luacov-console ./cluster
# .rocks/bin/luacov-console -s > coverage_result.txt
# .rocks/bin/luacov-console -s
