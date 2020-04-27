cmake_minimum_required(VERSION 2.8 FATAL_ERROR)

file(GLOB_RECURSE UML_FILES
  "${CMAKE_CURRENT_SOURCE_DIR}/uml/*.uml"
)
set(TMP "${CMAKE_CURRENT_SOURCE_DIR}/tmp.uml")

# pip3 install https://github.com/wandernauta/yuml/zipball/master

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
    COMMAND sed "/\\/\\//d" ${SRC} > ${TMP}
    COMMAND yuml -o ${DST} -i ${TMP} -f svg -s plain --dir ${DIRECTION}
    COMMAND rm ${TMP}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS ${SRC}
    COMMENT "Rendering ${DST}"
    VERBATIM
  )
  list(APPEND UML_OUTPUT "${DST}")
endforeach()

set(UML_OUTPUT ${UML_OUTPUT} PARENT_SCOPE)
add_custom_target(topics-images ALL
  DEPENDS ${UML_OUTPUT}
)
