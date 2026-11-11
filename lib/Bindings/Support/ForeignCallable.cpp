/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Internal: makes the Scheme procedure that builds the callable of a
// prototype. CREST-specific, no MLIR header mirror.

#include "ForeignCallable.h"

namespace crest::detail {

ptr foreignCallableMaker(const std::string& signature) {
  std::string code = "(lambda (procedure)"
                     "  (let ([callable (foreign-callable procedure " +
                     signature +
                     ")])"
                     "    (lock-object callable)"
                     "    (foreign-callable-entry-point callable)))";
  ptr port = scheme_call("open-string-input-port", Sstring(code.c_str()));
  ptr expression = scheme_call("read", port);
  return scheme_call("eval", expression);
}

} // namespace crest::detail
