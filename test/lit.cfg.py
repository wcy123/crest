# -*- Python -*-
import os
import lit.formats
import lit.util
from lit.llvm import llvm_config

config.name = "CREST"
config.test_format = lit.formats.ShTest()

config.suffixes = [".mlir"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = os.path.join(config.crest_obj_root, "test")

# Tests that need DynamicOpDefinition::addTrait say "REQUIRES: llvm-23".
if int(config.llvm_version_major) >= 23:
    config.available_features.add("llvm-23")

llvm_config.with_system_environment(["HOME", "PATH", "CREST_PATH",
                                     "CREST_DEBUG_MATCH",
                                     "CREST_SCHEME_BINARY_DIR"])
# Fall back to the source tree samples/ if CREST_PATH is not set in the
# environment (CI sets it explicitly; local builds get it for free this way).
if not os.environ.get("CREST_PATH"):
    llvm_config.with_environment("CREST_PATH", config.crest_samples_dir)

# %t — per-test temp directory used by debug-match tests to isolate the
# Scheme binary cache so patterns are always compiled fresh with CREST_DEBUG_MATCH=1.
config.substitutions.append(("%t",
    os.path.join(config.test_exec_root, "tmp")))

# Tool paths
llvm_config.with_environment("PATH", config.llvm_tools_dir,  append_path=True)
llvm_config.with_environment("PATH", config.crest_tools_dir, append_path=True)

# Tool substitutions
def find_tool(name):
    # The tools of the LLVM that this build uses, and then the PATH. A path with another version of LLVM is not a
    # fallback: FileCheck of LLVM 22 would be found for a build with LLVM 23 and the tests would run with it.
    path = lit.util.which(name, config.llvm_tools_dir)
    return path or lit.util.which(name)

crest_opt = os.path.join(config.crest_tools_dir, "crest-opt")
scheme_mlir = os.path.join(os.path.dirname(config.crest_tools_dir), "scheme-mlir", "scheme-mlir")

# lit --param valgrind_logs=DIR runs crest-opt and scheme-mlir under valgrind, one log file for each run in DIR.
# A log with "definitely lost" bytes is a leak (docs/tech-note.md, "Checking for memory leaks"). A test that
# valgrind cannot judge says "UNSUPPORTED: valgrind".
valgrind_logs = lit_config.params.get("valgrind_logs")
if valgrind_logs:
    config.available_features.add("valgrind")
    valgrind_logs = os.path.abspath(valgrind_logs)
    wrappers = os.path.join(valgrind_logs, "bin")
    os.makedirs(wrappers, exist_ok=True)

    def under_valgrind(real_tool):
        name = os.path.basename(real_tool)
        wrapper = os.path.join(wrappers, name)
        with open(wrapper, "w") as out:
            out.write("#!/bin/sh\n"
                      "exec valgrind --leak-check=full --show-leak-kinds=definite --num-callers=14 "
                      f"--log-file={valgrind_logs}/{name}.%p.log "
                      f'{real_tool} "$@"\n')
        os.chmod(wrapper, 0o755)
        return wrapper

    crest_opt = under_valgrind(crest_opt)
    scheme_mlir = under_valgrind(scheme_mlir)

config.substitutions.append(("%crest-opt", crest_opt))
config.substitutions.append(("%scheme-mlir", scheme_mlir))
cmake = lit.util.which("cmake")
if cmake:
    config.available_features.add("cmake")
    config.substitutions.append(("%cmake", '"' + cmake + '"'))
config.substitutions.append(("%FileCheck", find_tool("FileCheck")))
config.substitutions.append(("%samples", config.crest_samples_dir))
