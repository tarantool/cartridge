cmake_minimum_required(VERSION 2.8 FATAL_ERROR)

project(cluster C)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})
set(CMAKE_SKIP_INSTALL_ALL_DEPENDENCY TRUE)

# Find Tarantool and Lua dependecies
set(TARANTOOL_FIND_REQUIRED ON)
find_package(Tarantool)
include_directories(${TARANTOOL_INCLUDE_DIRS})

get_filename_component(WEB_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/webui" ABSOLUTE)

file(GLOB_RECURSE FRONTEND_FILES
  "${CMAKE_CURRENT_SOURCE_DIR}/webui/src/*.js"
  "${CMAKE_CURRENT_SOURCE_DIR}/webui/src/*.css"
)

file(GLOB_RECURSE LUA_FILES
  "${CMAKE_CURRENT_SOURCE_DIR}/cluster.lua"
  "${CMAKE_CURRENT_SOURCE_DIR}/cluster/*.lua"
)

## Webui ######################################################################
###############################################################################

add_custom_command(
  OUTPUT ${WEB_ROOT}/node_modules
  COMMAND NODE_ENV=production npm ci --prefix "${WEB_ROOT}"
  DEPENDS "${WEB_ROOT}/package.json"
  COMMENT "Installing node_modules"
)

add_custom_command(
  OUTPUT ${WEB_ROOT}/build/bundle.lua
  COMMAND npm run build --prefix "${WEB_ROOT}"
  DEPENDS ${WEB_ROOT}/node_modules ${FRONTEND_FILES}
  COMMENT "Building web archive"
)

add_custom_target(fornt-bundle ALL
  DEPENDS ${WEB_ROOT}/build/bundle.lua
)

## API doc ####################################################################
###############################################################################

set(DOC_OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/doc/index.html)

add_custom_command(
  OUTPUT DOC_OUTPUT
  COMMAND ldoc -t "${PROJECT_NAME}-${version}" -p "${PROJECT_NAME} (${version})" --all .
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  DEPENDS ${LUA_FILES}
  COMMENT "Building API documentation"
  VERBATIM
)

if(BUILD_DOC)
  add_custom_target(doc ALL
    DEPENDS DOC_OUTPUT)
else()
  add_custom_target(doc
    DEPENDS DOC_OUTPUT)
endif()

## GraphQL schema #############################################################
###############################################################################

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/doc/schema.graphql
  COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/fetch-schema.sh
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  DEPENDS ${LUA_FILES}
  COMMENT "Fetching GraphQL schema"
)
add_custom_target(schema
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/doc/schema.graphql
)

## Testing ####################################################################
###############################################################################

enable_testing()

add_test(
  NAME lint
  COMMAND luacheck cluster-scm-1.rockspec
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)

add_test(
  NAME test_unit
  COMMAND ${TARANTOOL} ${CMAKE_CURRENT_SOURCE_DIR}/taptest.lua
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)

add_test(
  NAME test_integration
  COMMAND pytest -v
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)

## Install ####################################################################
###############################################################################

install(CODE "")
