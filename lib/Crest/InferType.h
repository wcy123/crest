/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#ifndef CREST_INFER_TYPE_H
#define CREST_INFER_TYPE_H

#include "../Bindings/Support/LockedSchemeObject.h"
#include "llvm/ADT/StringRef.h"
#include "mlir/IR/OperationSupport.h"

namespace mlir {
class DynamicOpDefinition;
} // namespace mlir

namespace crest {

/// Remember the C function `entry` as the
/// InferTypeOpInterface::inferReturnTypes of the Scheme op `opName`. `entry`
/// has the signature of that method; it is the address of a Chez
/// foreign-callable and stays valid for the process.
void registerInferReturnTypes(llvm::StringRef opName, void* entry);

/// The isCompatibleReturnTypes method of the Scheme op `opName`: a procedure
/// (inferred actual) -> boolean over two lists of Types. Without one the result
/// types must equal the inferred ones. An op whose inference is general and
/// whose results get refined later (Toy: tensor<*xf64>, then a ranked tensor)
/// says what is compatible, as the ODS ops of C++ do.
void registerCompatibleReturnTypes(llvm::StringRef opName,
                                   crest::LockedSchemeObject proc);

/// If a function was registered for `opName`, wrap `verify` so that it first
/// checks the result types of the op against what that function infers, as the
/// verifier of a C++ op with InferTypeOpInterface does (an op that says i64
/// where its inference says i32 is an error). Otherwise return `verify`.
mlir::OperationName::VerifyInvariantsFn
withInferredTypesCheck(mlir::OperationName::VerifyInvariantsFn verify,
                       llvm::StringRef opName);

/// If a function was registered for `opName`, give `def` an
/// InferTypeOpInterface model that calls it. Call before registerDynamicOp.
void attachInferTypeOpInterface(mlir::DynamicOpDefinition& def,
                                llvm::StringRef opName);

} // namespace crest

#endif // CREST_INFER_TYPE_H
