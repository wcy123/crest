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
    # Search llvm_tools_dir, then well-known system paths
    for search_dir in [config.llvm_tools_dir,
                       "/usr/lib/llvm-22/bin",
                       "/usr/lib/llvm-15/bin",
                       "/usr/lib/llvm-14/bin"]:
        path = lit.util.which(name, search_dir)
        if path:
            return path
    return lit.util.which(name)  # fallback to PATH

crest_opt = os.path.join(config.crest_tools_dir, "crest-opt")
scheme_mlir = os.path.join(os.path.dirname(config.crest_tools_dir), "scheme-mlir", "scheme-mlir")

# lit --param valgrind_logs=DIR runs crest-opt and scheme-mlir under valgrind, one log file for each run in DIR.
# tools/check-valgrind-logs.py reads them (docs/tech-note.md, "Checking for memory leaks"). A test that measures
# the heap itself says "UNSUPPORTED: valgrind".
valgrind_logs = lit_config.params.get("valgrind_logs")
if valgrind_logs:
    config.available_features.add("valgrind")
    valgrind_logs = os.path.abspath(valgrind_logs)
    wrappers = os.path.join(valgrind_logs, "bin")
    os.makedirs(wrappers, exist_ok=True)

    def under_valgrind(real_tool):
        name = os.path.basename(real_tool)
        wrapper = os.path.join(wrappers, name)
        suppressions = os.path.join(os.path.dirname(__file__), "valgrind.supp")
        with open(wrapper, "w") as out:
            out.write("#!/bin/sh\n"
                      "exec valgrind --leak-check=full --show-leak-kinds=definite --num-callers=14 "
                      f"--suppressions={suppressions} --log-file={valgrind_logs}/{name}.%p.log "
                      f'{real_tool} "$@"\n')
        os.chmod(wrapper, 0o755)
        return wrapper

    crest_opt = under_valgrind(crest_opt)
    scheme_mlir = under_valgrind(scheme_mlir)

config.substitutions.append(("%crest-opt", crest_opt))
config.substitutions.append(("%scheme-mlir", scheme_mlir))
config.substitutions.append(("%FileCheck", find_tool("FileCheck")))
config.substitutions.append(("%samples", config.crest_samples_dir))
