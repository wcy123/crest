//
// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
// Licensed under the MIT License.
//
// Pass definitions for the CREST Scheme pass runner infrastructure.
//

#ifndef CREST_PASSES
#define CREST_PASSES

include "mlir/Pass/PassBase.td"

def SchemePass : Pass<"scheme-pass", "mlir::ModuleOp"> {
  let summary = "Run a pass implemented in Scheme";
  let description = [{
    General-purpose pass runner that loads a Scheme library and calls its
    run-pass function. The Scheme module is specified via the 'module' option
    using slash-separated R6RS library name notation.

    Examples:
      --scheme-pass="module=passes/my-rewrite"
      --scheme-pass="module=passes/my-rewrite,log-level=debug"
  }];
  let options = [
    Option<"moduleName", "module", "std::string", /*default=*/"\"\"",
           "Scheme module to load (slash-separated, e.g. 'passes/my-rewrite')">,
    Option<"logLevel", "log-level", "std::string", /*default=*/"\"warning\"",
           "Logging level: trace, debug, info, warning, error, fatal">
  ];
  let dependentDialects = [
    "::mlir::func::FuncDialect",
    "::mlir::shape::ShapeDialect"
  ];
}

#endif // CREST_PASSES
