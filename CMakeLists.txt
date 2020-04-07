cmake_minimum_required(VERSION 2.8 FATAL_ERROR)

project(cartridge C)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})
set(CMAKE_SKIP_INSTALL_ALL_DEPENDENCY TRUE)

# Find Tarantool and Lua dependecies
set(TARANTOOL_FIND_REQUIRED ON)
find_package(Tarantool)
include_directories(${TARANTOOL_INCLUDE_DIRS})

get_filename_component(WEB_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/webui" ABSOLUTE)

file(GLOB_RECURSE FRONTEND_FILES
  "${CMAKE_CURRENT_SOURCE_DIR}/webui/src/*.js"
  "${CMAKE_CURRENT_SOURCE_DIR}/webui/src/*.svg"
  "${CMAKE_CURRENT_SOURCE_DIR}/webui/config/*.prod.js"
  "${CMAKE_CURRENT_SOURCE_DIR}/webui/scripts/build.js"
  "${CMAKE_CURRENT_SOURCE_DIR}/webui/src/*.css"
)

file(GLOB_RECURSE LUA_FILES
  "${CMAKE_CURRENT_SOURCE_DIR}/cartridge.lua"
  "${CMAKE_CURRENT_SOURCE_DIR}/cartridge/*.lua"
)

## VERSION ####################################################################
###############################################################################

execute_process(
  COMMAND git describe --tags --always
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  OUTPUT_STRIP_TRAILING_WHITESPACE
  OUTPUT_VARIABLE GIT_DESCRIBE
  ERROR_QUIET
)

if (NOT GIT_DESCRIBE)
  set(GIT_DESCRIBE "unknown")
endif()

configure_file (
  "${PROJECT_SOURCE_DIR}/cartridge/VERSION.lua.in"
  "${CMAKE_CURRENT_BINARY_DIR}/VERSION.lua"
)

## Webui ######################################################################
###############################################################################
add_custom_command(
  OUTPUT ${WEB_ROOT}/node_modules
  COMMAND NODE_ENV=production npm ci --prefix "${WEB_ROOT}"
  DEPENDS "${WEB_ROOT}/package-lock.json"
  COMMENT "Installing node_modules"
)

add_custom_command(
  OUTPUT ${WEB_ROOT}/build/bundle.lua
  COMMAND npm run build --prefix "${WEB_ROOT}"
  DEPENDS ${WEB_ROOT}/node_modules ${FRONTEND_FILES}
  COMMENT "Building web archive"
)

if(DEFINED ENV{CMAKE_DUMMY_WEBUI})
  set(DUMMY_WEBUI "$ENV{CMAKE_DUMMY_WEBUI}")
endif()

if(DUMMY_WEBUI)
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/front-bundle.fake.lua"
    "return {__data = function() return {} end}\n"
  )
  add_custom_target(front-bundle ALL
    COMMAND ${CMAKE_COMMAND} -E copy
      "${CMAKE_CURRENT_BINARY_DIR}/front-bundle.fake.lua"
      "${CMAKE_CURRENT_BINARY_DIR}/front-bundle.lua"
    COMMENT "Generating fake front-bundle.lua"
    VERBATIM
  )
else()
  add_custom_target(front-bundle ALL
    DEPENDS "${WEB_ROOT}/build/bundle.lua"
    COMMAND ${CMAKE_COMMAND} -E copy
      "${WEB_ROOT}/build/bundle.lua"
      "${CMAKE_CURRENT_BINARY_DIR}/front-bundle.lua"
    COMMENT "Copying real front-bundle.lua"
    VERBATIM
  )
endif()


## API doc ####################################################################
###############################################################################

set(DOC_OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/doc/index.html)

if(DEFINED ENV{CMAKE_LDOC_FIND_REQUIRED})
  set(LDOC_FIND_REQUIRED "$ENV{CMAKE_LDOC_FIND_REQUIRED}")
endif()
find_package(Ldoc)

add_custom_command(
  OUTPUT DOC_OUTPUT
  COMMAND ${LDOC} --all .
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  DEPENDS ${LUA_FILES}
  COMMENT "Building API documentation"
  VERBATIM
)

if(LDOC_FOUND)
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
  COMMAND luacheck cartridge-scm-1.rockspec
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

install(
  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_NAME}
  DESTINATION ${TARANTOOL_INSTALL_LUADIR}
)

install(
  FILES ${CMAKE_CURRENT_SOURCE_DIR}/cartridge.lua
  DESTINATION ${TARANTOOL_INSTALL_LUADIR}
)

file(
    WRITE ${TARANTOOL_INSTALL_BINDIR}/stateboard
    "#!/usr/bin/env tarantool\n\nrequire('cartridge.stateboard').cfg()\n"
)

install(
  FILES
    ${CMAKE_CURRENT_BINARY_DIR}/VERSION.lua
    ${CMAKE_CURRENT_BINARY_DIR}/front-bundle.lua
  DESTINATION ${TARANTOOL_INSTALL_LUADIR}/${PROJECT_NAME}/
)
