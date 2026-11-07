/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Stand-in for Trait.cpp on LLVM before 23, which has no
// DynamicOpDefinition::addTrait. A dialect that asks for traits gets a clear
// error instead of silently losing them.

#include "Trait.h"

namespace crest {

std::string addOpTraits(mlir::DynamicOpDefinition&,
                        llvm::ArrayRef<std::string> names) {
  if (names.empty()) {
    return "";
  }
  return "define-op :traits requires LLVM 23+ (DynamicOpDefinition::addTrait); "
         "requested trait: " +
         names.front();
}

} // namespace crest
