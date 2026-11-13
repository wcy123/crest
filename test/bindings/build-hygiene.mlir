// The build files follow a few rules that a test can read (check-build-hygiene.py): the Chez build takes its number of
// jobs from CREST_CHEZ_JOBS, the boot depends on a glob that cmake checks again (CONFIGURE_DEPENDS), and lit.cfg.py does
// not look for a tool of one version of LLVM in a build of another.
//
// RUN: python3 %S/check-build-hygiene.py %S/../..

module {}
