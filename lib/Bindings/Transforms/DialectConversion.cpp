/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "mlir/Transforms/DialectConversion.h"
#include "../Support/LockedSchemeObject.h"
#include "../Support/Logging.h"
#include "../Support/SchemeWrapper.h"
#include "llvm/Support/raw_ostream.h"
#include "mlir/CAPI/IR.h"
#include "mlir/CAPI/Wrap.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/Tensor/IR/Tensor.h"
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
    ptr apply_proc = Stop_level_value(Sstring_to_symbol("apply"));
    ptr result = Scall2(apply_proc, callback_.get(), args_list);
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
    ptr apply_proc = Stop_level_value(Sstring_to_symbol("apply"));
    ptr result = Scall2(apply_proc, callback_.get(), args_list);
    return result == Strue ? mlir::success() : mlir::failure();
  }

private:
  crest::LockedSchemeObject callback_;
  std::string targetOpName;
};

extern "C" {

void mlir_transforms_dialect_conversion_add_conversion_pattern(
    ptr patterns_ptr, const char* op_name, ptr callback, ptr type_converter_ptr,
    int benefit) {
  auto* patterns = reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
  auto* typeConverter =
      reinterpret_cast<mlir::TypeConverter*>(type_converter_ptr);
  mlir_log_info(
      (std::string("Registering Scheme pattern for ") + op_name).c_str());
  patterns->add<SchemeConversionPattern>(typeConverter, patterns->getContext(),
                                         static_cast<ptr>(callback),
                                         llvm::StringRef(op_name), benefit);
}

void mlir_transforms_dialect_conversion_add_rewrite_pattern(ptr patterns_ptr,
                                                            const char* op_name,
                                                            ptr callback,
                                                            int benefit) {
  auto* patterns = reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
  crest::LockedSchemeObject lockedCallback(callback);
  mlir_log_info(
      (std::string("Registering Scheme rewrite pattern for ") + op_name)
          .c_str());
  patterns->add<SchemeRewritePattern>(patterns->getContext(),
                                      std::move(lockedCallback),
                                      llvm::StringRef(op_name), benefit);
}

uint64_t mlir_transforms_dialect_conversion_type_converter_create() {
  return reinterpret_cast<uint64_t>(new mlir::TypeConverter());
}

void mlir_transforms_dialect_conversion_type_converter_destroy(
    uint64_t converter_ptr) {
  if (!converter_ptr) {
    return;
  }
  delete reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
}

uint64_t mlir_transforms_dialect_conversion_target_create(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    return 0;
  }
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(new mlir::ConversionTarget(*ctx));
}

void mlir_transforms_dialect_conversion_target_destroy(uint64_t target_ptr) {
  if (!target_ptr) {
    return;
  }
  delete reinterpret_cast<mlir::ConversionTarget*>(target_ptr);
}

void mlir_transforms_dialect_conversion_target_add_illegal_dialect(
    uint64_t target_ptr, const char* dialect_name) {
  if (!target_ptr || !dialect_name) {
    return;
  }
  reinterpret_cast<mlir::ConversionTarget*>(target_ptr)
      ->addIllegalDialect(dialect_name);
}

void mlir_transforms_dialect_conversion_target_add_legal_dialect(
    uint64_t target_ptr, const char* dialect_name) {
  if (!target_ptr || !dialect_name) {
    return;
  }
  reinterpret_cast<mlir::ConversionTarget*>(target_ptr)
      ->addLegalDialect(dialect_name);
}

void mlir_transforms_dialect_conversion_target_add_legal_op(
    uint64_t target_ptr, uint64_t ctx_ptr, const char* op_name) {
  if (!target_ptr || !ctx_ptr || !op_name) {
    return;
  }
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  reinterpret_cast<mlir::ConversionTarget*>(target_ptr)
      ->addLegalOp(mlir::OperationName(op_name, ctx));
}

