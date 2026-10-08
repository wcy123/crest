/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/DialectConversion.h

#include "mlir/Transforms/DialectConversion.h"
#include "../Support/ArrayRef.h"
#include "../Support/CrestObject.h"
#include "../Support/LockedSchemeObject.h"
#include "../Support/Logging.h"
#include "../Support/SchemeWrapper.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Value.h"

// Calls a Scheme callback as (callback op operands-ref rewriter type-converter)
// → #t/#f.
// rewriter is a heap-allocated CrestRef<mlir::RewriterBase> shell; Scheme frees
// it via with-CrestObject.
// type-converter is the CrestOwned<mlir::TypeConverter>* — Scheme uses it
// opaquely.
class SchemeConversionPattern : public mlir::ConversionPattern {
public:
  SchemeConversionPattern(mlir::TypeConverter* typeConverter,
                          mlir::MLIRContext* ctx, ptr schemeCallback,
                          llvm::StringRef opName, int benefit,
                          uint64_t schemeConverterPtr)
      : ConversionPattern(*typeConverter, opName, benefit, ctx),
        callback_(schemeCallback), targetOpName(opName.str()),
        schemeTypeConverterPtr_(schemeConverterPtr) {}

  mlir::LogicalResult
  matchAndRewrite(mlir::Operation* op, mlir::ArrayRef<mlir::Value> operands,
                  mlir::ConversionPatternRewriter& rewriter) const override {
    if (op->getName().getStringRef() != targetOpName) {
      return mlir::failure();
    }
    ptr opPtr = Sunsigned64(reinterpret_cast<uint64_t>(op));
    // Wrap operands in a heap-allocated CArrayRef; C++ frees it after the call.
    auto* operandsWrapped = new CArrayRef<uintptr_t>(
        reinterpret_cast<const uintptr_t*>(operands.data()), operands.size());
    ptr operandsRefPtr =
        Sunsigned64(reinterpret_cast<uint64_t>(operandsWrapped));
    // Heap-allocate CrestRef shell for rewriter — Scheme frees via
    // with-CrestObject.
    auto* rwShell = new crest::CrestRef<mlir::RewriterBase>(&rewriter);
    ptr rewriterPtr = Sunsigned64(reinterpret_cast<uint64_t>(rwShell));
    ptr typeConverterPtr = Sunsigned64(schemeTypeConverterPtr_);
    ptr args_list =
        Scons(opPtr, Scons(operandsRefPtr,
                           Scons(rewriterPtr, Scons(typeConverterPtr, Snil))));
    ptr result = scheme_apply(callback_.get(), args_list);
    delete operandsWrapped;
    // rwShell is freed by Scheme via with-CrestObject — do NOT delete here.
    return result == Strue ? mlir::success() : mlir::failure();
  }

private:
  crest::LockedSchemeObject callback_;
  std::string targetOpName;
  uint64_t schemeTypeConverterPtr_;
};

// Calls a Scheme callback as (callback op rewriter) → #t/#f.
// rewriter is a heap-allocated CrestRef<mlir::RewriterBase> shell; Scheme frees
// it.
class SchemeRewritePattern : public mlir::RewritePattern {
public:
  SchemeRewritePattern(mlir::MLIRContext* ctx,
                       crest::LockedSchemeObject&& schemeCallback,
                       llvm::StringRef opName, int benefit = 1)
      : RewritePattern(opName, benefit, ctx),
        callback_(std::move(schemeCallback)), targetOpName(opName.str()) {}

  mlir::LogicalResult
  matchAndRewrite(mlir::Operation* op,
                  mlir::PatternRewriter& rewriter) const override {
    if (op->getName().getStringRef() != targetOpName) {
      return mlir::failure();
    }
    ptr opPtr = Sunsigned64(reinterpret_cast<uint64_t>(op));
    // Heap-allocate CrestRef shell — Scheme frees via with-CrestObject.
    auto* rwShell = new crest::CrestRef<mlir::RewriterBase>(&rewriter);
    ptr rewriterPtr = Sunsigned64(reinterpret_cast<uint64_t>(rwShell));
    ptr args_list = Scons(opPtr, Scons(rewriterPtr, Snil));
    ptr result = scheme_apply(callback_.get(), args_list);
    // rwShell freed by Scheme — do NOT delete here.
    return result == Strue ? mlir::success() : mlir::failure();
  }

private:
  crest::LockedSchemeObject callback_;
  std::string targetOpName;
};

