find_program(YUML yuml
    PATH_SUFFIXES bin
    DOC "Draw simple UML diagrams with code"
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(YUML
    REQUIRED_VARS YUML
)

mark_as_advanced(YUML)