void mlir_transforms_dialect_conversion_target_add_dynamically_legal_op(
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

void mlir_transforms_dialect_conversion_target_mark_unknown_ops_dynamically_legal(
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
void mlir_transforms_dialect_conversion_type_converter_add_conversion(
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

int mlir_transforms_dialect_conversion_type_converter_is_legal_type(
    uint64_t converter_ptr, uint64_t type_ptr) {
  if (!converter_ptr || !type_ptr) {
    return 0;
  }
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  mlir::Type type =
      mlir::Type::getFromOpaquePointer(reinterpret_cast<const void*>(type_ptr));
  return converter->isLegal(type) ? 1 : 0;
}

int mlir_transforms_dialect_conversion_type_converter_is_legal(
    uint64_t converter_ptr, uint64_t op_ptr) {
  if (!converter_ptr || !op_ptr) {
    return 0;
  }
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
  return converter->isLegal(op) ? 1 : 0;
}

int mlir_transforms_dialect_conversion_type_converter_is_signature_legal(
    uint64_t converter_ptr, uint64_t func_op_ptr) {
  if (!converter_ptr || !func_op_ptr) {
    return 0;
  }
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  auto func_op = mlir::dyn_cast<mlir::func::FuncOp>(
      reinterpret_cast<mlir::Operation*>(func_op_ptr));
  if (!func_op) {
    return 0;
  }
  return converter->isSignatureLegal(func_op.getFunctionType()) ? 1 : 0;
}

// Mark ModuleOp and arith.constant legal — present in every module and
// typically not subject to conversion.
void mlir_transforms_dialect_conversion_target_add_legal_common_ops(
    uint64_t target_ptr) {
  if (!target_ptr) {
    return;
  }
  auto* target = reinterpret_cast<mlir::ConversionTarget*>(target_ptr);
  target->addLegalOp<mlir::ModuleOp>();
  target->addLegalOp<mlir::arith::ConstantOp>();
}

// Mark func.func and func.return dynamically legal per the TypeConverter.
void mlir_transforms_dialect_conversion_target_add_dynamically_legal_func(
    uint64_t target_ptr, uint64_t converter_ptr) {
  if (!target_ptr || !converter_ptr) {
    return;
  }
  auto* target = reinterpret_cast<mlir::ConversionTarget*>(target_ptr);
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  target->addDynamicallyLegalOp<mlir::func::FuncOp>(
      [converter](mlir::func::FuncOp op) {
        return converter->isSignatureLegal(op.getFunctionType());
      });
  target->addDynamicallyLegalOp<mlir::func::ReturnOp>(
      [converter](mlir::func::ReturnOp op) { return converter->isLegal(op); });
}

uint64_t
mlir_transforms_dialect_conversion_pattern_set_create(uint64_t ctx_ptr) {
  if (!ctx_ptr) {
    return 0;
  }
  auto* ctx = reinterpret_cast<mlir::MLIRContext*>(ctx_ptr);
  return reinterpret_cast<uint64_t>(new mlir::RewritePatternSet(ctx));
}

void mlir_transforms_dialect_conversion_pattern_set_destroy(
    uint64_t patterns_ptr) {
  if (!patterns_ptr) {
    return;
  }
  delete reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
}

// Returns 1 on success, 0 on failure. Takes ownership of patterns.
int mlir_transforms_dialect_conversion_apply_full_conversion(
    uint64_t module_ptr, uint64_t target_ptr, uint64_t patterns_ptr) {
  if (!module_ptr || !target_ptr || !patterns_ptr) {
    return 0;
  }
  auto module = mlir::dyn_cast<mlir::ModuleOp>(
      reinterpret_cast<mlir::Operation*>(module_ptr));
  if (!module) {
    return 0;
  }
  auto* target = reinterpret_cast<mlir::ConversionTarget*>(target_ptr);
  auto* patterns = reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
  return mlir::succeeded(
      mlir::applyFullConversion(module, *target, std::move(*patterns)));
}

void mlir_transforms_dialect_conversion_populate_func_type_conversion(
    uint64_t patterns_ptr, uint64_t converter_ptr) {
  if (!patterns_ptr || !converter_ptr) {
    return;
  }
  auto* patterns = reinterpret_cast<mlir::RewritePatternSet*>(patterns_ptr);
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  mlir::populateFunctionOpInterfaceTypeConversionPattern<mlir::func::FuncOp>(
      *patterns, *converter);
}

// Insert tensor.cast to resolve unrealized_conversion_cast between compatible
// ranked tensor types (e.g. tensor<?x32xf16,dev> → tensor<?x?xf16,dev>).
// Required when a conversion pattern produces a more specific type than the
// TypeConverter declares for the result.
void mlir_transforms_dialect_conversion_type_converter_add_tensor_widening_materialization(
    uint64_t converter_ptr) {
  if (!converter_ptr) {
    return;
  }
  auto* converter = reinterpret_cast<mlir::TypeConverter*>(converter_ptr);
  auto materialize = [](mlir::OpBuilder& builder, mlir::Type resultType,
                        mlir::ValueRange inputs,
                        mlir::Location loc) -> mlir::Value {
    if (inputs.size() != 1) {
      return nullptr;
    }
    auto inputType =
        mlir::dyn_cast<mlir::RankedTensorType>(inputs[0].getType());
    auto outType = mlir::dyn_cast<mlir::RankedTensorType>(resultType);
    if (!inputType || !outType ||
        !mlir::tensor::CastOp::areCastCompatible(inputType, outType)) {
      return nullptr;
    }
    return mlir::tensor::CastOp::create(builder, loc, resultType, inputs[0]);
  };
  converter->addSourceMaterialization(materialize);
  converter->addTargetMaterialization(materialize);
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
      "mlir_transforms_dialect_conversion_type_converter_add_tensor_widening_"
      "materialization",
      (void*)::
          mlir_transforms_dialect_conversion_type_converter_add_tensor_widening_materialization);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_target_add_legal_common_ops",
      (void*)::mlir_transforms_dialect_conversion_target_add_legal_common_ops);
  Sregister_symbol(
      "mlir_transforms_dialect_conversion_target_add_dynamically_legal_func",
      (void*)::
          mlir_transforms_dialect_conversion_target_add_dynamically_legal_func);

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
  Sregister_symbol(
      "mlir_type_converter_add_tensor_widening_materialization",
      (void*)::
          mlir_transforms_dialect_conversion_type_converter_add_tensor_widening_materialization);
  Sregister_symbol(
      "mlir_conversion_target_add_legal_common_ops",
      (void*)::mlir_transforms_dialect_conversion_target_add_legal_common_ops);
  Sregister_symbol(
      "mlir_conversion_target_add_dynamically_legal_func",
      (void*)::
          mlir_transforms_dialect_conversion_target_add_dynamically_legal_func);
}

} // namespace crest
