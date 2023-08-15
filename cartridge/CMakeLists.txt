if (APPLE)
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} \
        -undefined suppress -flat_namespace")
endif(APPLE)

add_library(cwinternal SHARED clusterwide-config.c)

set_target_properties(cwinternal PROPERTIES PREFIX "" OUTPUT_NAME "cwinternal")
install(TARGETS cwinternal LIBRARY DESTINATION ${TARANTOOL_INSTALL_LIBDIR}/cartridge)
