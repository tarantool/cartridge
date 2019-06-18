#!/bin/bash

./taptest.lua

# collect coverage
.rocks/bin/luacov-console ./cluster
.rocks/bin/luacov-console -s > coverage_result.txt
.rocks/bin/luacov-console -s
