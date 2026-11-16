/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
//===- QAddFusion.cpp - the qadd fusion of samples/passes/hip-fusion/qadd.sls
//------===//
//
// The same fusion as the Scheme pattern, written the way a C++ pass would:
//
//   hip.dequantize_linear x2 -> hip.add -> hip.quantize_linear  ==>  hip.qadd
//
// It makes the baseline of the benchmarks: the checks, the attributes and the
// ops it makes are those of qadd.sls, and the two outputs must be equal (the
// benchmark compares them). The tool is built like mlir-opt, so parsing,
// printing and the greedy driver are the same code for both sides.
//
// What it does NOT have, because it is C++ and not the Scheme DSL: no
// diagnostics for a pattern that raises, and every op takes the location of
// the root op, not of a line of a pattern file.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/Tensor/IR/Tensor.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/OperationSupport.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Tools/mlir-opt/MlirOptMain.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"

#include <array>

namespace {

// The five operand groups of hip.dequantize_linear and hip.quantize_linear:
// (%ctx %x %scale (:optional %zero_point) %init). operandSegmentSizes says
// which are present. Answers false when the op has no such attribute or a group
// is not one operand (the zero point may be none).
bool operandGroups(mlir::Operation* op, std::array<mlir::Value, 5>& groups) {
  auto sizes =
      op->getAttrOfType<mlir::DenseI32ArrayAttr>("operandSegmentSizes");
  if (!sizes || sizes.size() != 5) {
    return false;
  }
  unsigned next = 0;
  for (unsigned i = 0; i < 5; ++i) {
    int32_t size = sizes[i];
    if (size == 0 && i == 3) {
      groups[i] = mlir::Value();
      continue;
    }
    if (size != 1 || next >= op->getNumOperands()) {
      return false;
    }
    groups[i] = op->getOperand(next++);
  }
  return true;
}

// A hip.constant of one result.
mlir::Operation* constantOf(mlir::Value value) {
  mlir::Operation* op = value.getDefiningOp();
  if (!op || op->getName().getStringRef() != "hip.constant" ||
      op->getNumResults() != 1) {
    return nullptr;
  }
  return op;
}

mlir::DenseElementsAttr splatValueOf(mlir::Operation* op) {
  auto attr = op->getAttrOfType<mlir::DenseElementsAttr>("value");
  return attr && attr.isSplat() ? attr : mlir::DenseElementsAttr();
}

// The scale of a dequantize or quantize: a splat hip.constant.
mlir::FloatAttr scaleAttr(mlir::Value value, mlir::MLIRContext* context) {
  mlir::Operation* constant = value ? constantOf(value) : nullptr;
  mlir::DenseElementsAttr splat = constant ? splatValueOf(constant) : nullptr;
  if (!splat) {
    return nullptr;
  }
  return mlir::FloatAttr::get(
      mlir::Float32Type::get(context),
      splat.getSplatValue<llvm::APFloat>().convertToDouble());
}

// The zero point: absent is 0, present is the splat integer of its constant.
// Answers false when it is present and not a splat constant.
bool zeroPointAttr(mlir::Value value, mlir::MLIRContext* context,
                   mlir::IntegerAttr& result) {
  int64_t number = 0;
  if (value) {
    mlir::Operation* defining = value.getDefiningOp();
    auto attr = defining
                    ? defining->getAttrOfType<mlir::DenseElementsAttr>("value")
                    : mlir::DenseElementsAttr();
    if (!attr || !attr.isSplat()) {
      return false;
    }
    number = attr.getSplatValue<llvm::APInt>().getSExtValue();
  }
  result = mlir::IntegerAttr::get(mlir::IntegerType::get(context, 64), number);
  return true;
}

struct QAddFusion : public mlir::RewritePattern {
  explicit QAddFusion(mlir::MLIRContext* context)
      : RewritePattern("hip.quantize_linear", /*benefit=*/10, context) {}

