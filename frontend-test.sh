#!/bin/bash

set -e -x

npm run graphqlgen --prefix=webui
npm run flow --prefix=webui
npm run test_once --prefix=webui
