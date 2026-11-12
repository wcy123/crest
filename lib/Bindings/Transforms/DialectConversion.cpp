/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/DialectConversion.h

#include "mlir/Transforms/DialectConversion.h"
#include "../Support/ArrayRef.h"
#include "../Support/CrestObject.h"
#include "../Support/Logging.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Value.h"

// The callbacks of these patterns, legality checks and type conversions are
// C functions that Scheme made of the closures that the user gives for one
// conversion. C++ only keeps their addresses: it makes, owns and releases
// nothing. Scheme keeps each function alive for as long as the C++ object that
// calls it (the pattern set, the conversion target or the type converter) can
// be used, and a function called after Scheme released it crashes. Objects
// cross as integers.

// A conversion pattern calls (op operands-ref rewriter type-converter) → 1/0.
// operands-ref and rewriter are shells that C++ owns for the call; Scheme uses
// them without freeing them. type-converter is the
// CrestBox<mlir::TypeConverter>* — Scheme uses it opaquely.
using ConversionPatternFn = int(uint64_t op, uint64_t operands,
                                uint64_t rewriter, uint64_t type_converter);
using RewritePatternFn = int(uint64_t op, uint64_t rewriter);
using LegalityFn = int(uint64_t op);
using TypeConversionFn = uint64_t(uint64_t type);
using MaterializationFn = uint64_t(uint64_t builder, uint64_t result_type,
                                   const uint64_t* inputs, uint64_t input_count,
                                   uint64_t loc);

class SchemeConversionPattern : public mlir::ConversionPattern {
public:
  // With TypeConverter: operands are remapped before matchAndRewrite.
  SchemeConversionPattern(mlir::TypeConverter* typeConverter,
                          mlir::MLIRContext* ctx, ConversionPatternFn* callback,
                          llvm::StringRef opName, int benefit,
                          uint64_t schemeConverterPtr)
      : ConversionPattern(*typeConverter, opName, benefit, ctx),
        callback_(callback), targetOpName(opName.str()),
        schemeTypeConverterPtr_(schemeConverterPtr) {}

  // Without TypeConverter: operands are passed as-is (no type remapping).
  SchemeConversionPattern(mlir::MLIRContext* ctx, ConversionPatternFn* callback,
                          llvm::StringRef opName, int benefit)
      : ConversionPattern(opName, static_cast<unsigned>(benefit), ctx),
        callback_(callback), targetOpName(opName.str()),
        schemeTypeConverterPtr_(0) {}

  mlir::LogicalResult
  matchAndRewrite(mlir::Operation* op, mlir::ArrayRef<mlir::Value> operands,
                  mlir::ConversionPatternRewriter& rewriter) const override {
    if (op->getName().getStringRef() != targetOpName) {
      return mlir::failure();
    }
    // C++ owns the shells; Scheme uses them during the call and does not free
    // them — no with-CrestObject on the Scheme side.
    CArrayRef<uintptr_t> operandsWrapped(
        reinterpret_cast<const uintptr_t*>(operands.data()), operands.size());
    crest::CrestBox<mlir::RewriterBase*> rwShell(&rewriter);
    return callback_(reinterpret_cast<uint64_t>(op),
                     reinterpret_cast<uint64_t>(&operandsWrapped),
                     reinterpret_cast<uint64_t>(&rwShell),
                     schemeTypeConverterPtr_) != 0
               ? mlir::success()
               : mlir::failure();
  }

private:
  ConversionPatternFn* callback_;
  std::string targetOpName;
  uint64_t schemeTypeConverterPtr_;
};

// A rewrite pattern calls (op rewriter) → 1/0. rewriter is a shell that C++
// owns for the call.
class SchemeRewritePattern : public mlir::RewritePattern {
public:
  SchemeRewritePattern(mlir::MLIRContext* ctx, RewritePatternFn* callback,
                       llvm::StringRef opName, int benefit = 1)
      : RewritePattern(opName, static_cast<unsigned>(benefit), ctx),
        callback_(callback), targetOpName(opName.str()) {}

