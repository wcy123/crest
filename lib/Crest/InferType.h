/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#ifndef CREST_INFER_TYPE_H
#define CREST_INFER_TYPE_H

#include "llvm/ADT/StringRef.h"

namespace mlir {
class DynamicOpDefinition;
} // namespace mlir

namespace crest {

/// Remember the C function `entry` as the
/// InferTypeOpInterface::inferReturnTypes of the Scheme op `opName`. `entry`
/// has the signature of that method; it is the address of a Chez
/// foreign-callable and stays valid for the process.
void registerInferReturnTypes(llvm::StringRef opName, void* entry);

/// If a function was registered for `opName`, give `def` an
/// InferTypeOpInterface model that calls it. Call before registerDynamicOp.
void attachInferTypeOpInterface(mlir::DynamicOpDefinition& def,
                                llvm::StringRef opName);

} // namespace crest

#endif // CREST_INFER_TYPE_H
