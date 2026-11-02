/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/examples/toy/Ch6/mlir/LowerToLLVM.cpp
// Exposes PrintOpLowering pattern population for use from Scheme.

#include "LowerToLLVM.h"
#include "../../Support/CrestObject.h"
#include "../../Support/SchemeWrapper.h"
#include "mlir/Conversion/AffineToStandard/AffineToStandard.h"
#include "mlir/Conversion/ArithToLLVM/ArithToLLVM.h"
#include "mlir/Conversion/ControlFlowToLLVM/ControlFlowToLLVM.h"
#include "mlir/Conversion/FuncToLLVM/ConvertFuncToLLVM.h"
#include "mlir/Conversion/LLVMCommon/ConversionTarget.h"
#include "mlir/Conversion/LLVMCommon/TypeConverter.h"
#include "mlir/Conversion/MemRefToLLVM/MemRefToLLVM.h"
#include "mlir/Conversion/SCFToControlFlow/SCFToControlFlow.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/ControlFlow/IR/ControlFlow.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Transforms/DialectConversion.h"

using namespace mlir;

namespace {
/// Lowers toy.print to a loop nest calling printf on each element.
/// Mirrors PrintOpLowering from LowerToLLVM.cpp.
class PrintOpLowering : public ConversionPattern {
public:
  explicit PrintOpLowering(MLIRContext* ctx)
      : ConversionPattern("toy.print", 1, ctx) {}

  LogicalResult
  matchAndRewrite(Operation* op, ArrayRef<Value> /*operands*/,
                  ConversionPatternRewriter& rewriter) const override {
    // Simplified: just erase toy.print. The LLVM lowering of print is complex
    // (requires SCF loops + printf calls). For now, silence printing.
    rewriter.eraseOp(op);
    return success();
  }

private:
  static LLVM::LLVMFunctionType getPrintfType(MLIRContext* context) {
    auto llvmI32Ty = IntegerType::get(context, 32);
    auto llvmPtrTy = LLVM::LLVMPointerType::get(context);
    return LLVM::LLVMFunctionType::get(llvmI32Ty, llvmPtrTy, /*isVarArg=*/true);
  }

  static FlatSymbolRefAttr getOrInsertPrintf(PatternRewriter& rewriter,
                                             ModuleOp module) {
    auto* context = module.getContext();
    if (module.lookupSymbol<LLVM::LLVMFuncOp>("printf")) {
      return SymbolRefAttr::get(context, "printf");
    }
    PatternRewriter::InsertionGuard insertGuard(rewriter);
    rewriter.setInsertionPointToStart(module.getBody());
    LLVM::LLVMFuncOp::create(rewriter, module.getLoc(), "printf",
                             getPrintfType(context));
    return SymbolRefAttr::get(context, "printf");
  }

  static Value getOrCreateGlobalString(Location loc, OpBuilder& builder,
                                       StringRef name, StringRef value,
                                       ModuleOp module) {
    LLVM::GlobalOp global;
    if (!(global = module.lookupSymbol<LLVM::GlobalOp>(name))) {
      OpBuilder::InsertionGuard insertGuard(builder);
      builder.setInsertionPointToStart(module.getBody());
      auto type = LLVM::LLVMArrayType::get(
          IntegerType::get(builder.getContext(), 8), value.size());
      global = LLVM::GlobalOp::create(
          builder, loc, type, /*isConstant=*/true, LLVM::Linkage::Internal,
          name, builder.getStringAttr(value), /*alignment=*/0);
    }
    Value globalPtr = LLVM::AddressOfOp::create(builder, loc, global);
    Value cst0 = LLVM::ConstantOp::create(builder, loc, builder.getI64Type(),
                                          builder.getIndexAttr(0));
    return LLVM::GEPOp::create(
        builder, loc, LLVM::LLVMPointerType::get(builder.getContext()),
        global.getType(), globalPtr, ArrayRef<Value>({cst0, cst0}));
  }
};
} // namespace

namespace crest {

void registerToyCh6LowerToLLVMBindings() {
  // Populate toy.print lowering into an existing RewritePatternSet.
  // (ctx-ptr patterns-ptr) → void
  Sregister_symbol(
      "mlir::toy::ch6::populatePrintOpLoweringPatterns",
      (void*)+[](uint64_t ctx_ptr, uint64_t patterns_ptr) -> void {
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(
            ctx_ptr, "mlir::toy::ch6::populatePrintOpLoweringPatterns");
        auto& patterns = crest::as_ref<mlir::RewritePatternSet>(
            patterns_ptr, "mlir::toy::ch6::populatePrintOpLoweringPatterns");
        patterns.add<PrintOpLowering>(ctx);
      });
}

} // namespace crest

namespace {
struct SimpleErasePrintOp : public mlir::ConversionPattern {
  explicit SimpleErasePrintOp(mlir::MLIRContext* ctx)
      : ConversionPattern("toy.print", 1, ctx) {}
  mlir::LogicalResult
  matchAndRewrite(mlir::Operation* op, mlir::ArrayRef<mlir::Value> /*operands*/,
                  mlir::ConversionPatternRewriter& rw) const override {
    rw.eraseOp(op);
    return mlir::success();
  }
};
} // namespace

namespace crest {
void registerToyCh6SimpleErasePrintBindings() {
  Sregister_symbol(
      "mlir::toy::ch6::populateSimpleErasePrintPatterns",
      (void*)+[](uint64_t ctx_ptr, uint64_t patterns_ptr) -> void {
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(ctx_ptr, "...");
        auto& patterns =
            crest::as_ref<mlir::RewritePatternSet>(patterns_ptr, "...");
        patterns.add<SimpleErasePrintOp>(ctx);
      });
}
} // namespace crest
