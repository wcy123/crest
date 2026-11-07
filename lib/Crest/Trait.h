/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#ifndef CREST_TRAIT_H
#define CREST_TRAIT_H

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/StringRef.h"
#include <string>
#include <vector>

namespace mlir {
class DynamicOpDefinition;
} // namespace mlir

namespace crest {

/// One requested trait: its CREST name followed by its arguments, as strings.
using TraitSpec = std::vector<std::string>;

/// Attaches the named traits to a dynamic op definition (and, for `pure`, the
/// interfaces that MLIR asks about it). Returns an empty string on success and
/// a message when a name or its arguments are wrong, or when traits are not
/// supported by the LLVM this was built against.
std::string addOpTraits(mlir::DynamicOpDefinition& def, llvm::StringRef opName,
                        llvm::ArrayRef<TraitSpec> traits);

} // namespace crest

#endif // CREST_TRAIT_H
