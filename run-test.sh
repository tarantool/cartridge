#!/bin/bash

set -e

# lint
.rocks/bin/luacheck .

# run tests
./taptest.lua
.rocks/bin/luatest -v --coverage

# collect coverage
.rocks/bin/luacov-console `pwd`
.rocks/bin/luacov-console -s
