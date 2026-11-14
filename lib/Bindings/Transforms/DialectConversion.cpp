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
//
// Each function has the C result type that is written here, and the Scheme
// callable has the same one (scheme/crest/callback.sls). An error of the Scheme
// procedure is reported there, as a diagnostic at the Scheme source, and the
// callable answers the failure value of its type: 0.

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
                                   uint64_t inputs, uint64_t loc);

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
    int answer = callback_(reinterpret_cast<uint64_t>(op),
                           reinterpret_cast<uint64_t>(&operandsWrapped),
                           reinterpret_cast<uint64_t>(&rwShell),
                           schemeTypeConverterPtr_);
    return answer != 0 ? mlir::success() : mlir::failure();
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
    int answer = callback_(reinterpret_cast<uint64_t>(op),
                           reinterpret_cast<uint64_t>(&rwShell));
    return answer != 0 ? mlir::success() : mlir::failure();
  }

private:
  RewritePatternFn* callback_;
  std::string targetOpName;
};

namespace {

// A dynamic legality check: whether the op is legal. An error of the Scheme
// procedure is reported by its callable, which answers 0: the op is taken as
// illegal.
bool isLegal(LegalityFn* callback, mlir::Operation* op) {
  return callback(reinterpret_cast<uint64_t>(op)) != 0;
}

// The materialization of a type converter: Scheme gets the builder as a
// borrowed shell that lives for the call (insertion point changes are made on
// the builder itself, so nothing is copied), and the inputs as a CArrayRef.
mlir::Value materialize(MaterializationFn* callback, mlir::OpBuilder& builder,
                        mlir::Type resultType, mlir::ValueRange inputs,
                        mlir::Location loc) {
  crest::CrestBox<mlir::OpBuilder*> builder_shell(&builder);
  llvm::SmallVector<uintptr_t, 4> input_pointers;
  for (mlir::Value input : inputs) {
    input_pointers.push_back(
        reinterpret_cast<uintptr_t>(input.getAsOpaquePointer()));
  }
  CArrayRef<uintptr_t> inputs_ref(input_pointers.data(), input_pointers.size());
  uint64_t result =
      callback(reinterpret_cast<uint64_t>(&builder_shell),
               reinterpret_cast<uint64_t>(resultType.getAsOpaquePointer()),
               reinterpret_cast<uint64_t>(&inputs_ref),
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
      (void*)+[](uint64_t patterns_ptr, const char* op_name_arg,
                 ConversionPatternFn* callback, uint64_t type_converter_ptr,
                 int benefit) -> ptr {
        const std::string op_name(op_name_arg);
        auto* patterns_box =
            crest::as_ref<mlir::RewritePatternSet>(patterns_ptr);
        if (!patterns_box) {
          return scheme_error(
              "crest::DialectConversion::addConversionPattern",
              "null pointer or not a CrestBox<mlir::RewritePatternSet> or "
              "CrestBox<mlir::RewritePatternSet*>");
        }
        auto& patterns = *patterns_box;
        auto* typeConverter_box =
            crest::CrestBox<mlir::TypeConverter>::inner(type_converter_ptr);
        if (!typeConverter_box) {
          return scheme_error(
              "crest::DialectConversion::addConversionPattern",
              "null pointer or not a CrestBox<mlir::TypeConverter>");
        }
        auto& typeConverter = *typeConverter_box;
        mlir_support_logging_info(
            (std::string("Registering Scheme pattern for ") + op_name).c_str());
        patterns.add<SchemeConversionPattern>(
            &typeConverter, patterns.getContext(), callback,
            llvm::StringRef(op_name), benefit, type_converter_ptr);
        return Svoid;
      });
  // Variant with no TypeConverter: operands are passed as original values.
  // Use for patterns that consume original (unconverted) operand types.
  Sregister_symbol(
      "crest::DialectConversion::addConversionPatternWithoutTypeConverter",
      (void*)+[](uint64_t patterns_ptr, const char* op_name_arg,
                 ConversionPatternFn* callback, int benefit) -> ptr {
        const std::string op_name(op_name_arg);
        auto* patterns_box =
            crest::as_ref<mlir::RewritePatternSet>(patterns_ptr);
        if (!patterns_box) {
          return scheme_error(
              "crest::DialectConversion::"
              "addConversionPatternWithoutTypeConverter",
              "null pointer or not a CrestBox<mlir::RewritePatternSet> or "
              "CrestBox<mlir::RewritePatternSet*>");
        }
        auto& patterns = *patterns_box;
        mlir_support_logging_info(
            (std::string("Registering Scheme pattern (no TC) for ") + op_name)
                .c_str());
        patterns.add<SchemeConversionPattern>(
            patterns.getContext(), callback, llvm::StringRef(op_name), benefit);
        return Svoid;
      });
  Sregister_symbol(
      "crest::DialectConversion::addRewritePattern",
      (void*)+[](uint64_t patterns_ptr, const char* op_name_arg,
                 RewritePatternFn* callback, int benefit) -> ptr {
        const std::string op_name(op_name_arg);
        auto* patterns_box =
            crest::as_ref<mlir::RewritePatternSet>(patterns_ptr);
        if (!patterns_box) {
          return scheme_error(
              "crest::DialectConversion::addRewritePattern",
              "null pointer or not a CrestBox<mlir::RewritePatternSet> or "
              "CrestBox<mlir::RewritePatternSet*>");
        }
        auto& patterns = *patterns_box;
        mlir_support_logging_info(
            (std::string("Registering Scheme rewrite pattern for ") + op_name)
                .c_str());
        patterns.add<SchemeRewritePattern>(patterns.getContext(), callback,
                                           llvm::StringRef(op_name), benefit);
        return Svoid;
      });
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-TypeConverter, which frees it after its body; a box that is never
  // freed leaks.
  Sregister_symbol(
      "mlir::TypeConverter::TypeConverter", (void*)+[]() -> ptr {
        return Sunsigned64(
            reinterpret_cast<uint64_t>(new CrestBox<mlir::TypeConverter>()));
      });
  // LEAK WARNING: the box is on the C++ heap and only the caller frees it. Use
  // with-ConversionTarget, which frees it after its body; a box that is never
  // freed leaks.
  Sregister_symbol(
      "mlir::ConversionTarget::ConversionTarget",
      (void*)+[](uint64_t ctx_ptr) -> ptr {
        if (!ctx_ptr) {
          return scheme_error("mlir::ConversionTarget::ConversionTarget",
                              "ctx must not be null");
        }
        auto* ctx = crest::as_context(ctx_ptr);
        return Sunsigned64(reinterpret_cast<uint64_t>(
            new CrestBox<mlir::ConversionTarget>(*ctx)));
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addIllegalDialect",
      (void*)+[](uint64_t target_ptr, const char* dialect_name) -> ptr {
        if (!dialect_name) {
          return Svoid;
        }
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::ConversionTarget>::inner(target_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::ConversionTarget::addIllegalDialect",
              "null pointer or not a CrestBox<mlir::ConversionTarget>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.addIllegalDialect(dialect_name);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addLegalDialect",
      (void*)+[](uint64_t target_ptr, const char* dialect_name) -> ptr {
        if (!dialect_name) {
          return Svoid;
        }
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::ConversionTarget>::inner(target_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::ConversionTarget::addLegalDialect",
              "null pointer or not a CrestBox<mlir::ConversionTarget>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.addLegalDialect(dialect_name);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addLegalOp",
      (void*)+[](uint64_t target_ptr, uint64_t ctx_ptr,
                 const char* op_name) -> ptr {
        if (!ctx_ptr || !op_name) {
          return Svoid;
        }
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("mlir::ConversionTarget::addLegalOp",
                              "null MLIRContext pointer");
        }
        auto* crest_lookup1_box =
            crest::CrestBox<mlir::ConversionTarget>::inner(target_ptr);
        if (!crest_lookup1_box) {
          return scheme_error(
              "mlir::ConversionTarget::addLegalOp",
              "null pointer or not a CrestBox<mlir::ConversionTarget>");
        }
        auto& crest_lookup1 = *crest_lookup1_box;

        crest_lookup1.addLegalOp(mlir::OperationName(op_name, ctx));
        return Svoid;
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addDynamicallyLegalOp",
      (void*)+[](uint64_t target_ptr, uint64_t ctx_ptr, const char* op_name_arg,
                 LegalityFn* callback) -> ptr {
        const bool hasName = op_name_arg != nullptr;
        const std::string op_name(hasName ? op_name_arg : "");
        if (!ctx_ptr || !hasName) {
          return Svoid;
        }
        auto* target_box =
            crest::CrestBox<mlir::ConversionTarget>::inner(target_ptr);
        if (!target_box) {
          return scheme_error(
              "mlir::ConversionTarget::addDynamicallyLegalOp",
              "null pointer or not a CrestBox<mlir::ConversionTarget>");
        }
        auto& target = *target_box;
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("mlir::ConversionTarget::addDynamicallyLegalOp",
                              "null MLIRContext pointer");
        }
        target.addDynamicallyLegalOp(mlir::OperationName(op_name, ctx),
                                     [callback](mlir::Operation* op) -> bool {
                                       return isLegal(callback, op);
                                     });
        return Svoid;
      });
  Sregister_symbol(
      "mlir::ConversionTarget::markUnknownOpsDynamicallyLegal",
      (void*)+[](uint64_t target_ptr, LegalityFn* callback) -> ptr {
        auto* target_box =
            crest::CrestBox<mlir::ConversionTarget>::inner(target_ptr);
        if (!target_box) {
          return scheme_error(
              "mlir::ConversionTarget::markUnknownOpsDynamicallyLegal",
              "null pointer or not a CrestBox<mlir::ConversionTarget>");
        }
        auto& target = *target_box;
        target.markUnknownOpDynamicallyLegal(
            [callback](mlir::Operation* op) -> bool {
              return isLegal(callback, op);
            });
        return Svoid;
      });
  Sregister_symbol(
      "mlir::TypeConverter::addConversion",
      (void*)+[](uint64_t converter_ptr, TypeConversionFn* callback) -> ptr {
        auto* converter_box =
            crest::CrestBox<mlir::TypeConverter>::inner(converter_ptr);
        if (!converter_box) {
          return scheme_error(
              "mlir::TypeConverter::addConversion",
              "null pointer or not a CrestBox<mlir::TypeConverter>");
        }
        auto& converter = *converter_box;
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
        return Svoid;
      });
  Sregister_symbol(
      "mlir::TypeConverter::isLegal<Type>",
      (void*)+[](uint64_t converter_ptr, uint64_t type_ptr) -> ptr {
        if (!type_ptr) {
          return scheme_error("mlir::TypeConverter::isLegal<Type>",
                              "null type");
        }
        auto* converter_box =
            crest::CrestBox<mlir::TypeConverter>::inner(converter_ptr);
        if (!converter_box) {
          return scheme_error(
              "mlir::TypeConverter::isLegal<Type>",
              "null pointer or not a CrestBox<mlir::TypeConverter>");
        }
        auto& converter = *converter_box;
        mlir::Type type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        return Sinteger64(converter.isLegal(type) ? 1 : 0);
      });
  Sregister_symbol(
      "mlir::TypeConverter::isLegal<Operation>",
      (void*)+[](uint64_t converter_ptr, uint64_t op_ptr) -> ptr {
        if (!op_ptr) {
          return scheme_error("mlir::TypeConverter::isLegal<Operation>",
                              "null op");
        }
        auto* converter_box =
            crest::CrestBox<mlir::TypeConverter>::inner(converter_ptr);
        if (!converter_box) {
          return scheme_error(
              "mlir::TypeConverter::isLegal<Operation>",
              "null pointer or not a CrestBox<mlir::TypeConverter>");
        }
        auto& converter = *converter_box;
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return Sinteger64(converter.isLegal(op) ? 1 : 0);
      });
  Sregister_symbol(
      "mlir::TypeConverter::isSignatureLegal",
      (void*)+[](uint64_t converter_ptr, uint64_t func_op_ptr) -> ptr {
        if (!func_op_ptr) {
          return scheme_error("mlir::TypeConverter::isSignatureLegal",
                              "null func-op");
        }
        auto* converter_box =
            crest::CrestBox<mlir::TypeConverter>::inner(converter_ptr);
        if (!converter_box) {
          return scheme_error(
              "mlir::TypeConverter::isSignatureLegal",
              "null pointer or not a CrestBox<mlir::TypeConverter>");
        }
        auto& converter = *converter_box;
        auto func_op = mlir::dyn_cast<mlir::func::FuncOp>(
            reinterpret_cast<mlir::Operation*>(func_op_ptr));
        if (!func_op) {
          return scheme_error("mlir::TypeConverter::isSignatureLegal",
                              "op is not a func.func operation");
        }
        return Sinteger64(
            converter.isSignatureLegal(func_op.getFunctionType()) ? 1 : 0);
      });
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_apply_full_conversion",
      (void*)+[](uint64_t module_ptr, uint64_t target_ptr,
                 uint64_t patterns_ptr) -> ptr {
        if (!module_ptr || !target_ptr || !patterns_ptr) {
          return scheme_error(
              "mlir_transforms_dialect_conversion_apply_full_conversion",
              "module, target, and patterns must not be null");
        }
        auto module = mlir::dyn_cast<mlir::ModuleOp>(
            reinterpret_cast<mlir::Operation*>(module_ptr));
        if (!module) {
          return scheme_error(
              "mlir_transforms_dialect_conversion_apply_full_conversion",
              "op is not a module op");
        }
        auto* target_box =
            crest::CrestBox<mlir::ConversionTarget>::inner(target_ptr);
        if (!target_box) {
          return scheme_error(
              "mlir_transforms_dialect_conversion_apply_full_conversion",
              "null pointer or not a CrestBox<mlir::ConversionTarget>");
        }
        auto& target = *target_box;
        auto* patterns_box =
            crest::as_ref<mlir::RewritePatternSet>(patterns_ptr);
        if (!patterns_box) {
          return scheme_error(
              "mlir_transforms_dialect_conversion_apply_full_conversion",
              "null pointer or not a CrestBox<mlir::RewritePatternSet> or "
              "CrestBox<mlir::RewritePatternSet*>");
        }
        auto& patterns = *patterns_box;
        return Sinteger64(mlir::succeeded(mlir::applyFullConversion(
                              module, target, std::move(patterns)))
                              ? 1
                              : 0);
      });
  Sregister_symbol(
      "mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>",
      (void*)+[](uint64_t patterns_ptr, uint64_t converter_ptr) -> ptr {
        auto* patterns_box =
            crest::as_ref<mlir::RewritePatternSet>(patterns_ptr);
        if (!patterns_box) {
          return scheme_error(
              "mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>",
              "null pointer or not a CrestBox<mlir::RewritePatternSet> or "
              "CrestBox<mlir::RewritePatternSet*>");
        }
        auto& patterns = *patterns_box;
        auto* converter_box =
            crest::CrestBox<mlir::TypeConverter>::inner(converter_ptr);
        if (!converter_box) {
          return scheme_error(
              "mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>",
              "null pointer or not a CrestBox<mlir::TypeConverter>");
        }
        auto& converter = *converter_box;
        mlir::populateFunctionOpInterfaceTypeConversionPattern<
            mlir::func::FuncOp>(patterns, converter);
        return Svoid;
      });
  Sregister_symbol(
      "mlir::TypeConverter::addSourceMaterialization",
      (void*)+[](uint64_t converter_ptr, MaterializationFn* callback) -> ptr {
        auto* converter_box =
            crest::CrestBox<mlir::TypeConverter>::inner(converter_ptr);
        if (!converter_box) {
          return scheme_error(
              "mlir::TypeConverter::addSourceMaterialization",
              "null pointer or not a CrestBox<mlir::TypeConverter>");
        }
        auto& converter = *converter_box;
        converter.addSourceMaterialization(
            [callback](mlir::OpBuilder& builder, mlir::Type resultType,
                       mlir::ValueRange inputs,
                       mlir::Location loc) -> mlir::Value {
              return materialize(callback, builder, resultType, inputs, loc);
            });
        return Svoid;
      });
  Sregister_symbol(
      "mlir::TypeConverter::addTargetMaterialization",
      (void*)+[](uint64_t converter_ptr, MaterializationFn* callback) -> ptr {
        auto* converter_box =
            crest::CrestBox<mlir::TypeConverter>::inner(converter_ptr);
        if (!converter_box) {
          return scheme_error(
              "mlir::TypeConverter::addTargetMaterialization",
              "null pointer or not a CrestBox<mlir::TypeConverter>");
        }
        auto& converter = *converter_box;
        converter.addTargetMaterialization(
            [callback](mlir::OpBuilder& builder, mlir::Type resultType,
                       mlir::ValueRange inputs,
                       mlir::Location loc) -> mlir::Value {
              return materialize(callback, builder, resultType, inputs, loc);
            });
        return Svoid;
      });
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::TypeConverter>>",
      (void*)+[](uint64_t address) -> ptr {
        if (!address) {
          return Sinteger64(0);
        }
        return Sinteger64(reinterpret_cast<CrestObject*>(address)
                                  ->isa<CrestBox<mlir::TypeConverter>>()
                              ? 1
                              : 0);
      });
  Sregister_symbol(
      "crest::isa<CrestBox<mlir::ConversionTarget>>",
      (void*)+[](uint64_t address) -> ptr {
        if (!address) {
          return Sinteger64(0);
        }
        return Sinteger64(reinterpret_cast<CrestObject*>(address)
                                  ->isa<CrestBox<mlir::ConversionTarget>>()
                              ? 1
                              : 0);
      });

  // applyPartialConversion: partially lower ops, leaving unregistered ops.
  // (op-ptr target-ptr patterns-ptr) → 1 success | 0 failure
  Sregister_symbol(
      "mlir::applyPartialConversion",
      (void*)+[](uint64_t op_ptr, uint64_t target_ptr,
                 uint64_t patterns_ptr) -> ptr {
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto* target_box =
            crest::CrestBox<mlir::ConversionTarget>::inner(target_ptr);
        if (!target_box) {
          return scheme_error(
              "mlir::applyPartialConversion",
              "null pointer or not a CrestBox<mlir::ConversionTarget>");
        }
        auto& target = *target_box;
        auto* patterns_box =
            crest::as_ref<mlir::RewritePatternSet>(patterns_ptr);
        if (!patterns_box) {
          return scheme_error(
              "mlir::applyPartialConversion",
              "null pointer or not a CrestBox<mlir::RewritePatternSet> or "
              "CrestBox<mlir::RewritePatternSet*>");
        }
        auto& patterns = *patterns_box;
        return Sinteger64(mlir::succeeded(mlir::applyPartialConversion(
                              op, target, std::move(patterns)))
                              ? 1
                              : 0);
      });

  // modifyOpInPlace: mutate an op inside a rewriter notification.
  // (rw-ptr op-ptr thunk) → void  where thunk is a C function void() that
  // Scheme made and keeps alive until the call returns. MLIR's callback is
  // void, so an error of the thunk ends the process (Rule 20).
  Sregister_symbol(
      "mlir::RewriterBase::modifyOpInPlace",
      (void*)+[](uint64_t rw_ptr, uint64_t op_ptr, void (*thunk)()) -> ptr {
        auto* rw_box = crest::CrestBox<mlir::RewriterBase*>::inner(rw_ptr);
        if (!rw_box) {
          return scheme_error(
              "mlir::RewriterBase::modifyOpInPlace",
              "null pointer or not a CrestBox<mlir::RewriterBase*>");
        }
        auto& rw = *rw_box;
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        rw.modifyOpInPlace(op, [&]() { thunk(); });
        return Svoid;
      });
}

} // namespace crest
