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

llvm_config.with_system_environment(["HOME", "PATH", "CREST_PATH",
                                     "CREST_DEBUG_MATCH",
                                     "CREST_SCHEME_BINARY_DIR"])

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

config.substitutions.append(("%crest-opt",
    os.path.join(config.crest_tools_dir, "crest-opt")))
config.substitutions.append(("%FileCheck", find_tool("FileCheck")))
