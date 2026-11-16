#!/bin/sh
# Like fake-fuse.sh, but its output differs from it, as a C++ pass that did not do the same would.
for last; do :; done
sed 's/hip\.add/hip.qadd/; s/tensor\.empty/tensor.other/' "$last"
