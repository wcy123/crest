/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once

// The guard of a callable that Scheme made reports an error as a diagnostic in
// (current-MLIRContext) (scheme/crest/callback.sls), and a Location belongs to
// a context. Scheme code sets the parameter with with-current-MLIRContext. A
// tool that C++ drives (crest-opt) has no Scheme code of that kind, so the C++
// code that runs Scheme for a context sets it: a Chez parameter that is called
// with one argument sets its value.

#include "../Bindings/Support/SchemeWrapper.h"
#include "../Interpreter/ChezSchemeInterpreter.h"
#include "mlir/IR/MLIRContext.h"
#include <cstdint>

namespace crest {

inline void setCurrentContext(ChezSchemeInterpreter& interpreter,
                              mlir::MLIRContext* context) {
  interpreter.eval("(import (mlir IR MLIRContext))");
  scheme_call("current-MLIRContext", reinterpret_cast<uint64_t>(context));
}

} // namespace crest
