# -*- Python -*-
import os
import lit.formats
import lit.util
from lit.llvm import llvm_config
from lit.llvm.subst import ToolSubst

config.name = "CREST"
config.test_format = lit.formats.ShTest()

config.suffixes = [".mlir"]
config.test_source_root = os.path.dirname(__file__)
config.test_exec_root = os.path.join(config.crest_obj_root, "test")

llvm_config.with_system_environment(["HOME", "PATH"])

# Tools substitutions
llvm_config.add_tool_substitutions(
    [ToolSubst("%crest-opt", command=os.path.join(config.crest_tools_dir, "crest-opt"))],
)

# FileCheck comes from the LLVM tools dir
llvm_config.with_environment("PATH", config.llvm_tools_dir, append_path=True)
llvm_config.with_environment("PATH", config.crest_tools_dir, append_path=True)
