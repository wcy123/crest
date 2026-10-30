add_subdirectory(crest-opt)
add_subdirectory(scheme-mlir)

configure_file(expand-macro expand-macro COPYONLY)
install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/expand-macro TYPE BIN)
