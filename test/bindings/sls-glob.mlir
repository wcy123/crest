// The list of .sls files that crest.boot depends on is a glob that cmake checks again at every build
// (CONFIGURE_DEPENDS), so a .sls file that is added later is found and the boot is rebuilt (check-sls-glob.py).
//
// RUN: python3 %S/check-sls-glob.py %S/../..

module {}
