/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/Transforms/DialectConversion.h

#include "mlir/Transforms/DialectConversion.h"
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
class SchemeConversionPattern : public mlir::ConversionPattern {
public:
  SchemeConversionPattern(mlir::TypeConverter* typeConverter,
                          mlir::MLIRContext* ctx, ptr schemeCallback,
                          llvm::StringRef opName, int benefit = 1)
      : ConversionPattern(*typeConverter, opName, benefit, ctx),
        callback_(schemeCallback), targetOpName(opName.str()) {}

  mlir::LogicalResult
  matchAndRewrite(mlir::Operation* op, mlir::ArrayRef<mlir::Value> operands,
                  mlir::ConversionPatternRewriter& rewriter) const override {
    if (op->getName().getStringRef() != targetOpName) {
      return mlir::failure();
    }
    ptr opPtr = Sunsigned64(reinterpret_cast<uint64_t>(op));
    ptr operandsRefPtr = Sunsigned64(reinterpret_cast<uint64_t>(&operands));
    ptr rewriterPtr = Sunsigned64(reinterpret_cast<uint64_t>(&rewriter));
    ptr typeConverterPtr =
        Sunsigned64(reinterpret_cast<uint64_t>(getTypeConverter()));
    ptr args_list =
        Scons(opPtr, Scons(operandsRefPtr,
                           Scons(rewriterPtr, Scons(typeConverterPtr, Snil))));
    ptr result = scheme_apply(callback_.get(), args_list);
    return result == Strue ? mlir::success() : mlir::failure();
  }

private:
  crest::LockedSchemeObject callback_;
  std::string targetOpName;
};

// Calls a Scheme callback as (callback op rewriter) → #t/#f.
// No TypeConverter — for local rewrites only.
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
    ptr rewriterPtr = Sunsigned64(reinterpret_cast<uint64_t>(&rewriter));
    ptr args_list = Scons(opPtr, Scons(rewriterPtr, Snil));
    ptr result = scheme_apply(callback_.get(), args_list);
    return result == Strue ? mlir::success() : mlir::failure();
  }

private:
  crest::LockedSchemeObject callback_;
  std::string targetOpName;
};