  mlir::LogicalResult
  matchAndRewrite(mlir::Operation* op,
                  mlir::PatternRewriter& rewriter) const override {
    if (op->getName().getStringRef() != targetOpName) {
      return mlir::failure();
    }
    crest::CrestBox<mlir::RewriterBase*> rwShell(&rewriter);
    return callback_(reinterpret_cast<uint64_t>(op),
                     reinterpret_cast<uint64_t>(&rwShell)) != 0
               ? mlir::success()
               : mlir::failure();
  }

private:
  RewritePatternFn* callback_;
  std::string targetOpName;
};

namespace {

// The materialization of a type converter: Scheme gets the builder as a
// borrowed shell that lives for the call (insertion point changes are made on
// the builder itself, so nothing is copied), and the inputs as pointers.
mlir::Value materialize(MaterializationFn* callback, mlir::OpBuilder& builder,
                        mlir::Type resultType, mlir::ValueRange inputs,
                        mlir::Location loc) {
  crest::CrestBox<mlir::OpBuilder*> builder_shell(&builder);
  llvm::SmallVector<uint64_t, 4> input_pointers;
  for (mlir::Value input : inputs) {
    input_pointers.push_back(
        reinterpret_cast<uint64_t>(input.getAsOpaquePointer()));
  }
  uint64_t result =
      callback(reinterpret_cast<uint64_t>(&builder_shell),
               reinterpret_cast<uint64_t>(resultType.getAsOpaquePointer()),
               input_pointers.data(), input_pointers.size(),
               reinterpret_cast<uint64_t>(loc.getAsOpaquePointer()));
  if (!result) {
    return nullptr;
  }
  return mlir::Value::getFromOpaquePointer(
      reinterpret_cast<const void*>(result));
}

} // namespace

