#!/bin/bash

echo "Sending list of test results to ${MONITOR_HOST}..."
curl -s --data-binary "@luatest.log" --cookie "token=${MONITOR_TOKEN}" \
    "${MONITOR_HOST}/api_result/${CI_PROJECT_NAME}/${CI_COMMIT_REF_NAME}/${CI_COMMIT_SHA}/${CI_JOB_ID}/luatest"

if [ "${CI_COMMIT_REF_NAME}" = "master" ]; then
    echo "Sending list of updated tests..."
    LAST_COMMIT=$(curl --cookie "token=${MONITOR_TOKEN}" "${MONITOR_HOST}/api_last/${CI_PROJECT_NAME}")
    DIFF=$(git diff --name-only "${LAST_COMMIT}")
    curl -s -d "${DIFF}" --cookie "token=${MONITOR_TOKEN}" \
        "${MONITOR_HOST}/api_diff/${CI_PROJECT_NAME}/${CI_COMMIT_SHA}"
fi
