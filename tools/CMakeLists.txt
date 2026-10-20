add_subdirectory(crest-opt)

configure_file(expand-macro expand-macro COPYONLY)
install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/expand-macro TYPE BIN)