extern "C" {

static void mlir_transforms_dialect_conversion_add_conversion_pattern(
    ptr patterns_ptr, const char* op_name, ptr callback, ptr type_converter_ptr,
    int benefit) {
  auto* patterns = reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
  auto* typeConverter =
      reinterpret_cast<mlir::TypeConverter*>(type_converter_ptr);
  mlir_support_logging_info(
      (std::string("Registering Scheme pattern for ") + op_name).c_str());
  patterns->add<SchemeConversionPattern>(typeConverter, patterns->getContext(),
                                         static_cast<ptr>(callback),
                                         llvm::StringRef(op_name), benefit);
}

static void mlir_transforms_dialect_conversion_add_rewrite_pattern(
    ptr patterns_ptr, const char* op_name, ptr callback, int benefit) {
  auto* patterns = reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
  crest::LockedSchemeObject lockedCallback(callback);
  mlir_support_logging_info(
      (std::string("Registering Scheme rewrite pattern for ") + op_name)
          .c_str());
  patterns->add<SchemeRewritePattern>(patterns->getContext(),
                                      std::move(lockedCallback),
                                      llvm::StringRef(op_name), benefit);
}

static uint64_t mlir_transforms_dialect_conversion_type_converter_create() {
  return reinterpret_cast<uint64_t>(new mlir::TypeConverter());
}

static void mlir_transforms_dialect_conversion_type_converter_destroy(
    uint64_t converter_ptr) {
  if (!converter_ptr) {
    return;
  }
  delete reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
}

static uint64_t
mlir_transforms_dialect_conversion_target_create(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir-transforms-dialect-conversion-target-create",
                 "ctx must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(new mlir::ConversionTarget(*ctx));
}

static void
mlir_transforms_dialect_conversion_target_destroy(uint64_t target_ptr) {
  if (!target_ptr) {
    return;
  }
  delete reinterpret_cast<mlir::ConversionTarget*>(target_ptr);
}

static void mlir_transforms_dialect_conversion_target_add_illegal_dialect(
    uint64_t target_ptr, const char* dialect_name) {
  if (!target_ptr || !dialect_name) {
    return;
  }
  reinterpret_cast<mlir::ConversionTarget*>(target_ptr)
      ->addIllegalDialect(dialect_name);
}

static void mlir_transforms_dialect_conversion_target_add_legal_dialect(
    uint64_t target_ptr, const char* dialect_name) {
  if (!target_ptr || !dialect_name) {
    return;
  }
  reinterpret_cast<mlir::ConversionTarget*>(target_ptr)
      ->addLegalDialect(dialect_name);
}

static void mlir_transforms_dialect_conversion_target_add_legal_op(
    uint64_t target_ptr, uint64_t ctx_ptr, const char* op_name) {
  if (!target_ptr || !ctx_ptr || !op_name) {
    return;
  }
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  reinterpret_cast<mlir::ConversionTarget*>(target_ptr)
      ->addLegalOp(mlir::OperationName(op_name, ctx));
}

static void mlir_transforms_dialect_conversion_target_add_dynamically_legal_op(
    uint64_t target_ptr, uint64_t ctx_ptr, const char* op_name, ptr callback) {
  if (!target_ptr || !ctx_ptr || !op_name) {
    return;
  }
  auto* target = reinterpret_cast<mlir::ConversionTarget*>(target_ptr);
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  // shared_ptr: std::function requires a copyable callable; LockedSchemeObject
  // is non-copyable.
  auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
  target->addDynamicallyLegalOp(
      mlir::OperationName(op_name, ctx), [locked](mlir::Operation* op) -> bool {
        ptr op_arg = Sunsigned64(reinterpret_cast<uint64_t>(op));
        ptr result = Scall1(locked->get(), op_arg);
        return result != Sfalse && result != Sfixnum(0);
      });
}

static void
mlir_transforms_dialect_conversion_target_mark_unknown_ops_dynamically_legal(
    uint64_t target_ptr, ptr callback) {
  if (!target_ptr) {
    return;
  }
  auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
  reinterpret_cast<mlir::ConversionTarget*>(target_ptr)
      ->markUnknownOpDynamicallyLegal([locked](mlir::Operation* op) -> bool {
        ptr op_arg = Sunsigned64(reinterpret_cast<uint64_t>(op));
        ptr result = Scall1(locked->get(), op_arg);
        return result != Sfalse && result != Sfixnum(0);
      });
}

// callback: (lambda (type-uptr) -> type-uptr-or-#f); #f means not handled.
static void mlir_transforms_dialect_conversion_type_converter_add_conversion(
    uint64_t converter_ptr, ptr callback) {
  if (!converter_ptr) {
    return;
  }
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
  converter->addConversion(
      [locked](mlir::Type type) -> std::optional<mlir::Type> {
        ptr type_arg =
            Sunsigned64(reinterpret_cast<uint64_t>(type.getAsOpaquePointer()));
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
}

static int mlir_transforms_dialect_conversion_type_converter_is_legal_type(
    uint64_t converter_ptr, uint64_t type_ptr) {
  if (!converter_ptr || !type_ptr) {
    scheme_error(
        "mlir-transforms-dialect-conversion-type-converter-is-legal-type",
        "converter and type must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  mlir::Type type =
      mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr));
  return converter->isLegal(type) ? 1 : 0;
}

static int mlir_transforms_dialect_conversion_type_converter_is_legal(
    uint64_t converter_ptr, uint64_t op_ptr) {
  if (!converter_ptr || !op_ptr) {
    scheme_error("mlir-transforms-dialect-conversion-type-converter-is-legal",
                 "converter and op must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  return converter->isLegal(op) ? 1 : 0;
}

static int mlir_transforms_dialect_conversion_type_converter_is_signature_legal(
    uint64_t converter_ptr, uint64_t func_op_ptr) {
  if (!converter_ptr || !func_op_ptr) {
    scheme_error(
        "mlir-transforms-dialect-conversion-type-converter-is-signature-legal",
        "converter and func-op must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  auto func_op = mlir::dyn_cast<mlir::func::FuncOp>(
      reinterpret_cast<mlir::Operation*>(func_op_ptr));
  if (!func_op) {
    scheme_error(
        "mlir-transforms-dialect-conversion-type-converter-is-signature-legal",
        "op is not a func.func operation");
    return 0; // unreachable — error performs non-local exit
  }
  return converter->isSignatureLegal(func_op.getFunctionType()) ? 1 : 0;
}

static uint64_t
mlir_transforms_dialect_conversion_pattern_set_create(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    scheme_error("mlir-transforms-dialect-conversion-pattern-set-create",
                 "ctx must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(new mlir::RewritePatternSet(ctx));
}

static void
mlir_transforms_dialect_conversion_pattern_set_destroy(uint64_t patterns_ptr) {
  if (!patterns_ptr) {
    return;
  }
  delete reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
}

// Returns 1 on success, 0 on failure. Takes ownership of patterns.
static int mlir_transforms_dialect_conversion_apply_full_conversion(
    uint64_t module_ptr, uint64_t target_ptr, uint64_t patterns_ptr) {
  if (!module_ptr || !target_ptr || !patterns_ptr) {
    scheme_error("mlir-transforms-dialect-conversion-apply-full-conversion",
                 "module, target, and patterns must not be null");
    return 0; // unreachable — error performs non-local exit
  }
  auto module = mlir::dyn_cast<mlir::ModuleOp>(
      reinterpret_cast<mlir::Operation*>(module_ptr));
  if (!module) {
    scheme_error("mlir-transforms-dialect-conversion-apply-full-conversion",
                 "op is not a module op");
    return 0; // unreachable — error performs non-local exit
  }
  auto* target = reinterpret_cast<mlir::ConversionTarget*>(target_ptr);
  auto* patterns = reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
  return mlir::succeeded(
      mlir::applyFullConversion(module, *target, std::move(*patterns)));
}

static void mlir_transforms_dialect_conversion_populate_func_type_conversion(
    uint64_t patterns_ptr, uint64_t converter_ptr) {
  if (!patterns_ptr || !converter_ptr) {
    return;
  }
  auto* patterns = reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  mlir::populateFunctionOpInterfaceTypeConversionPattern<mlir::func::FuncOp>(
      *patterns, *converter);
}

// callback: (lambda (builder-uptr result-type-uptr inputs-list loc-uptr) ->
//            value-uptr | #f/#0); #f/0 means not handled (return nullptr).
// inputs-list is a Scheme list of value uptrs.
static void
mlir_transforms_dialect_conversion_type_converter_add_source_materialization(
    uint64_t converter_ptr, ptr callback) {
  if (!converter_ptr) {
    return;
  }
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
  converter->addSourceMaterialization(
      [locked](mlir::OpBuilder& builder, mlir::Type resultType,
               mlir::ValueRange inputs, mlir::Location loc) -> mlir::Value {
        ptr builder_arg = Sunsigned64(reinterpret_cast<uint64_t>(&builder));
        ptr result_type_arg = Sunsigned64(
            reinterpret_cast<uint64_t>(resultType.getAsOpaquePointer()));
        ptr inputs_list = Snil;
        for (int i = static_cast<int>(inputs.size()) - 1; i >= 0; --i) {
          inputs_list = Scons(Sunsigned64(reinterpret_cast<uint64_t>(
                                  inputs[i].getAsOpaquePointer())),
                              inputs_list);
        }
        ptr loc_arg =
            Sunsigned64(reinterpret_cast<uint64_t>(loc.getAsOpaquePointer()));
        ptr args =
            Scons(builder_arg, Scons(result_type_arg,
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
}

// Same as add_source_materialization but registers a target materialization.
static void
mlir_transforms_dialect_conversion_type_converter_add_target_materialization(
    uint64_t converter_ptr, ptr callback) {
  if (!converter_ptr) {
    return;
  }
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  auto locked = std::make_shared<crest::LockedSchemeObject>(callback);
  converter->addTargetMaterialization(
      [locked](mlir::OpBuilder& builder, mlir::Type resultType,
               mlir::ValueRange inputs, mlir::Location loc) -> mlir::Value {
        ptr builder_arg = Sunsigned64(reinterpret_cast<uint64_t>(&builder));
        ptr result_type_arg = Sunsigned64(
            reinterpret_cast<uint64_t>(resultType.getAsOpaquePointer()));
        ptr inputs_list = Snil;
        for (int i = static_cast<int>(inputs.size()) - 1; i >= 0; --i) {
          inputs_list = Scons(Sunsigned64(reinterpret_cast<uint64_t>(
                                  inputs[i].getAsOpaquePointer())),
                              inputs_list);
        }
        ptr loc_arg =
            Sunsigned64(reinterpret_cast<uint64_t>(loc.getAsOpaquePointer()));
        ptr args =
            Scons(builder_arg, Scons(result_type_arg,
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
}

} // extern "C"

namespace crest {

void registerTransformsDialectConversionBindings() {
  // ── New canonical names ───────────────────────────────────────────────────
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_add_conversion_pattern",
      (void*)::mlir_transforms_dialect_conversion_add_conversion_pattern);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_add_rewrite_pattern",
      (void*)::mlir_transforms_dialect_conversion_add_rewrite_pattern);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_type_converter_create",
      (void*)::mlir_transforms_dialect_conversion_type_converter_create);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_type_converter_destroy",
      (void*)::mlir_transforms_dialect_conversion_type_converter_destroy);
  Sregister_symbol("mlir_transforms_dialect_conversion_target_create",
                   (void*)::mlir_transforms_dialect_conversion_target_create);
  Sregister_symbol("mlir_transforms_dialect_conversion_target_destroy",
                   (void*)::mlir_transforms_dialect_conversion_target_destroy);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_target_add_illegal_dialect",
      (void*)::mlir_transforms_dialect_conversion_target_add_illegal_dialect);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_target_add_legal_dialect",
      (void*)::mlir_transforms_dialect_conversion_target_add_legal_dialect);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_target_add_legal_op",
      (void*)::mlir_transforms_dialect_conversion_target_add_legal_op);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_target_add_dynamically_legal_op",
      (void*)::
          mlir_transforms_dialect_conversion_target_add_dynamically_legal_op);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_target_mark_unknown_ops_dynamically_"
      "legal",
      (void*)::
          mlir_transforms_dialect_conversion_target_mark_unknown_ops_dynamically_legal);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_type_converter_add_conversion",
      (void*)::
          mlir_transforms_dialect_conversion_type_converter_add_conversion);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_type_converter_is_legal_type",
      (void*)::mlir_transforms_dialect_conversion_type_converter_is_legal_type);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_type_converter_is_legal",
      (void*)::mlir_transforms_dialect_conversion_type_converter_is_legal);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_type_converter_is_signature_legal",
      (void*)::
          mlir_transforms_dialect_conversion_type_converter_is_signature_legal);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_pattern_set_create",
      (void*)::mlir_transforms_dialect_conversion_pattern_set_create);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_pattern_set_destroy",
      (void*)::mlir_transforms_dialect_conversion_pattern_set_destroy);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_apply_full_conversion",
      (void*)::mlir_transforms_dialect_conversion_apply_full_conversion);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_populate_func_type_conversion",
      (void*)::
          mlir_transforms_dialect_conversion_populate_func_type_conversion);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_type_converter_add_source_"
      "materialization",
      (void*)::
          mlir_transforms_dialect_conversion_type_converter_add_source_materialization);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_type_converter_add_target_"
      "materialization",
      (void*)::
          mlir_transforms_dialect_conversion_type_converter_add_target_materialization);

  // ── Backward-compat aliases (old names) ──────────────────────────────────
  Sregister_symbol(
      "mlir_register_conversion_pattern",
      (void*)::mlir_transforms_dialect_conversion_add_conversion_pattern);
  Sregister_symbol(
      "mlir_register_rewrite_pattern",
      (void*)::mlir_transforms_dialect_conversion_add_rewrite_pattern);
  Sregister_symbol(
      "mlir_create_type_converter",
      (void*)::mlir_transforms_dialect_conversion_type_converter_create);
  Sregister_symbol(
      "mlir_destroy_type_converter",
      (void*)::mlir_transforms_dialect_conversion_type_converter_destroy);
  Sregister_symbol("mlir_create_conversion_target",
                   (void*)::mlir_transforms_dialect_conversion_target_create);
  Sregister_symbol("mlir_destroy_conversion_target",
                   (void*)::mlir_transforms_dialect_conversion_target_destroy);
  Sregister_symbol(
      "mlir_conversion_target_add_illegal_dialect",
      (void*)::mlir_transforms_dialect_conversion_target_add_illegal_dialect);
  Sregister_symbol(
      "mlir_conversion_target_add_legal_dialect",
      (void*)::mlir_transforms_dialect_conversion_target_add_legal_dialect);
  Sregister_symbol(
      "mlir_conversion_target_add_legal_op",
      (void*)::mlir_transforms_dialect_conversion_target_add_legal_op);
  Sregister_symbol(
      "mlir_conversion_target_add_dynamically_legal_op",
      (void*)::
          mlir_transforms_dialect_conversion_target_add_dynamically_legal_op);
  Sregister_symbol(
      "mlir_conversion_target_mark_unknown_ops_dynamically_legal",
      (void*)::
          mlir_transforms_dialect_conversion_target_mark_unknown_ops_dynamically_legal);
  Sregister_symbol(
      "mlir_type_converter_add_conversion",
      (void*)::
          mlir_transforms_dialect_conversion_type_converter_add_conversion);
  Sregister_symbol(
      "mlir_type_converter_is_legal_type",
      (void*)::mlir_transforms_dialect_conversion_type_converter_is_legal_type);
  Sregister_symbol(
      "mlir_type_converter_is_legal",
      (void*)::mlir_transforms_dialect_conversion_type_converter_is_legal);
  Sregister_symbol(
      "mlir_type_converter_is_signature_legal",
      (void*)::
          mlir_transforms_dialect_conversion_type_converter_is_signature_legal);
  Sregister_symbol(
      "mlir_create_rewrite_pattern_set",
      (void*)::mlir_transforms_dialect_conversion_pattern_set_create);
  Sregister_symbol(
      "mlir_destroy_rewrite_pattern_set",
      (void*)::mlir_transforms_dialect_conversion_pattern_set_destroy);
  Sregister_symbol(
      "mlir_apply_full_conversion",
      (void*)::mlir_transforms_dialect_conversion_apply_full_conversion);
  Sregister_symbol(
      "mlir_populate_func_type_conversion_pattern",
      (void*)::
          mlir_transforms_dialect_conversion_populate_func_type_conversion);
}

} // namespace crest
