// lit.cfg.py does not look for a tool (FileCheck) of one version of LLVM in a build of another: it takes the tools of
// the LLVM of the build, then the PATH (check-lit-tool-paths.py).
//
// RUN: python3 %S/check-lit-tool-paths.py %S/../..

module {}
