#!/bin/bash

npm run graphqlgen --prefix=webui
npm run flow --prefix=webui
npm run test_once --prefix=webui
