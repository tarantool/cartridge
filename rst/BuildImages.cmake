## This is a cmake-based script which builds uml images with a help of PlantUML.
# It's intelligent enough to avoid unnecesary rebuilds.
# It calculates uml source hash (md5) and does nothing unless it changes.

message(STATUS "Checking if uml sources has been changed")

if (NOT DEFINED JUST_CHECK)
    if (DEFINED ENV{JUST_CHECK})
        set(JUST_CHECK "$ENV{JUST_CHECK}")
    endif()
endif()

get_filename_component(BASE_DIR "${CMAKE_SCRIPT_MODE_FILE}" DIRECTORY)

function(check_hash UML_FILE IMAGE_FILE)
    file(MD5 ${UML_FILE} UML_HASH)
    set(UML_HASH ${UML_HASH} PARENT_SCOPE)

    get_filename_component(IMAGE_NAME "${UML_FILE}" NAME_WE)
    set(IMAGE_FILE "${BASE_DIR}/images/${IMAGE_NAME}.svg" PARENT_SCOPE)

    if(NOT EXISTS ${IMAGE_FILE})
        set(REBUILD 1 PARENT_SCOPE)
        return()
    endif()

    file(STRINGS "${IMAGE_FILE}" IMAGE_HASH REGEX "_UML_HASH (.+)")
    STRING(REGEX MATCH "[a-f0-9]+" IMAGE_HASH "${IMAGE_HASH}" )

    if(NOT "${UML_HASH}" STREQUAL "${IMAGE_HASH}")
        set(REBUILD 1 PARENT_SCOPE)
    endif()
endfunction()

file(GLOB UML_FILES
    "${BASE_DIR}/uml/*uml"
)
foreach(UML_FILE ${UML_FILES})
    set(REBUILD 0)

    get_filename_component(IMAGE_NAME "${UML_FILE}" NAME_WE)
    set(IMAGE_FILE "${BASE_DIR}/images/${IMAGE_NAME}.svg")
    set(UML_HASH 0)
    check_hash(${UML_FILE} ${IMAGE_FILE})

    if(REBUILD)
        if(DEFINED JUST_CHECK)
            message(FATAL_ERROR "${IMAGE_NAME} uml has been changed. Update the corresponding image")
        endif()

        message(STATUS "Building ${IMAGE_NAME}")

        if (NOT PLANTUML_EXECUTABLE)
            find_program(PLANTUML_EXECUTABLE plantuml
                HINTS ENV PLANTUML_INSTALL_DIR
                PATH_SUFFIXES bin)
        endif()
        if (NOT PLANTUML_EXECUTABLE)
            message(FATAL_ERROR "PlantUML is not found. It can be installed with:\nsudo apt install plantuml")
        endif()

        execute_process(
            COMMAND "${PLANTUML_EXECUTABLE}"
            "-tsvg"
            "-o" "${BASE_DIR}/images"
            ${UML_FILE}
            RESULT_VARIABLE STATUS
        )
        if(NOT STATUS EQUAL "0")
            file(REMOVE ${IMAGE_FILE})
            message(FATAL_ERROR "PlantUML has failed on ${IMAGE_NAME} diagram")
        endif()

        file(APPEND ${IMAGE_FILE} "\n<!-- _UML_HASH ${UML_HASH} -->\n")
    else()
        message(STATUS "Skipping ${IMAGE_NAME}")
    endif()
endforeach()
