/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/DialectConversion.h

#include "mlir/Transforms/DialectConversion.h"
#include "../Support/ArrayRef.h"
#include "../Support/CrestObject.h"
#include "../Support/ForeignCallable.h"
#include "../Support/Logging.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Value.h"

// The callbacks of these patterns, legality checks and type conversions are
// closures that the user gives for one conversion: each is a Scheme
// foreign-callable made for it (see scheme/crest/callback.sls), and the owner
// below releases it when whatever calls it, the pattern set, the target or the
// type converter, is destroyed. Objects cross as integers.

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
  SchemeConversionPattern(
      mlir::TypeConverter* typeConverter, mlir::MLIRContext* ctx,
      crest::ForeignCallable<ConversionPatternFn>&& callback,
      llvm::StringRef opName, int benefit, uint64_t schemeConverterPtr)
      : ConversionPattern(*typeConverter, opName, benefit, ctx),
        callback_(std::move(callback)), targetOpName(opName.str()),
        schemeTypeConverterPtr_(schemeConverterPtr) {}

  // Without TypeConverter: operands are passed as-is (no type remapping).
  SchemeConversionPattern(
      mlir::MLIRContext* ctx,
      crest::ForeignCallable<ConversionPatternFn>&& callback,
      llvm::StringRef opName, int benefit)
      : ConversionPattern(opName, static_cast<unsigned>(benefit), ctx),
        callback_(std::move(callback)), targetOpName(opName.str()),
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
  crest::ForeignCallable<ConversionPatternFn> callback_;
  std::string targetOpName;
  uint64_t schemeTypeConverterPtr_;
};

// A rewrite pattern calls (op rewriter) → 1/0. rewriter is a shell that C++
// owns for the call.
class SchemeRewritePattern : public mlir::RewritePattern {
public:
  SchemeRewritePattern(mlir::MLIRContext* ctx,
                       crest::ForeignCallable<RewritePatternFn>&& callback,
                       llvm::StringRef opName, int benefit = 1)
      : RewritePattern(opName, static_cast<unsigned>(benefit), ctx),
        callback_(std::move(callback)), targetOpName(opName.str()) {}

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
  crest::ForeignCallable<RewritePatternFn> callback_;
  std::string targetOpName;
};

