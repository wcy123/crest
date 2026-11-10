/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Internal: makes the Scheme procedure that builds the callables of a
// prototype. CREST-specific, no MLIR header mirror.

#include "ForeignCallable.h"
#include <unordered_map>

namespace crest::detail {

namespace {
// Never destroyed: the process can end after Chez is gone, and unlocking then
// would be a use after free. The makers stay locked for the life of the
// process.
std::unordered_map<std::string, LockedSchemeObject>& makers() {
  static auto* table = new std::unordered_map<std::string, LockedSchemeObject>;
  return *table;
}
} // namespace

ptr foreignCallableMaker(const std::string& signature) {
  auto& table = makers();
  auto found = table.find(signature);
  if (found == table.end()) {
    std::string code = "(lambda (procedure)"
                       "  (let ([callable (foreign-callable procedure " +
                       signature +
                       ")])"
                       "    (lock-object callable)"
                       "    (foreign-callable-entry-point callable)))";
    ptr port = scheme_call("open-string-input-port", Sstring(code.c_str()));
    ptr expression = scheme_call("read", port);
    ptr maker = scheme_call("eval", expression);
    found = table.emplace(signature, LockedSchemeObject(maker)).first;
  }
  return found->second.get();
}

size_t foreignCallableMakerCount() { return makers().size(); }

} // namespace crest::detail
