## This is a cmake-based script which builds uml images with a help of PlantUML.
# It's intelligent enough to avoid unnecesary rebuilds.
# It calculates *.puml source file hash (md5) and does nothing unless it changes.
# The hash is stored in the resulting svg file as a comment.

# Usage:
#   cmake [-DJUST_CHECK=TRUE] -P rst/BuildUML.cmake

get_filename_component(BASE_DIR "${CMAKE_SCRIPT_MODE_FILE}" DIRECTORY)
message(STATUS "Building UML diagrams")

if (DEFINED ENV{JUST_CHECK})
    set(JUST_CHECK "$ENV{JUST_CHECK}")
endif()

if (NOT JUST_CHECK)
    find_program(PLANTUML_EXECUTABLE plantuml
        HINTS ENV PLANTUML_INSTALL_DIR
        PATH_SUFFIXES bin
    )

    include(FindPackageHandleStandardArgs)
    set(PlantUML_FIND_REQUIRED 1)
    find_package_handle_standard_args(PlantUML
        REQUIRED_VARS PLANTUML_EXECUTABLE
    )
endif()

function(check_hash IMAGE_FILE EXPECTED_MD5)
    if(NOT EXISTS ${IMAGE_FILE})
        set(REBUILD 1 PARENT_SCOPE)
        return()
    endif()

    file(STRINGS "${IMAGE_FILE}" MD5_MATCH
        REGEX "^<!-- _UML_SOURCE_MD5 ${EXPECTED_MD5} -->$"
    )
    if(MD5_MATCH)
        set(REBUILD 0 PARENT_SCOPE)
    else()
        set(REBUILD 1 PARENT_SCOPE)
    endif()
endfunction()

file(GLOB UML_FILES
    "${BASE_DIR}/uml/*.puml"
)

foreach(UML_FILE ${UML_FILES})
    get_filename_component(FILENAME "${UML_FILE}" NAME_WE)
    set(IMAGE_FILE "${BASE_DIR}/images/uml/${FILENAME}.svg")

    file(MD5 ${UML_FILE} UML_SOURCE_MD5)
    check_hash(${IMAGE_FILE} ${UML_SOURCE_MD5})
    if(NOT REBUILD)
        message(STATUS "Skipping ${IMAGE_FILE}")
        continue()
    elseif(JUST_CHECK)
        message(FATAL_ERROR "Checksum mismatch: ${IMAGE_FILE}")
    endif()

    message(STATUS "Building ${IMAGE_FILE} ...")
    execute_process(
        COMMAND "${PLANTUML_EXECUTABLE}"
        "-tsvg"
        "-o" "${BASE_DIR}/images/uml"
        ${UML_FILE}
        RESULT_VARIABLE STATUS
        ERROR_VARIABLE _ERROR
    )
    if(NOT STATUS EQUAL "0")
        file(REMOVE ${IMAGE_FILE})
        message(FATAL_ERROR "${_ERROR}")
    endif()

    file(APPEND ${IMAGE_FILE} "\n\n")
    file(APPEND ${IMAGE_FILE} "<!-- _UML_SOURCE rst/uml/${FILENAME}.puml -->\n")
    file(APPEND ${IMAGE_FILE} "<!-- _UML_SOURCE_MD5 ${UML_SOURCE_MD5} -->\n")
endforeach()