  mlir::LogicalResult
  matchAndRewrite(mlir::Operation* quantize,
                  mlir::PatternRewriter& rewriter) const override {
    mlir::MLIRContext* context = quantize->getContext();
    if (quantize->getNumResults() != 1) {
      return mlir::failure();
    }

    // hip.quantize_linear (%ctx %sum %out_scale (:optional %out_zp) %q_init)
    std::array<mlir::Value, 5> q;
    if (!operandGroups(quantize, q)) {
      return mlir::failure();
    }
    mlir::Value sum = q[1];

    // hip.add (%ctx %dq_lhs %dq_rhs %sum_init), one use, same rank as the
    // result
    mlir::Operation* add = sum.getDefiningOp();
    if (!add || add->getName().getStringRef() != "hip.add" ||
        add->getNumResults() != 1 || add->getNumOperands() < 4) {
      return mlir::failure();
    }
    if (!sum.hasOneUse()) {
      return mlir::failure();
    }
    auto resultType = mlir::dyn_cast<mlir::RankedTensorType>(
        quantize->getResult(0).getType());
    auto sumInitType =
        mlir::dyn_cast<mlir::RankedTensorType>(add->getOperand(3).getType());
    if (!resultType || !sumInitType ||
        resultType.getRank() != sumInitType.getRank()) {
      return mlir::failure();
    }

    // hip.dequantize_linear (%ctx %x %scale (:optional %zp) %init), twice
    std::array<mlir::Value, 5> dequantize[2];
    for (unsigned side = 0; side < 2; ++side) {
      mlir::Operation* op = add->getOperand(1 + side).getDefiningOp();
      if (!op || op->getName().getStringRef() != "hip.dequantize_linear" ||
          op->getNumResults() != 1 || !operandGroups(op, dequantize[side])) {
        return mlir::failure();
      }
    }

    // The scales are splat hip.constant ops; one %ctx for all four ops.
    mlir::Value context0 = q[0];
    if (add->getOperand(0) != context0 || dequantize[0][0] != context0 ||
        dequantize[1][0] != context0) {
      return mlir::failure();
    }
    for (mlir::Value scale : {dequantize[0][2], dequantize[1][2], q[2]}) {
      mlir::Operation* constant = constantOf(scale);
      if (!constant || !splatValueOf(constant)) {
        return mlir::failure();
      }
    }

    // The values for the new op, read before the IR changes.
    mlir::FloatAttr lhsScale = scaleAttr(dequantize[0][2], context);
    mlir::FloatAttr rhsScale = scaleAttr(dequantize[1][2], context);
    mlir::FloatAttr outScale = scaleAttr(q[2], context);
    mlir::IntegerAttr lhsZp, rhsZp, outZp;
    if (!zeroPointAttr(dequantize[0][3], context, lhsZp) ||
        !zeroPointAttr(dequantize[1][3], context, rhsZp) ||
        !zeroPointAttr(q[3], context, outZp)) {
      return mlir::failure();
    }
    if (!resultType.hasStaticShape()) {
      return mlir::failure();
    }

    rewriter.setInsertionPoint(quantize);
    mlir::Location location = quantize->getLoc();
    mlir::Value init = mlir::tensor::EmptyOp::create(
        rewriter, location, resultType.getShape(), resultType.getElementType());

    mlir::OperationState state(location, "hip.qadd");
    state.addOperands({context0, dequantize[0][1], dequantize[1][1], init});
    state.addTypes(resultType);
    state.addAttribute("lhs_scale", lhsScale);
    state.addAttribute("lhs_zp", lhsZp);
    state.addAttribute("rhs_scale", rhsScale);
    state.addAttribute("rhs_zp", rhsZp);
    state.addAttribute("output_scale", outScale);
    state.addAttribute("output_zp", outZp);
    mlir::Operation* qadd = rewriter.create(state);

    rewriter.replaceOp(quantize, qadd->getResults());
    return mlir::success();
  }
};

struct QAddFusionPass
    : public mlir::PassWrapper<QAddFusionPass,
                               mlir::OperationPass<mlir::ModuleOp>> {
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(QAddFusionPass)

  llvm::StringRef getArgument() const override { return "bench-qadd-fusion"; }
  llvm::StringRef getDescription() const override {
    return "The qadd fusion of samples/passes/hip-fusion/qadd.sls, in C++";
  }

  void getDependentDialects(mlir::DialectRegistry& registry) const override {
    registry.insert<mlir::tensor::TensorDialect>();
  }

  void runOnOperation() override {
    mlir::RewritePatternSet patterns(&getContext());
    patterns.add<QAddFusion>(&getContext());
    if (mlir::failed(
            mlir::applyPatternsGreedily(getOperation(), std::move(patterns)))) {
      signalPassFailure();
    }
  }
};

} // namespace

int main(int argc, char** argv) {
  mlir::DialectRegistry registry;
  registry.insert<mlir::func::FuncDialect, mlir::tensor::TensorDialect>();
  mlir::PassRegistration<QAddFusionPass>();
  return mlir::asMainReturnCode(
      mlir::MlirOptMain(argc, argv, "CREST benchmark baseline\n", registry));
}