namespace {

// The materialization of a type converter: Scheme gets the builder as a
// borrowed shell that lives for the call (insertion point changes are made on
// the builder itself, so nothing is copied), and the inputs as pointers.
mlir::Value
materialize(const crest::ForeignCallable<MaterializationFn>& callback,
            mlir::OpBuilder& builder, mlir::Type resultType,
            mlir::ValueRange inputs, mlir::Location loc) {
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
  Sregister_symbol(
      "crest::DialectConversion::addConversionPattern",
      (void*)+[](uint64_t patterns_ptr, const char* op_name, uint64_t callback,
                 uint64_t type_converter_ptr, int benefit) -> void {
        crest::ForeignCallable<ConversionPatternFn> owned(callback);
        auto& patterns = crest::as_ref<mlir::RewritePatternSet>(
            patterns_ptr, "crest::DialectConversion::addConversionPattern");
        auto& typeConverter = crest::CrestBox<mlir::TypeConverter>::inner(
            type_converter_ptr,
            "crest::DialectConversion::addConversionPattern");
        mlir_support_logging_info(
            (std::string("Registering Scheme pattern for ") + op_name).c_str());
        patterns.add<SchemeConversionPattern>(
            &typeConverter, patterns.getContext(), std::move(owned),
            llvm::StringRef(op_name), benefit, type_converter_ptr);
      });
  // Variant with no TypeConverter: operands are passed as original values.
  // Use for patterns that consume original (unconverted) operand types.
  Sregister_symbol(
      "crest::DialectConversion::addConversionPattern/ctx",
      (void*)+[](uint64_t patterns_ptr, const char* op_name, uint64_t callback,
                 int benefit) -> void {
        crest::ForeignCallable<ConversionPatternFn> owned(callback);
        auto& patterns = crest::as_ref<mlir::RewritePatternSet>(
            patterns_ptr, "crest::DialectConversion::addConversionPattern/ctx");
        mlir_support_logging_info(
            (std::string("Registering Scheme pattern (no TC) for ") + op_name)
                .c_str());
        patterns.add<SchemeConversionPattern>(
            patterns.getContext(), std::move(owned), llvm::StringRef(op_name),
            benefit);
      });
  Sregister_symbol(
      "crest::DialectConversion::addRewritePattern",
      (void*)+[](uint64_t patterns_ptr, const char* op_name, uint64_t callback,
                 int benefit) -> void {
        crest::ForeignCallable<RewritePatternFn> owned(callback);
        auto& patterns = crest::as_ref<mlir::RewritePatternSet>(
            patterns_ptr, "crest::DialectConversion::addRewritePattern");
        mlir_support_logging_info(
            (std::string("Registering Scheme rewrite pattern for ") + op_name)
                .c_str());
        patterns.add<SchemeRewritePattern>(patterns.getContext(),
                                           std::move(owned),
                                           llvm::StringRef(op_name), benefit);
      });
  Sregister_symbol(
      "mlir::TypeConverter::TypeConverter", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(new CrestBox<mlir::TypeConverter>());
      });
  Sregister_symbol(
      "mlir::ConversionTarget::ConversionTarget",
      (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::ConversionTarget::ConversionTarget",
                       "ctx must not be null");
        }
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__);
        return reinterpret_cast<uint64_t>(
            new CrestBox<mlir::ConversionTarget>(*ctx));
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addIllegalDialect",
      (void*)+[](uint64_t target_ptr, const char* dialect_name) -> void {
        if (!dialect_name) {
          return;
        }
        crest::CrestBox<mlir::ConversionTarget>::inner(
            target_ptr, "mlir::ConversionTarget::addIllegalDialect")
            .addIllegalDialect(dialect_name);
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addLegalDialect",
      (void*)+[](uint64_t target_ptr, const char* dialect_name) -> void {
        if (!dialect_name) {
          return;
        }
        crest::CrestBox<mlir::ConversionTarget>::inner(
            target_ptr, "mlir::ConversionTarget::addLegalDialect")
            .addLegalDialect(dialect_name);
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addLegalOp",
      (void*)+[](uint64_t target_ptr, uint64_t ctx_ptr,
                 const char* op_name) -> void {
        if (!ctx_ptr || !op_name) {
          return;
        }
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__);
        crest::CrestBox<mlir::ConversionTarget>::inner(
            target_ptr, "mlir::ConversionTarget::addLegalOp")
            .addLegalOp(mlir::OperationName(op_name, ctx));
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addDynamicallyLegalOp",
      (void*)+[](uint64_t target_ptr, uint64_t ctx_ptr, const char* op_name,
                 uint64_t callback) -> void {
        auto owned =
            std::make_shared<crest::ForeignCallable<LegalityFn>>(callback);
        if (!ctx_ptr || !op_name) {
          return;
        }
        auto& target = crest::CrestBox<mlir::ConversionTarget>::inner(
            target_ptr, "mlir::ConversionTarget::addDynamicallyLegalOp");
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__);
        target.addDynamicallyLegalOp(
            mlir::OperationName(op_name, ctx),
            [owned](mlir::Operation* op) -> bool {
              return (*owned)(reinterpret_cast<uint64_t>(op)) != 0;
            });
      });
  Sregister_symbol(
      "mlir::ConversionTarget::markUnknownOpsDynamicallyLegal",
      (void*)+[](uint64_t target_ptr, uint64_t callback) -> void {
        auto owned =
            std::make_shared<crest::ForeignCallable<LegalityFn>>(callback);
        crest::CrestBox<mlir::ConversionTarget>::inner(
            target_ptr,
            "mlir::ConversionTarget::markUnknownOpsDynamicallyLegal")
            .markUnknownOpDynamicallyLegal(
                [owned](mlir::Operation* op) -> bool {
                  return (*owned)(reinterpret_cast<uint64_t>(op)) != 0;
                });
      });
  Sregister_symbol(
      "mlir::TypeConverter::addConversion",
      (void*)+[](uint64_t converter_ptr, uint64_t callback) -> void {
        auto owned = std::make_shared<crest::ForeignCallable<TypeConversionFn>>(
            callback);
        auto& converter = crest::CrestBox<mlir::TypeConverter>::inner(
            converter_ptr, "mlir::TypeConverter::addConversion");
        converter.addConversion(
            [owned](mlir::Type type) -> std::optional<mlir::Type> {
              uint64_t result = (*owned)(
                  reinterpret_cast<uint64_t>(type.getAsOpaquePointer()));
              if (result == 0) {
                return std::nullopt;
              }
              return mlir::Type::getFromOpaquePointer(
                  reinterpret_cast<const void*>(result));
            });
      });
  Sregister_symbol(
      "mlir::TypeConverter::isLegal<Type>",
      (void*)+[](uint64_t converter_ptr, uint64_t type_ptr) -> int {
        if (!type_ptr) {
          scheme_error("mlir::TypeConverter::isLegal<Type>", "null type");
        }
        auto& converter = crest::CrestBox<mlir::TypeConverter>::inner(
            converter_ptr, "mlir::TypeConverter::isLegal<Type>");
        mlir::Type type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        return converter.isLegal(type) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::TypeConverter::isLegal<Operation>",
      (void*)+[](uint64_t converter_ptr, uint64_t op_ptr) -> int {
        if (!op_ptr) {
          scheme_error("mlir::TypeConverter::isLegal<Operation>", "null op");
        }
        auto& converter = crest::CrestBox<mlir::TypeConverter>::inner(
            converter_ptr, "mlir::TypeConverter::isLegal<Operation>");
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return converter.isLegal(op) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::TypeConverter::isSignatureLegal",
      (void*)+[](uint64_t converter_ptr, uint64_t func_op_ptr) -> int {
        if (!func_op_ptr) {
          scheme_error("mlir::TypeConverter::isSignatureLegal", "null func-op");
        }
        auto& converter = crest::CrestBox<mlir::TypeConverter>::inner(
            converter_ptr, "mlir::TypeConverter::isSignatureLegal");
        auto func_op = mlir::dyn_cast<mlir::func::FuncOp>(
            reinterpret_cast<mlir::Operation*>(func_op_ptr));
        if (!func_op) {
          scheme_error("mlir::TypeConverter::isSignatureLegal",
                       "op is not a func.func operation");
        }
        return converter.isSignatureLegal(func_op.getFunctionType()) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_apply_full_conversion",
      (void*)+[](uint64_t module_ptr, uint64_t target_ptr,
                 uint64_t patterns_ptr) -> int {
        if (!module_ptr || !target_ptr || !patterns_ptr) {
          scheme_error(
              "mlir_transforms_dialect_conversion_apply_full_conversion",
              "module, target, and patterns must not be null");
        }
        auto module = mlir::dyn_cast<mlir::ModuleOp>(
            reinterpret_cast<mlir::Operation*>(module_ptr));
        if (!module) {
          scheme_error(
              "mlir_transforms_dialect_conversion_apply_full_conversion",
              "op is not a module op");
        }
        auto& target = crest::CrestBox<mlir::ConversionTarget>::inner(
            target_ptr,
            "mlir_transforms_dialect_conversion_apply_full_conversion");
        auto& patterns = crest::as_ref<mlir::RewritePatternSet>(
            patterns_ptr,
            "mlir_transforms_dialect_conversion_apply_full_conversion");
        return mlir::succeeded(mlir::applyFullConversion(module, target,
                                                         std::move(patterns)))
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>",
      (void*)+[](uint64_t patterns_ptr, uint64_t converter_ptr) -> void {
        auto& patterns = crest::as_ref<mlir::RewritePatternSet>(
            patterns_ptr,
            "mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>");
        auto& converter = crest::CrestBox<mlir::TypeConverter>::inner(
            converter_ptr,
            "mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>");
        mlir::populateFunctionOpInterfaceTypeConversionPattern<
            mlir::func::FuncOp>(patterns, converter);
      });
  Sregister_symbol(
      "mlir::TypeConverter::addSourceMaterialization",
      (void*)+[](uint64_t converter_ptr, uint64_t callback) -> void {
        auto owned =
            std::make_shared<crest::ForeignCallable<MaterializationFn>>(
                callback);
        auto& converter = crest::CrestBox<mlir::TypeConverter>::inner(
            converter_ptr, "mlir::TypeConverter::addSourceMaterialization");
        converter.addSourceMaterialization(
            [owned](mlir::OpBuilder& builder, mlir::Type resultType,
                    mlir::ValueRange inputs,
                    mlir::Location loc) -> mlir::Value {
              return materialize(*owned, builder, resultType, inputs, loc);
            });
      });
  Sregister_symbol(
      "mlir::TypeConverter::addTargetMaterialization",
      (void*)+[](uint64_t converter_ptr, uint64_t callback) -> void {
        auto owned =
            std::make_shared<crest::ForeignCallable<MaterializationFn>>(
                callback);
        auto& converter = crest::CrestBox<mlir::TypeConverter>::inner(
            converter_ptr, "mlir::TypeConverter::addTargetMaterialization");
        converter.addTargetMaterialization(
            [owned](mlir::OpBuilder& builder, mlir::Type resultType,
                    mlir::ValueRange inputs,
                    mlir::Location loc) -> mlir::Value {
              return materialize(*owned, builder, resultType, inputs, loc);
            });
      });
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::TypeConverter>>",
      (void*)+[](uint64_t ptr) -> int {
        if (!ptr) {
          return 0;
        }
        return reinterpret_cast<CrestObject*>(ptr)
                       ->isa<CrestBox<mlir::TypeConverter>>()
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::ConversionTarget>>",
      (void*)+[](uint64_t ptr) -> int {
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
  Sregister_symbol(
      "mlir::applyPartialConversion",
      (void*)+[](uint64_t op_ptr, uint64_t target_ptr,
                 uint64_t patterns_ptr) -> int {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto& target = crest::CrestBox<mlir::ConversionTarget>::inner(
            target_ptr, "mlir::applyPartialConversion");
        auto& patterns = crest::as_ref<mlir::RewritePatternSet>(
            patterns_ptr, "mlir::applyPartialConversion");
        return mlir::succeeded(mlir::applyPartialConversion(
                   op, target, std::move(patterns)))
                   ? 1
                   : 0;
      });

  // modifyOpInPlace: mutate an op inside a rewriter notification.
  // (rw-ptr op-ptr fn) → void  where fn is the entry point of a
  // foreign-callable made for this call, a thunk () → void
  Sregister_symbol(
      "mlir::RewriterBase::modifyOpInPlace",
      (void*)+[](uint64_t rw_ptr, uint64_t op_ptr, uint64_t fn) -> void {
        crest::ForeignCallable<void()> owned(fn);
        auto& rw = crest::CrestBox<mlir::RewriterBase*>::inner(
            rw_ptr, "mlir::RewriterBase::modifyOpInPlace");
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        rw.modifyOpInPlace(op, [&] { owned(); });
      });
}

} // namespace crest