namespace crest {

void registerTransformsDialectConversionBindings() {
  register_binding(
      "crest::DialectConversion::addConversionPattern",
      [](uint64_t patterns_ptr, const char* op_name_arg,
         ConversionPatternFn* callback, uint64_t type_converter_ptr,
         int benefit) -> llvm::Error {
        const std::string op_name(op_name_arg);
        CREST_TRY(patterns,
                  crest::as_ref<mlir::RewritePatternSet>(
                      patterns_ptr,
                      "crest::DialectConversion::addConversionPattern"));
        CREST_TRY(typeConverter,
                  crest::CrestBox<mlir::TypeConverter>::inner(
                      type_converter_ptr,
                      "crest::DialectConversion::addConversionPattern"));
        mlir_support_logging_info(
            (std::string("Registering Scheme pattern for ") + op_name).c_str());
        patterns.add<SchemeConversionPattern>(
            &typeConverter, patterns.getContext(), callback,
            llvm::StringRef(op_name), benefit, type_converter_ptr);
        return llvm::Error::success();
      });
  // Variant with no TypeConverter: operands are passed as original values.
  // Use for patterns that consume original (unconverted) operand types.
  register_binding(
      "crest::DialectConversion::addConversionPattern/ctx",
      [](uint64_t patterns_ptr, const char* op_name_arg,
         ConversionPatternFn* callback, int benefit) -> llvm::Error {
        const std::string op_name(op_name_arg);
        CREST_TRY(patterns,
                  crest::as_ref<mlir::RewritePatternSet>(
                      patterns_ptr,
                      "crest::DialectConversion::addConversionPattern/ctx"));
        mlir_support_logging_info(
            (std::string("Registering Scheme pattern (no TC) for ") + op_name)
                .c_str());
        patterns.add<SchemeConversionPattern>(
            patterns.getContext(), callback, llvm::StringRef(op_name), benefit);
        return llvm::Error::success();
      });
  register_binding(
      "crest::DialectConversion::addRewritePattern",
      [](uint64_t patterns_ptr, const char* op_name_arg,
         RewritePatternFn* callback, int benefit) -> llvm::Error {
        const std::string op_name(op_name_arg);
        CREST_TRY(patterns, crest::as_ref<mlir::RewritePatternSet>(
                                patterns_ptr,
                                "crest::DialectConversion::addRewritePattern"));
        mlir_support_logging_info(
            (std::string("Registering Scheme rewrite pattern for ") + op_name)
                .c_str());
        patterns.add<SchemeRewritePattern>(patterns.getContext(), callback,
                                           llvm::StringRef(op_name), benefit);
        return llvm::Error::success();
      });
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-TypeConverter, which frees it after its body; a box that is never
  // freed leaks.
  register_binding("mlir::TypeConverter::TypeConverter", []() -> uint64_t {
    return reinterpret_cast<uint64_t>(new CrestBox<mlir::TypeConverter>());
  });
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-ConversionTarget, which frees it after its body; a box that is never
  // freed leaks.
  register_binding(
      "mlir::ConversionTarget::ConversionTarget",
      [](uint64_t ctx_ptr) -> llvm::Expected<uint64_t> {
        if (!ctx_ptr) {
          return fail("mlir::ConversionTarget::ConversionTarget",
                      llvm::Twine("ctx must not be null"));
        }
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        return reinterpret_cast<uint64_t>(
            new CrestBox<mlir::ConversionTarget>(*ctx));
      });
  register_binding(
      "mlir::ConversionTarget::addIllegalDialect",
      [](uint64_t target_ptr, const char* dialect_name) -> llvm::Error {
        if (!dialect_name) {
          return llvm::Error::success();
        }
        CREST_TRY(crest_lookup1,
                  crest::CrestBox<mlir::ConversionTarget>::inner(
                      target_ptr, "mlir::ConversionTarget::addIllegalDialect"));

        crest_lookup1.addIllegalDialect(dialect_name);
        return llvm::Error::success();
      });
  register_binding(
      "mlir::ConversionTarget::addLegalDialect",
      [](uint64_t target_ptr, const char* dialect_name) -> llvm::Error {
        if (!dialect_name) {
          return llvm::Error::success();
        }
        CREST_TRY(crest_lookup1,
                  crest::CrestBox<mlir::ConversionTarget>::inner(
                      target_ptr, "mlir::ConversionTarget::addLegalDialect"));

        crest_lookup1.addLegalDialect(dialect_name);
        return llvm::Error::success();
      });
  register_binding(
      "mlir::ConversionTarget::addLegalOp",
      [](uint64_t target_ptr, uint64_t ctx_ptr,
         const char* op_name) -> llvm::Error {
        if (!ctx_ptr || !op_name) {
          return llvm::Error::success();
        }
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        CREST_TRY(crest_lookup1,
                  crest::CrestBox<mlir::ConversionTarget>::inner(
                      target_ptr, "mlir::ConversionTarget::addLegalOp"));

        crest_lookup1.addLegalOp(mlir::OperationName(op_name, ctx));
        return llvm::Error::success();
      });
  register_binding(
      "mlir::ConversionTarget::addDynamicallyLegalOp",
      [](uint64_t target_ptr, uint64_t ctx_ptr, const char* op_name_arg,
         LegalityFn* callback) -> llvm::Error {
        const bool hasName = op_name_arg != nullptr;
        const std::string op_name(hasName ? op_name_arg : "");
        if (!ctx_ptr || !hasName) {
          return llvm::Error::success();
        }
        CREST_TRY(target, crest::CrestBox<mlir::ConversionTarget>::inner(
                              target_ptr,
                              "mlir::ConversionTarget::addDynamicallyLegalOp"));
        CREST_TRY(ctx, crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__));
        target.addDynamicallyLegalOp(
            mlir::OperationName(op_name, ctx),
            [callback](mlir::Operation* op) -> bool {
              return callback(reinterpret_cast<uint64_t>(op)) != 0;
            });
        return llvm::Error::success();
      });
  register_binding(
      "mlir::ConversionTarget::markUnknownOpsDynamicallyLegal",
      [](uint64_t target_ptr, LegalityFn* callback) -> llvm::Error {
        CREST_TRY(
            target,
            crest::CrestBox<mlir::ConversionTarget>::inner(
                target_ptr,
                "mlir::ConversionTarget::markUnknownOpsDynamicallyLegal"));
        target.markUnknownOpDynamicallyLegal(
            [callback](mlir::Operation* op) -> bool {
              return callback(reinterpret_cast<uint64_t>(op)) != 0;
            });
        return llvm::Error::success();
      });
  register_binding(
      "mlir::TypeConverter::addConversion",
      [](uint64_t converter_ptr, TypeConversionFn* callback) -> llvm::Error {
        CREST_TRY(converter,
                  crest::CrestBox<mlir::TypeConverter>::inner(
                      converter_ptr, "mlir::TypeConverter::addConversion"));
        converter.addConversion(
            [callback](mlir::Type type) -> std::optional<mlir::Type> {
              uint64_t result = callback(
                  reinterpret_cast<uint64_t>(type.getAsOpaquePointer()));
              if (result == 0) {
                return std::nullopt;
              }
              return mlir::Type::getFromOpaquePointer(
                  reinterpret_cast<const void*>(result));
            });
        return llvm::Error::success();
      });
  register_binding(
      "mlir::TypeConverter::isLegal<Type>",
      [](uint64_t converter_ptr, uint64_t type_ptr) -> llvm::Expected<int> {
        if (!type_ptr) {
          return fail("mlir::TypeConverter::isLegal<Type>",
                      llvm::Twine("null type"));
        }
        CREST_TRY(converter,
                  crest::CrestBox<mlir::TypeConverter>::inner(
                      converter_ptr, "mlir::TypeConverter::isLegal<Type>"));
        mlir::Type type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        return converter.isLegal(type) ? 1 : 0;
      });
  register_binding(
      "mlir::TypeConverter::isLegal<Operation>",
      [](uint64_t converter_ptr, uint64_t op_ptr) -> llvm::Expected<int> {
        if (!op_ptr) {
          return fail("mlir::TypeConverter::isLegal<Operation>",
                      llvm::Twine("null op"));
        }
        CREST_TRY(converter, crest::CrestBox<mlir::TypeConverter>::inner(
                                 converter_ptr,
                                 "mlir::TypeConverter::isLegal<Operation>"));
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return converter.isLegal(op) ? 1 : 0;
      });
  register_binding(
      "mlir::TypeConverter::isSignatureLegal",
      [](uint64_t converter_ptr, uint64_t func_op_ptr) -> llvm::Expected<int> {
        if (!func_op_ptr) {
          return fail("mlir::TypeConverter::isSignatureLegal",
                      llvm::Twine("null func-op"));
        }
        CREST_TRY(converter,
                  crest::CrestBox<mlir::TypeConverter>::inner(
                      converter_ptr, "mlir::TypeConverter::isSignatureLegal"));
        auto func_op = mlir::dyn_cast<mlir::func::FuncOp>(
            reinterpret_cast<mlir::Operation*>(func_op_ptr));
        if (!func_op) {
          return fail("mlir::TypeConverter::isSignatureLegal",
                      llvm::Twine("op is not a func.func operation"));
        }
        return converter.isSignatureLegal(func_op.getFunctionType()) ? 1 : 0;
      });
  register_binding(
      "mlir_transforms_dialect_conversion_apply_full_conversion",
      [](uint64_t module_ptr, uint64_t target_ptr,
         uint64_t patterns_ptr) -> llvm::Expected<int> {
        if (!module_ptr || !target_ptr || !patterns_ptr) {
          return fail(
              "mlir_transforms_dialect_conversion_apply_full_conversion",
              llvm::Twine("module, target, and patterns must not be null"));
        }
        auto module = mlir::dyn_cast<mlir::ModuleOp>(
            reinterpret_cast<mlir::Operation*>(module_ptr));
        if (!module) {
          return fail(
              "mlir_transforms_dialect_conversion_apply_full_conversion",
              llvm::Twine("op is not a module op"));
        }
        CREST_TRY(
            target,
            crest::CrestBox<mlir::ConversionTarget>::inner(
                target_ptr,
                "mlir_transforms_dialect_conversion_apply_full_conversion"));
        CREST_TRY(
            patterns,
            crest::as_ref<mlir::RewritePatternSet>(
                patterns_ptr,
                "mlir_transforms_dialect_conversion_apply_full_conversion"));
        return mlir::succeeded(mlir::applyFullConversion(module, target,
                                                         std::move(patterns)))
                   ? 1
                   : 0;
      });
  register_binding(
      "mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>",
      [](uint64_t patterns_ptr, uint64_t converter_ptr) -> llvm::Error {
        CREST_TRY(patterns,
                  crest::as_ref<mlir::RewritePatternSet>(
                      patterns_ptr,
                      "mlir::populateFunctionOpInterfaceTypeConversionPattern<"
                      "FuncOp>"));
        CREST_TRY(converter,
                  crest::CrestBox<mlir::TypeConverter>::inner(
                      converter_ptr,
                      "mlir::populateFunctionOpInterfaceTypeConversionPattern<"
                      "FuncOp>"));
        mlir::populateFunctionOpInterfaceTypeConversionPattern<
            mlir::func::FuncOp>(patterns, converter);
        return llvm::Error::success();
      });
  register_binding(
      "mlir::TypeConverter::addSourceMaterialization",
      [](uint64_t converter_ptr, MaterializationFn* callback) -> llvm::Error {
        CREST_TRY(converter,
                  crest::CrestBox<mlir::TypeConverter>::inner(
                      converter_ptr,
                      "mlir::TypeConverter::addSourceMaterialization"));
        converter.addSourceMaterialization(
            [callback](mlir::OpBuilder& builder, mlir::Type resultType,
                       mlir::ValueRange inputs,
                       mlir::Location loc) -> mlir::Value {
              return materialize(callback, builder, resultType, inputs, loc);
            });
        return llvm::Error::success();
      });
  register_binding(
      "mlir::TypeConverter::addTargetMaterialization",
      [](uint64_t converter_ptr, MaterializationFn* callback) -> llvm::Error {
        CREST_TRY(converter,
                  crest::CrestBox<mlir::TypeConverter>::inner(
                      converter_ptr,
                      "mlir::TypeConverter::addTargetMaterialization"));
        converter.addTargetMaterialization(
            [callback](mlir::OpBuilder& builder, mlir::Type resultType,
                       mlir::ValueRange inputs,
                       mlir::Location loc) -> mlir::Value {
              return materialize(callback, builder, resultType, inputs, loc);
            });
        return llvm::Error::success();
      });
  register_binding("crest::isa<CrestBox<mlir::TypeConverter>>",
                   [](uint64_t ptr) -> int {
                     if (!ptr) {
                       return 0;
                     }
                     return reinterpret_cast<CrestObject*>(ptr)
                                    ->isa<CrestBox<mlir::TypeConverter>>()
                                ? 1
                                : 0;
                   });
  register_binding("crest::isa<CrestBox<mlir::ConversionTarget>>",
                   [](uint64_t ptr) -> int {
                     if (!ptr) {
                       return 0;
                     }
                     return reinterpret_cast<CrestObject*>(ptr)
                                    ->isa<CrestBox<mlir::ConversionTarget>>()
                                ? 1
                                : 0;
                   });

