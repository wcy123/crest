// The examples in the docs work when a reader copies them: the options of --crest-pass exist, a pattern
// that a doc shows for a sample file is made of lines of that file, the tutorial's steps build and give
// the output they show, and the commands of the README run (see check-doc-examples.py).
//
// REQUIRES: system-linux
// RUN: env CREST_PATH=%samples python3 %S/check-doc-examples.py %S/../.. %crest-opt

module {}
