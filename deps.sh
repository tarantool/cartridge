#!/bin/sh

set -e

tarantoolctl rocks install http 1.0.5
tarantoolctl rocks make
