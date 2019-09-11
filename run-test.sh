#!/bin/bash

set -e

./taptest.lua
.rocks/bin/luatest -v -c

# lint
.rocks/bin/luacheck cartridge-scm-1.rockspec

# collect coverage
# .rocks/bin/luacov-console ./cluster
# .rocks/bin/luacov-console -s > coverage_result.txt
# .rocks/bin/luacov-console -s
