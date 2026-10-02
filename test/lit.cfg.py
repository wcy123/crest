# -*- Python -*-
import os
import platform
import lit.formats
import lit.util

config.name = "CREST"
config.test_format = lit.formats.ShTest(not llvm_config.use_lit_shell)

config.suffixes = [".mlir"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = os.path.join(config.crest_obj_root, "test")

# Substitutions
config.substitutions.append(("%crest-opt", os.path.join(config.crest_tools_dir, "crest-opt")))
config.substitutions.append(("%FileCheck", "FileCheck"))

# Look for tools in the build directory
llvm_config.with_environment("PATH", config.crest_tools_dir, append_path=True)
llvm_config.with_environment("PATH", config.llvm_tools_dir,  append_path=True)
