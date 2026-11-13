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
//
// The parameter holds a bare pointer, so it must not outlive the context:
// CrestDialect clears it when its context goes (clearCurrentContext), and a
// pass runner restores the old value after the call (CurrentContextScope).

#include "../Bindings/Support/SchemeWrapper.h"
#include "../Interpreter/ChezSchemeInterpreter.h"
#include "mlir/IR/MLIRContext.h"
#include <cstdint>

namespace crest {

// The library that has the parameter is imported once: the import stays in the
// interpreter, and an eval of the form costs about 6 microseconds, which the
// scope below paid for every function that a Scheme pass visits.
inline void importCurrentContextLibrary(ChezSchemeInterpreter& interpreter) {
  static bool imported = false;
  if (!imported) {
    interpreter.eval("(import (mlir IR MLIRContext))");
    imported = true;
  }
}

inline void setCurrentContext(ChezSchemeInterpreter& interpreter,
                              mlir::MLIRContext* context) {
  importCurrentContextLibrary(interpreter);
  scheme_call("current-MLIRContext", reinterpret_cast<uint64_t>(context));
}

// Make the parameter #f if it still names `context`, which is about to be
// destroyed.
inline void clearCurrentContext(ChezSchemeInterpreter& interpreter,
                                mlir::MLIRContext* context) {
  importCurrentContextLibrary(interpreter);
  ptr current = scheme_call("current-MLIRContext");
  if (current != Sfalse &&
      Sunsigned64_value(current) == reinterpret_cast<uint64_t>(context)) {
    scheme_call("current-MLIRContext", Sfalse);
  }
}

// Sets the parameter for the length of a call, and puts the old value back.
class CurrentContextScope {
public:
  CurrentContextScope(ChezSchemeInterpreter& interpreter,
                      mlir::MLIRContext* context) {
    importCurrentContextLibrary(interpreter);
    ptr old = scheme_call("current-MLIRContext");
    hadOld_ = old != Sfalse;
    if (hadOld_) {
      old_ = Sunsigned64_value(old);
    }
    scheme_call("current-MLIRContext", reinterpret_cast<uint64_t>(context));
  }
  ~CurrentContextScope() {
    if (hadOld_) {
      scheme_call("current-MLIRContext", old_);
    } else {
      scheme_call("current-MLIRContext", Sfalse);
    }
  }
  CurrentContextScope(const CurrentContextScope&) = delete;
  CurrentContextScope& operator=(const CurrentContextScope&) = delete;

private:
  bool hadOld_ = false;
  uint64_t old_ = 0;
};

} // namespace crest
