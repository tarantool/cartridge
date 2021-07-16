find_program(SPHINX sphinx-build
    HINTS ${SPHINX_DIR}
    PATH_SUFFIXES bin
    DOC "Create intelligent and beautiful documentation"
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Sphinx
    REQUIRED_VARS SPHINX
)

mark_as_advanced(SPHINX_EXECUTABLE)
