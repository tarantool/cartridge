#!/bin/bash
#
# Usage examples:
#
# ./cypress-test.sh
# ./cypress-test.sh open
# ./cypress-test.sh run --spec ./webui/cypress/integration/plugin.spec.js

if [ -z "$1" ] ; then set -- "run" ; fi
set -e -x

pushd $(dirname "${BASH_SOURCE[0]}")
tarantool <<LAUNCHER_SCRIPT &
    log = require('log')
    fio = require('fio')
    helpers = require('test.helper')
    require('console').listen('127.0.0.1:3333')

    httpd = require('http.server').new("localhost", 8080)
    httpd:start()

    _G.server = nil
    _G.cluster = nil

    function cleanup()
        print('----- Performing cleanup -----')
        pcall(function() httpd:stop() end)
        if _G.server ~= nil then
            _G.server:stop()
            fio.rmtree(_G.server.workdir)
            _G.server = nil
        end
        if _G.cluster ~= nil then
            _G.cluster:stop()
            fio.rmtree(_G.cluster.datadir)
            _G.cluster = nil
        end
    end
LAUNCHER_SCRIPT

trap "kill %1" EXIT

export NODE_ENV=production
export BABEL_ENV=$NODE_ENV
npx cypress "$@" -P webui/
