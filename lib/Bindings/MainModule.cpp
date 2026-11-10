/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Registration hub - no MLIR header mirror.

// Registration hub - calls every canonical register*Bindings() directly.
// No Core/ shim layer; each header belongs to its canonical IR/, Transforms/,
// Dialect/, or Interfaces/ sub-tree.

#include "../Crest/Dialect.h"
#include "../Crest/InlinerInterface.h"
#include "../Crest/Op.h"
#include "../Crest/SchemePass.h"
#include "../Crest/Type.h"

#include "Dialect/Affine/IR/AffineOps.h"
#include "Dialect/Affine/Transforms/Passes.h"
#include "Dialect/Arith/IR/Arith.h"
#include "Dialect/ControlFlow/IR/ControlFlow.h"
#include "Dialect/Func/IR/FuncOps.h"
#include "Dialect/MemRef/IR/MemRef.h"
#include "Dialect/SCF/IR/SCFDialect.h"
#include "Dialect/SCF/IR/SCFOps.h"
#include "Dialect/Shape/IR/Shape.h"
#include "Dialect/Tensor/IR/Tensor.h"
#include "IR/AffineExpr.h"
#include "IR/AffineMap.h"
#include "IR/Attributes.h"
#include "IR/Block.h"
#include "IR/Builders.h"
#include "IR/BuiltinAttributes.h"
#include "IR/BuiltinOps.h"
#include "IR/BuiltinTypes.h"
#include "IR/Diagnostics.h"
#include "IR/Dialect.h"
#include "IR/DialectRegistry.h"
#include "IR/Location.h"
#include "IR/MLIRContext.h"
#include "IR/OpImplementation.h"
#include "Transforms/Passes.h"

#include "Conversion/AffineToStandard/AffineToStandard.h"
#include "Conversion/ArithToLLVM/ArithToLLVM.h"
#include "Conversion/ControlFlowToLLVM/ControlFlowToLLVM.h"
#include "Conversion/FuncToLLVM/ConvertFuncToLLVM.h"
#include "Conversion/LLVMCommon/TypeConverter.h"
#include "Conversion/MemRefToLLVM/MemRefToLLVM.h"
#include "Conversion/ReconcileUnrealizedCasts/ReconcileUnrealizedCasts.h"
#include "Conversion/SCFToControlFlow/SCFToControlFlow.h"
#include "Dialect/LLVMIR/IR/LLVMDialect.h"
#include "Dialect/LLVMIR/IR/LLVMOps.h"
#include "Dialect/LLVMIR/Transforms/Passes.h"
#include "ExecutionEngine/ExecutionEngine.h"
#include "IR/Operation.h"
#include "IR/OperationSupport.h"
#include "IR/PatternMatch.h"
#include "IR/Region.h"
#include "IR/SymbolInterfaces.h"
#include "IR/Types.h"
#include "IR/Value.h"
#include "Interfaces/CallInterfaces.h"
#include "Interfaces/DestinationStyleOpInterface.h"
#include "Interfaces/FunctionInterfaces.h"
#include "Interfaces/InferTypeOpInterface.h"
#include "Interfaces/SideEffectInterfaces.h"
#include "Pass/PassManager.h"
#include "Support/ArrayRef.h"
#include "Support/CrestObject.h"
#include "Support/Logging.h"
#include "Target/LLVMIR/Export.h"
#include "Transforms/DialectConversion.h"
#include "Transforms/GreedyPatternRewriteDriver.h"
#include "Transforms/InliningUtils.h"

namespace crest {

// Hook for downstream projects to register their own dialect-specific
// FFI without modifying CREST itself.
static void (*g_extra_bindings_fn)() = nullptr;

extern "C" void crest_register_extra_bindings(void (*fn)()) {
  g_extra_bindings_fn = fn;
}

void registerMlirForeignFunctions() {
  registerDialectShapeBindings();
  registerDialectTensorBindings();
  registerInterfacesDpsBindings();
  registerInterfacesCallInterfacesBindings();
  registerInterfacesInferTypeOpInterfaceBindings();
  registerInterfacesSideEffectInterfacesBindings();
  registerInterfacesFunctionInterfacesBindings();
  registerIRSymbolInterfacesBindings();
  registerIRDialectBindings();
  registerIRDialectRegistryBindings();
  registerIRExtensibleDialectBindings();
  registerCrestInlinerInterfaceBindings();
  registerTransformsInliningUtilsBindings();
  registerPassPassManagerBindings();
  registerCrestDynamicOpBindings();
  registerCrestSchemePassBindings();
  registerCrestDynamicTypeBindings();
  registerIRLocationBindings();
  registerIRDiagnosticsBindings();
  registerIROpImplementationBindings();
  registerIRAffineExprBindings();
  registerIRAffineMapBindings();
  registerIRBlockBindings();
  registerIRRegionBindings();
  registerIRBuiltinAttributesBindings();
  registerIRBuiltinOpsBindings();
  registerIRMLIRContextBindings();
  registerIRBuiltinTypesBindings();
  registerIROpBuilderBindings();
  registerIROperationBindings();
  registerIROperationStateBindings();
  registerIROpResultBindings();
  registerIRRewriterBaseBindings();
  registerIRTypeBindings();
  registerIRAttributeBindings();
  registerIRValueBindings();
  registerCrestObjectBindings();
  registerArrayRefBindings();
  registerLoggingBindings();
  registerTransformsDialectConversionBindings();
  registerTransformsGreedyPatternRewriteDriverBindings();
  registerTransformsPassesBindings();
  registerDialectAffineIRAffineOpsBindings();
  registerDialectAffineTransformsPassesBindings();
  registerDialectControlFlowIRControlFlowBindings();
  registerDialectSCFIRSCFDialectBindings();
  registerDialectSCFIRSCFOpsBindings();
  registerDialectArithIRArithBindings();
  registerDialectFuncIRFuncOpsBindings();
  registerDialectMemRefIRMemRefBindings();
  registerConversionAffineToStandardBindings();
  registerConversionReconcileUnrealizedCastsBindings();
  registerConversionSCFToControlFlowBindings();
  registerConversionArithToLLVMBindings();
  registerConversionMemRefToLLVMBindings();
  registerConversionControlFlowToLLVMBindings();
  registerConversionFuncToLLVMBindings();
  registerConversionLLVMCommonTypeConverterBindings();
  registerDialectLLVMIRIRLLVMDialectBindings();
  registerDialectLLVMIRIRLLVMOpsBindings();
  registerDialectLLVMIRTransformsPassesBindings();
  registerTargetLLVMIRExportBindings();
  registerExecutionEngineBindings();
  if (g_extra_bindings_fn) {
    g_extra_bindings_fn();
  }
}

} // namespace crest
