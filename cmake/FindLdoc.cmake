find_program(LDOC ldoc
    HINTS .rocks/
    PATH_SUFFIXES bin
    DOC "Documentation generator tool for Lua source code"
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Ldoc
    REQUIRED_VARS LDOC
)

mark_as_advanced(LDOC)
