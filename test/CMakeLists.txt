##
# CREST lit / FileCheck integration tests
##

configure_lit_site_cfg(
  ${CMAKE_CURRENT_SOURCE_DIR}/lit.site.cfg.py.in
  ${CMAKE_CURRENT_BINARY_DIR}/lit.site.cfg.py
  MAIN_CONFIG
    ${CMAKE_CURRENT_SOURCE_DIR}/lit.cfg.py
)

set(CREST_TEST_DEPENDS
  crest-opt
  FileCheck
)

add_lit_testsuite(check-crest "Running CREST regression tests"
  ${CMAKE_CURRENT_BINARY_DIR}
  DEPENDS ${CREST_TEST_DEPENDS}
)

set_target_properties(check-crest PROPERTIES FOLDER "Tests")

add_lit_testsuites(CREST ${CMAKE_CURRENT_SOURCE_DIR}
  DEPENDS ${CREST_TEST_DEPENDS}
)
