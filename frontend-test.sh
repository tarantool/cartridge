#!/bin/bash

set -e -x

time npm run graphqlgen --prefix=webui
time npm run flow --prefix=webui
time npm run test_once --prefix=webui
