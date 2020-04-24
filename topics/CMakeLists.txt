cmake_minimum_required(VERSION 2.8 FATAL_ERROR)

file(GLOB_RECURSE UML_FILES
  "${CMAKE_CURRENT_SOURCE_DIR}/uml/*.uml"
)
set(UML_FILES ${UML_FILES} PARENT_SCOPE)

# pip3 install https://github.com/wandernauta/yuml/zipball/master

foreach(SRC ${UML_FILES})
  string(REGEX REPLACE "uml/(.+)\\.uml" "images/\\1.svg" DST "${SRC}")
  get_filename_component(DIR ${DST} DIRECTORY)
  add_custom_command(
    OUTPUT ${DST}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${DIR}
    COMMAND yuml -i ${SRC} -o ${DST} -f svg -s plain --dir LR
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS ${SRC}
    COMMENT "Rendering ${DST}"
    VERBATIM
  )
  list(APPEND UML_OUTPUT "${DST}")
endforeach()

add_custom_target(topics-images ALL
  DEPENDS ${UML_OUTPUT}
)
