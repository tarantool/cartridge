## This is a cmake-based script which builds frontend bundle.
# It's intelligent enough to avoid unnecesary rebuilds.
# It calculates source hash (md5) and does nothing unless it changes.

get_filename_component(BASE_DIR "${CMAKE_SCRIPT_MODE_FILE}" DIRECTORY)
set(REBUILD 0)

function(check_hash HASH_FILE FILES)
    set(__digest "")

    list(SORT FILES)
    foreach(F ${FILES})
        file(RELATIVE_PATH F_RELPATH ${BASE_DIR} ${F})
        file(MD5 ${F} F_MD5)
        list(APPEND __digest "${F_RELPATH};${F_MD5}")
    endforeach()

    string(MD5 MD5_ACTUAL "${__digest}")
    if (NOT EXISTS ${HASH_FILE})
        set(REBUILD 1)
    else()
        file(READ ${HASH_FILE} MD5_CACHED)
        string(STRIP "${MD5_CACHED}" MD5_CACHED)
        if (NOT MD5_CACHED STREQUAL MD5_ACTUAL)
            set(REBUILD 1)
        endif()
    endif()

    set(REBUILD ${REBUILD} PARENT_SCOPE)
    set(MD5_CACHED ${MD5_CACHED} PARENT_SCOPE)
    set(MD5_ACTUAL ${MD5_ACTUAL} PARENT_SCOPE)
endfunction()

## node_modules ###############################################################
###############################################################################

set(HASH_FILE "${BASE_DIR}/node_modules/package-lock.md5")
check_hash(${HASH_FILE} "${BASE_DIR}/package-lock.json")

if (REBUILD)
    message(STATUS "Installing node_modules")
    execute_process(
        COMMAND npm ci --no-audit --no-progress --prefer-offline
        WORKING_DIRECTORY "${BASE_DIR}"
        RESULT_VARIABLE _result
    )
    if (_result)
        message(FATAL_ERROR "npm ci failed (exit ${_result})")
    endif()
    file(WRITE ${HASH_FILE} "${MD5_ACTUAL}")
else()
    message(STATUS "Skipping node_modules installation")
endif()

## bundle.lua #################################################################
###############################################################################

set(HASH_FILE "${BASE_DIR}/build/bundle.md5")
file(GLOB_RECURSE FRONTEND_FILES
    "${BASE_DIR}/src/*"
    "${BASE_DIR}/config/*.prod.js"
    "${BASE_DIR}/flow-typed/*"
    "${BASE_DIR}/public/*"
)
list(APPEND FRONTEND_FILES
    "${BASE_DIR}/.browserslistrc"
    "${BASE_DIR}/.env"
    "${BASE_DIR}/.env.production"
    "${BASE_DIR}/.eslintignore"
    "${BASE_DIR}/.eslintrc.js"
    "${BASE_DIR}/.prettierignore"
    "${BASE_DIR}/.prettierrc.js"
    "${BASE_DIR}/.importsortrc.js"
    "${BASE_DIR}/.flowconfig"
    "${BASE_DIR}/codegen.yml"
    "${BASE_DIR}/package-lock.json"
    "${BASE_DIR}/package.json"
    "${BASE_DIR}/webpack.config.js"
    "${BASE_DIR}/webpack.config.prod.js"
    "${BASE_DIR}/tsconfig.json"
)
check_hash(${HASH_FILE} "${FRONTEND_FILES}")

if (REBUILD)
    message(STATUS "Building WebUI bundle")
    execute_process(
        COMMAND npm run build
        WORKING_DIRECTORY "${BASE_DIR}"
        RESULT_VARIABLE _result
    )
    if (_result)
        message(FATAL_ERROR "npm run build failed (exit ${_result})")
    endif()
    file(WRITE ${HASH_FILE} "${MD5_ACTUAL}")
else()
    message(STATUS "Skipping WebUI bundle build")
endif()
