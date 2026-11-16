#!/bin/sh
# A stand-in for crest-opt and crest-bench-cpp in the benchmark tests: it "fuses" by renaming hip.add, so the harness
# sees one hip.qadd for each function of the matching module and none in the other. The last argument is the module.
for last; do :; done
sed 's/hip\.add/hip.qadd/' "$last"
