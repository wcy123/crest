/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#ifndef CREST_INFER_TYPE_H
#define CREST_INFER_TYPE_H

#include "../Bindings/Support/LockedSchemeObject.h"
#include "mlir/IR/OperationSupport.h"
#include <cstdint>

namespace mlir {
class DynamicOpDefinition;
} // namespace mlir

namespace crest {

/// Give `def` an InferTypeOpInterface model: insert it in the interface map of
/// `def`, look it up and fill in the function pointers of its Concept from
/// `dispatcher`. That is the Scheme procedure that the entry of the op's
/// :interface2 clause holds (see (mlir Interfaces InferTypeOpInterface)), from
/// a method name to the entry point of its callable (0 for a method the op has
/// no clause for, which keeps its default); the caller keeps it locked for the
/// call. An entry is a C function that Scheme made once for the clause (a Chez
/// foreign-callable, valid for the process, with the signature of the Concept's
/// method). inferReturnTypes is required. The three pointers are what C++ code
/// that uses the interface calls; nothing here checks the result types of an
/// op against them. Call before registerDynamicOp.
void attachInferTypeOpInterface(mlir::DynamicOpDefinition& def,
                                const LockedSchemeObject& dispatcher);

} // namespace crest

#endif // CREST_INFER_TYPE_H
