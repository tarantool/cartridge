cmake_minimum_required(VERSION 2.8 FATAL_ERROR)

# pip3 install https://github.com/wandernauta/yuml/zipball/master
find_package(Yuml)


if(YUML_FOUND)
  file(GLOB_RECURSE UML_FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/uml/*.uml"
  )

  foreach(SRC ${UML_FILES})
    string(REGEX REPLACE "uml/(.+)\\.uml" "images/\\1.svg" DST "${SRC}")
    get_filename_component(DESTDIR ${DST} DIRECTORY)

    set(DIRECTION LR)
    file(STRINGS ${SRC} LINE REGEX "// dir: .+")
    if (LINE)
        string(REGEX REPLACE "// dir: (.+)" "\\1" DIRECTION ${LINE})
    endif()

    add_custom_command(
      OUTPUT ${DST}
      COMMAND ${CMAKE_COMMAND} -E make_directory ${DESTDIR}
      COMMAND ${YUML} -i ${SRC} -o ${DST} -f svg -s plain --dir ${DIRECTION}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      DEPENDS ${SRC}
      COMMENT "Rendering ${DST}"
      VERBATIM
    )
    list(APPEND UML_OUTPUT "${DST}")
  endforeach()
else()
  file(GLOB_RECURSE UML_OUTPUT
    "${CMAKE_CURRENT_SOURCE_DIR}/images/*.svg"
  )
endif()

set(UML_OUTPUT ${UML_OUTPUT} PARENT_SCOPE)
add_custom_target(topics-images ALL
  DEPENDS ${UML_OUTPUT}
)