namespace crest {

void registerTransformsDialectConversionBindings() {
  Sregister_symbol(
      "crest::DialectConversion::addConversionPattern",
      (void*)+[](uint64_t patterns_ptr, const char* op_name, ptr callback,
                 uint64_t type_converter_ptr, int benefit) -> void {
        auto* patterns =
            &reinterpret_cast<CrestOwned<mlir::RewritePatternSet>*>(
                 patterns_ptr)
                 ->inner;
        auto* typeConverter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(
                 type_converter_ptr)
                 ->inner;
        mlir_support_logging_info(
            (std::string("Registering Scheme pattern for ") + op_name).c_str());
        patterns->add<SchemeConversionPattern>(
            typeConverter, patterns->getContext(), static_cast<ptr>(callback),
            llvm::StringRef(op_name), benefit, type_converter_ptr);
      });
  Sregister_symbol(
      "crest::DialectConversion::addRewritePattern",
      (void*)+[](uint64_t patterns_ptr, const char* op_name, ptr callback,
                 int benefit) -> void {
        auto* patterns =
            &reinterpret_cast<CrestOwned<mlir::RewritePatternSet>*>(
                 patterns_ptr)
                 ->inner;
        crest::LockedSchemeObject lockedCallback(callback);
        mlir_support_logging_info(
            (std::string("Registering Scheme rewrite pattern for ") + op_name)
                .c_str());
        patterns->add<SchemeRewritePattern>(patterns->getContext(),
                                            std::move(lockedCallback),
                                            llvm::StringRef(op_name), benefit);
      });
  Sregister_symbol(
      "mlir::TypeConverter::TypeConverter", (void*)+[]() -> uint64_t {
        return reinterpret_cast<uint64_t>(
            new CrestOwned<mlir::TypeConverter>());
      });
  Sregister_symbol(
      "mlir::ConversionTarget::ConversionTarget",
      (void*)+[](uint64_t ctx_ptr) -> uint64_t {
        if (!ctx_ptr) {
          scheme_error("mlir::ConversionTarget::ConversionTarget",
                       "ctx must not be null");
        }
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        return reinterpret_cast<uint64_t>(
            new CrestOwned<mlir::ConversionTarget>(*ctx));
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addIllegalDialect",
      (void*)+[](uint64_t target_ptr, const char* dialect_name) -> void {
        if (!target_ptr || !dialect_name) {
          return;
        }
        reinterpret_cast<CrestOwned<mlir::ConversionTarget>*>(target_ptr)
            ->inner.addIllegalDialect(dialect_name);
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addLegalDialect",
      (void*)+[](uint64_t target_ptr, const char* dialect_name) -> void {
        if (!target_ptr || !dialect_name) {
          return;
        }
        reinterpret_cast<CrestOwned<mlir::ConversionTarget>*>(target_ptr)
            ->inner.addLegalDialect(dialect_name);
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addLegalOp",
      (void*)+[](uint64_t target_ptr, uint64_t ctx_ptr,
                 const char* op_name) -> void {
        if (!target_ptr || !ctx_ptr || !op_name) {
          return;
        }
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        reinterpret_cast<CrestOwned<mlir::ConversionTarget>*>(target_ptr)
            ->inner.addLegalOp(mlir::OperationName(op_name, ctx));
      });
  Sregister_symbol(
      "mlir::ConversionTarget::addDynamicallyLegalOp",
      (void*)+[](uint64_t target_ptr, uint64_t ctx_ptr, const char* op_name,
                 ptr callback) -> void {
        if (!target_ptr || !ctx_ptr || !op_name) {
          return;
        }
        auto* target =
            &reinterpret_cast<CrestOwned<mlir::ConversionTarget>*>(target_ptr)
                 ->inner;
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
        target->addDynamicallyLegalOp(
            mlir::OperationName(op_name, ctx),
            [locked](mlir::Operation* op) -> bool {
              ptr op_arg = Sunsigned64(reinterpret_cast<uint64_t>(op));
              ptr result = Scall1(locked->get(), op_arg);
              return result != Sfalse && result != Sfixnum(0);
            });
      });
  Sregister_symbol(
      "mlir::ConversionTarget::markUnknownOpsDynamicallyLegal",
      (void*)+[](uint64_t target_ptr, ptr callback) -> void {
        if (!target_ptr) {
          return;
        }
        auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
        reinterpret_cast<CrestOwned<mlir::ConversionTarget>*>(target_ptr)
            ->inner.markUnknownOpDynamicallyLegal(
                [locked](mlir::Operation* op) -> bool {
                  ptr op_arg = Sunsigned64(reinterpret_cast<uint64_t>(op));
                  ptr result = Scall1(locked->get(), op_arg);
                  return result != Sfalse && result != Sfixnum(0);
                });
      });
  Sregister_symbol(
      "mlir::TypeConverter::addConversion",
      (void*)+[](uint64_t converter_ptr, ptr callback) -> void {
        if (!converter_ptr) {
          return;
        }
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
        converter->addConversion(
            [locked](mlir::Type type) -> std::optional<mlir::Type> {
              ptr type_arg = Sunsigned64(
                  reinterpret_cast<uint64_t>(type.getAsOpaquePointer()));
              ptr result = Scall1(locked->get(), type_arg);
              if (result == Sfalse) {
                return std::nullopt;
              }
              uint64_t result_val = Sunsigned64_value(result);
              if (result_val == 0) {
                return std::nullopt;
              }
              return mlir::Type::getFromOpaquePointer(
                  reinterpret_cast<const void*>(result_val));
            });
      });
  Sregister_symbol(
      "mlir::TypeConverter::isLegal<Type>",
      (void*)+[](uint64_t converter_ptr, uint64_t type_ptr) -> int {
        if (!converter_ptr || !type_ptr) {
          scheme_error("mlir::TypeConverter::isLegal<Type>",
                       "converter and type must not be null");
        }
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        mlir::Type type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        return converter->isLegal(type) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::TypeConverter::isLegal<Operation>",
      (void*)+[](uint64_t converter_ptr, uint64_t op_ptr) -> int {
        if (!converter_ptr || !op_ptr) {
          scheme_error("mlir::TypeConverter::isLegal<Operation>",
                       "converter and op must not be null");
        }
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return converter->isLegal(op) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir::TypeConverter::isSignatureLegal",
      (void*)+[](uint64_t converter_ptr, uint64_t func_op_ptr) -> int {
        if (!converter_ptr || !func_op_ptr) {
          scheme_error("mlir::TypeConverter::isSignatureLegal",
                       "converter and func-op must not be null");
        }
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        auto func_op = mlir::dyn_cast<mlir::func::FuncOp>(
            reinterpret_cast<mlir::Operation*>(func_op_ptr));
        if (!func_op) {
          scheme_error("mlir::TypeConverter::isSignatureLegal",
                       "op is not a func.func operation");
        }
        return converter->isSignatureLegal(func_op.getFunctionType()) ? 1 : 0;
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
        auto* target =
            &reinterpret_cast<CrestOwned<mlir::ConversionTarget>*>(target_ptr)
                 ->inner;
        auto& patterns =
            reinterpret_cast<CrestOwned<mlir::RewritePatternSet>*>(patterns_ptr)
                ->inner;
        return mlir::succeeded(mlir::applyFullConversion(module, *target,
                                                         std::move(patterns)))
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "mlir::populateFunctionOpInterfaceTypeConversionPattern<FuncOp>",
      (void*)+[](uint64_t patterns_ptr, uint64_t converter_ptr) -> void {
        if (!patterns_ptr || !converter_ptr) {
          return;
        }
        auto& patterns =
            reinterpret_cast<CrestOwned<mlir::RewritePatternSet>*>(patterns_ptr)
                ->inner;
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        mlir::populateFunctionOpInterfaceTypeConversionPattern<
            mlir::func::FuncOp>(patterns, *converter);
      });
  Sregister_symbol(
      "mlir::TypeConverter::addSourceMaterialization",
      (void*)+[](uint64_t converter_ptr, ptr callback) -> void {
        if (!converter_ptr) {
          return;
        }
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
        converter->addSourceMaterialization(
            [locked](mlir::OpBuilder& builder, mlir::Type resultType,
                     mlir::ValueRange inputs,
                     mlir::Location loc) -> mlir::Value {
              // Wrap builder in CrestRef shell; freed by Scheme via
              // with-CrestObject.
              auto* builderShell = new CrestRef<mlir::OpBuilder>(&builder);
              ptr builder_arg =
                  Sunsigned64(reinterpret_cast<uint64_t>(builderShell));
              ptr result_type_arg = Sunsigned64(
                  reinterpret_cast<uint64_t>(resultType.getAsOpaquePointer()));
              ptr inputs_list = Snil;
              for (int i = static_cast<int>(inputs.size()) - 1; i >= 0; --i) {
                inputs_list = Scons(Sunsigned64(reinterpret_cast<uint64_t>(
                                        inputs[i].getAsOpaquePointer())),
                                    inputs_list);
              }
              ptr loc_arg = Sunsigned64(
                  reinterpret_cast<uint64_t>(loc.getAsOpaquePointer()));
              ptr args = Scons(builder_arg,
                               Scons(result_type_arg,
                                     Scons(inputs_list, Scons(loc_arg, Snil))));
              ptr result = scheme_apply(locked->get(), args);
              if (result == Sfalse || result == Sfixnum(0)) {
                return nullptr;
              }
              uint64_t val = Sunsigned64_value(result);
              if (!val) {
                return nullptr;
              }
              return mlir::Value::getFromOpaquePointer(
                  reinterpret_cast<const void*>(val));
            });
      });
  Sregister_symbol(
      "mlir::TypeConverter::addTargetMaterialization",
      (void*)+[](uint64_t converter_ptr, ptr callback) -> void {
        if (!converter_ptr) {
          return;
        }
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
        converter->addTargetMaterialization(
            [locked](mlir::OpBuilder& builder, mlir::Type resultType,
                     mlir::ValueRange inputs,
                     mlir::Location loc) -> mlir::Value {
              // Wrap builder in CrestRef shell; freed by Scheme via
              // with-CrestObject.
              auto* builderShell = new CrestRef<mlir::OpBuilder>(&builder);
              ptr builder_arg =
                  Sunsigned64(reinterpret_cast<uint64_t>(builderShell));
              ptr result_type_arg = Sunsigned64(
                  reinterpret_cast<uint64_t>(resultType.getAsOpaquePointer()));
              ptr inputs_list = Snil;
              for (int i = static_cast<int>(inputs.size()) - 1; i >= 0; --i) {
                inputs_list = Scons(Sunsigned64(reinterpret_cast<uint64_t>(
                                        inputs[i].getAsOpaquePointer())),
                                    inputs_list);
              }
              ptr loc_arg = Sunsigned64(
                  reinterpret_cast<uint64_t>(loc.getAsOpaquePointer()));
              ptr args = Scons(builder_arg,
                               Scons(result_type_arg,
                                     Scons(inputs_list, Scons(loc_arg, Snil))));
              ptr result = scheme_apply(locked->get(), args);
              if (result == Sfalse || result == Sfixnum(0)) {
                return nullptr;
              }
              uint64_t val = Sunsigned64_value(result);
              if (!val) {
                return nullptr;
              }
              return mlir::Value::getFromOpaquePointer(
                  reinterpret_cast<const void*>(val));
            });
      });
  Sregister_symbol(
      "crest::isa<CrestOwned<mlir::TypeConverter>>",
      (void*)+[](uint64_t ptr) -> int {
        if (!ptr) {
          return 0;
        }
        return reinterpret_cast<CrestObject*>(ptr)
                       ->isa<CrestOwned<mlir::TypeConverter>>()
                   ? 1
                   : 0;
      });
  Sregister_symbol(
      "crest::isa<CrestOwned<mlir::ConversionTarget>>",
      (void*)+[](uint64_t ptr) -> int {
        if (!ptr) {
          return 0;
        }
        return reinterpret_cast<CrestObject*>(ptr)
                       ->isa<CrestOwned<mlir::ConversionTarget>>()
                   ? 1
                   : 0;
      });

  // ── Backward-compat aliases (old names) ──────────────────────────────────
  Sregister_symbol(
      "mlir_conversion_target_add_illegal_dialect",
      (void*)+[](uint64_t target_ptr, const char* dialect_name) -> void {
        if (!target_ptr || !dialect_name) {
          return;
        }
        reinterpret_cast<CrestOwned<mlir::ConversionTarget>*>(target_ptr)
            ->inner.addIllegalDialect(dialect_name);
      });
  Sregister_symbol(
      "mlir_conversion_target_add_legal_dialect",
      (void*)+[](uint64_t target_ptr, const char* dialect_name) -> void {
        if (!target_ptr || !dialect_name) {
          return;
        }
        reinterpret_cast<CrestOwned<mlir::ConversionTarget>*>(target_ptr)
            ->inner.addLegalDialect(dialect_name);
      });
  Sregister_symbol(
      "mlir_conversion_target_add_legal_op",
      (void*)+[](uint64_t target_ptr, uint64_t ctx_ptr,
                 const char* op_name) -> void {
        if (!target_ptr || !ctx_ptr || !op_name) {
          return;
        }
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        reinterpret_cast<CrestOwned<mlir::ConversionTarget>*>(target_ptr)
            ->inner.addLegalOp(mlir::OperationName(op_name, ctx));
      });
  Sregister_symbol(
      "mlir_conversion_target_add_dynamically_legal_op",
      (void*)+[](uint64_t target_ptr, uint64_t ctx_ptr, const char* op_name,
                 ptr callback) -> void {
        if (!target_ptr || !ctx_ptr || !op_name) {
          return;
        }
        auto* target =
            &reinterpret_cast<CrestOwned<mlir::ConversionTarget>*>(target_ptr)
                 ->inner;
        auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
        auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
        target->addDynamicallyLegalOp(
            mlir::OperationName(op_name, ctx),
            [locked](mlir::Operation* op) -> bool {
              ptr op_arg = Sunsigned64(reinterpret_cast<uint64_t>(op));
              ptr result = Scall1(locked->get(), op_arg);
              return result != Sfalse && result != Sfixnum(0);
            });
      });
  Sregister_symbol(
      "mlir_conversion_target_mark_unknown_ops_dynamically_legal",
      (void*)+[](uint64_t target_ptr, ptr callback) -> void {
        if (!target_ptr) {
          return;
        }
        auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
        reinterpret_cast<CrestOwned<mlir::ConversionTarget>*>(target_ptr)
            ->inner.markUnknownOpDynamicallyLegal(
                [locked](mlir::Operation* op) -> bool {
                  ptr op_arg = Sunsigned64(reinterpret_cast<uint64_t>(op));
                  ptr result = Scall1(locked->get(), op_arg);
                  return result != Sfalse && result != Sfixnum(0);
                });
      });
  Sregister_symbol(
      "mlir_type_converter_add_conversion",
      (void*)+[](uint64_t converter_ptr, ptr callback) -> void {
        if (!converter_ptr) {
          return;
        }
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
        converter->addConversion(
            [locked](mlir::Type type) -> std::optional<mlir::Type> {
              ptr type_arg = Sunsigned64(
                  reinterpret_cast<uint64_t>(type.getAsOpaquePointer()));
              ptr result = Scall1(locked->get(), type_arg);
              if (result == Sfalse) {
                return std::nullopt;
              }
              uint64_t result_val = Sunsigned64_value(result);
              if (result_val == 0) {
                return std::nullopt;
              }
              return mlir::Type::getFromOpaquePointer(
                  reinterpret_cast<const void*>(result_val));
            });
      });
  Sregister_symbol(
      "mlir_type_converter_is_legal_type",
      (void*)+[](uint64_t converter_ptr, uint64_t type_ptr) -> int {
        if (!converter_ptr || !type_ptr) {
          scheme_error("mlir_type_converter_is_legal_type",
                       "converter and type must not be null");
        }
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        mlir::Type type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        return converter->isLegal(type) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir_type_converter_is_legal",
      (void*)+[](uint64_t converter_ptr, uint64_t op_ptr) -> int {
        if (!converter_ptr || !op_ptr) {
          scheme_error("mlir_type_converter_is_legal",
                       "converter and op must not be null");
        }
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        return converter->isLegal(op) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir_type_converter_is_signature_legal",
      (void*)+[](uint64_t converter_ptr, uint64_t func_op_ptr) -> int {
        if (!converter_ptr || !func_op_ptr) {
          scheme_error("mlir_type_converter_is_signature_legal",
                       "converter and func-op must not be null");
        }
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        auto func_op = mlir::dyn_cast<mlir::func::FuncOp>(
            reinterpret_cast<mlir::Operation*>(func_op_ptr));
        if (!func_op) {
          scheme_error("mlir_type_converter_is_signature_legal",
                       "op is not a func.func operation");
        }
        return converter->isSignatureLegal(func_op.getFunctionType()) ? 1 : 0;
      });
  Sregister_symbol(
      "mlir_populate_func_type_conversion_pattern",
      (void*)+[](uint64_t patterns_ptr, uint64_t converter_ptr) -> void {
        if (!patterns_ptr || !converter_ptr) {
          return;
        }
        auto& patterns =
            reinterpret_cast<CrestOwned<mlir::RewritePatternSet>*>(patterns_ptr)
                ->inner;
        auto* converter =
            &reinterpret_cast<CrestOwned<mlir::TypeConverter>*>(converter_ptr)
                 ->inner;
        mlir::populateFunctionOpInterfaceTypeConversionPattern<
            mlir::func::FuncOp>(patterns, *converter);
      });
}

} // namespace crest
