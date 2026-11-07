/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#ifndef CREST_TRAIT_H
#define CREST_TRAIT_H

#include "llvm/ADT/ArrayRef.h"
#include <string>

namespace mlir {
class DynamicOpDefinition;
} // namespace mlir

namespace crest {

/// Attaches the named traits to a dynamic op definition. Returns an empty
/// string on success and a message when a name is unknown or traits are not
/// supported by the LLVM this was built against.
std::string addOpTraits(mlir::DynamicOpDefinition& def,
                        llvm::ArrayRef<std::string> names);

} // namespace crest

#endif // CREST_TRAIT_H