  // applyPartialConversion: partially lower ops, leaving unregistered ops.
  // (op-ptr target-ptr patterns-ptr) → 1 success | 0 failure
  register_binding(
      "mlir::applyPartialConversion",
      [](uint64_t op_ptr, uint64_t target_ptr,
         uint64_t patterns_ptr) -> llvm::Expected<int> {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        CREST_TRY(target, crest::CrestBox<mlir::ConversionTarget>::inner(
                              target_ptr, "mlir::applyPartialConversion"));
        CREST_TRY(patterns, crest::as_ref<mlir::RewritePatternSet>(
                                patterns_ptr, "mlir::applyPartialConversion"));
        return mlir::succeeded(mlir::applyPartialConversion(
                   op, target, std::move(patterns)))
                   ? 1
                   : 0;
      });

  // modifyOpInPlace: mutate an op inside a rewriter notification.
  // (rw-ptr op-ptr thunk) → void  where thunk is a C function () that Scheme
  // made and keeps alive until the call returns
  register_binding(
      "mlir::RewriterBase::modifyOpInPlace",
      [](uint64_t rw_ptr, uint64_t op_ptr, void (*thunk)()) -> llvm::Error {
        CREST_TRY(rw, crest::CrestBox<mlir::RewriterBase*>::inner(
                          rw_ptr, "mlir::RewriterBase::modifyOpInPlace"));
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        rw.modifyOpInPlace(op, [&] { thunk(); });
        return llvm::Error::success();
      });
}

} // namespace crest
