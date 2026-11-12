/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

// Mirrors mlir/IR/Operation.h

#include "Operation.h"
#include "../Support/ArrayRef.h"
#include "../Support/Logging.h"
#include "../Support/Result.h"
#include "../Support/SchemeWrapper.h"
#include "llvm/Support/raw_ostream.h"
#include "mlir/CAPI/IR.h"
#include "mlir/CAPI/Wrap.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/Verifier.h"
#include <limits>

namespace crest {

void registerIROperationBindings() {
  register_binding("mlir::Operation::getName", [](uint64_t op) -> const char* {
    if (!op) {
      return "";
    }
    return reinterpret_cast<mlir::Operation*>(op)
        ->getName()
        .getStringRef()
        .data();
  });
  register_binding("mlir::Operation::getContext",
                   [](uint64_t op) -> llvm::Expected<uint64_t> {
                     if (!op) {
                       return fail("mlir::Operation::getContext",
                                   llvm::Twine("operation must not be null"));
                     }
                     return reinterpret_cast<uint64_t>(
                         reinterpret_cast<mlir::Operation*>(op)->getContext());
                   });
  register_binding(
      "mlir::Operation::getNumOperands",
      [](uint64_t op) -> llvm::Expected<int64_t> {
        if (!op) {
          return fail("mlir::Operation::getNumOperands",
                      llvm::Twine("operation must not be null"));
        }
        return reinterpret_cast<mlir::Operation*>(op)->getNumOperands();
      });
  register_binding(
      "mlir::Operation::getNumResults",
      [](uint64_t op) -> llvm::Expected<int64_t> {
        if (!op) {
          return fail("mlir::Operation::getNumResults",
                      llvm::Twine("operation must not be null"));
        }
        return reinterpret_cast<mlir::Operation*>(op)->getNumResults();
      });
  register_binding(
      "mlir::Operation::getOperand",
      [](uint64_t op, int64_t index) -> llvm::Expected<uint64_t> {
        if (!op) {
          return fail("mlir::Operation::getOperand",
                      llvm::Twine("operation must not be null"));
        }
        auto* cppOp = reinterpret_cast<mlir::Operation*>(op);
        if (index < 0 || index >= (int64_t)cppOp->getNumOperands()) {
          return fail("mlir::Operation::getOperand",
                      llvm::Twine("index out of range: ") + " " +
                          llvm::Twine(index) + " " + " (size " + " " +
                          llvm::Twine((int64_t)cppOp->getNumOperands()) + " " +
                          ")");
        }
        return reinterpret_cast<uint64_t>(
            cppOp->getOperand(static_cast<unsigned>(index))
                .getAsOpaquePointer());
      });
  register_binding(
      "mlir::Operation::getOpOperand",
      [](uint64_t op, int64_t index) -> llvm::Expected<uint64_t> {
        if (!op) {
          return fail("mlir::Operation::getOpOperand",
                      llvm::Twine("operation must not be null"));
        }
        mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
        if (index < 0 || index >= (int64_t)cppOp->getNumOperands()) {
          return fail("mlir::Operation::getOpOperand",
                      llvm::Twine("index out of range: ") + " " +
                          llvm::Twine(index) + " " + " (size " + " " +
                          llvm::Twine((int64_t)cppOp->getNumOperands()) + " " +
                          ")");
        }
        mlir::Value val = cppOp->getOperand(static_cast<unsigned>(index));
        MlirValue cVal = wrap(val);
        return reinterpret_cast<uint64_t>(const_cast<void*>(cVal.ptr));
      });
  register_binding(
      "mlir::Operation::getResult",
      [](uint64_t op, int64_t index) -> llvm::Expected<uint64_t> {
        if (!op) {
          return fail("mlir::Operation::getResult",
                      llvm::Twine("operation must not be null"));
        }
        mlir::Operation* cppOp = reinterpret_cast<mlir::Operation*>(op);
        if (index < 0 || index >= (int64_t)cppOp->getNumResults()) {
          return fail("mlir::Operation::getResult",
                      llvm::Twine("index out of range: ") + " " +
                          llvm::Twine(index) + " " + " (size " + " " +
                          llvm::Twine((int64_t)cppOp->getNumResults()) + " " +
                          ")");
        }
        mlir::Value val = cppOp->getResult(static_cast<unsigned>(index));
        MlirValue cVal = wrap(val);
        return reinterpret_cast<uint64_t>(const_cast<void*>(cVal.ptr));
      });
  register_binding(
      "mlir::Operation::getParentOp",
      [](uint64_t op_ptr) -> llvm::Expected<uint64_t> {
        if (!op_ptr) {
          return fail("mlir::Operation::getParentOp",
                      llvm::Twine("operation must not be null"));
        }
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::Operation*>(op_ptr)->getParentOp());
      });
  register_binding(
      "mlir::OpOperand::get",
      [](uint64_t op_ptr, int64_t index) -> llvm::Expected<uint64_t> {
        if (!op_ptr) {
          return fail("mlir::OpOperand::get",
                      llvm::Twine("operation must not be null"));
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        if (index < 0 || index >= (int64_t)op->getNumOperands()) {
          return fail("mlir::OpOperand::get",
                      llvm::Twine("index out of range: ") + " " +
                          llvm::Twine(index) + " " + " (size " + " " +
                          llvm::Twine((int64_t)op->getNumOperands()) + " " +
                          ")");
        }
        return reinterpret_cast<uint64_t>(const_cast<void*>(
            op->getOperand(static_cast<unsigned>(index)).getAsOpaquePointer()));
      });
  register_binding(
      "mlir::OpResult::getOwner",
      [](uint64_t op_ptr, int64_t index) -> llvm::Expected<uint64_t> {
        if (!op_ptr) {
          return fail("mlir::OpResult::getOwner",
                      llvm::Twine("operation must not be null"));
        }
        mlir::Operation* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        if (index < 0 || index >= (int64_t)op->getNumResults()) {
          return fail("mlir::OpResult::getOwner",
                      llvm::Twine("index out of range: ") + " " +
                          llvm::Twine(index) + " " + " (size " + " " +
                          llvm::Twine((int64_t)op->getNumResults()) + " " +
                          ")");
        }
        return reinterpret_cast<uint64_t>(const_cast<void*>(
            op->getResult(static_cast<unsigned>(index)).getAsOpaquePointer()));
      });
  register_binding("mlir::Operation::getLoc",
                   [](uint64_t op_ptr) -> llvm::Expected<uint64_t> {
                     if (!op_ptr) {
                       return fail("mlir::Operation::getLoc",
                                   llvm::Twine("operation must not be null"));
                     }
                     return reinterpret_cast<uint64_t>(const_cast<void*>(
                         reinterpret_cast<mlir::Operation*>(op_ptr)
                             ->getLoc()
                             .getAsOpaquePointer()));
                   });
  register_binding("mlir::Operation::walk",
                   [](uint64_t op, void (*visit)(uint64_t)) -> void {
                     // `visit` is a C function that Scheme made, and Scheme
                     // keeps it alive until the walk returns.
                     if (!op) {
                       return;
                     }
                     mlir::Operation* cppOp =
                         reinterpret_cast<mlir::Operation*>(op);
                     cppOp->walk([visit](mlir::Operation* walkOp) {
                       visit(reinterpret_cast<uint64_t>(walkOp));
                     });
                   });
  register_binding("mlir::Operation::setOperand",
                   [](uint64_t op_ptr, int index, uint64_t value) -> void {
                     if (!op_ptr || !value) {
                       return;
                     }
                     mlir::Operation* op =
                         reinterpret_cast<mlir::Operation*>(op_ptr);
                     mlir::Value val = unwrap(
                         MlirValue{reinterpret_cast<const void*>(value)});
                     op->setOperand(static_cast<unsigned>(index), val);
                   });
  register_binding("mlir::Operation::use_empty", [](uint64_t op_ptr) -> int {
    if (!op_ptr) {
      return 1;
    }
    return reinterpret_cast<mlir::Operation*>(op_ptr)->use_empty() ? 1 : 0;
  });
  register_binding("mlir::Operation::getAttrOfType<StringAttr>",
                   [](uint64_t op_ptr, const char* attr_name) -> const char* {
                     if (!op_ptr) {
                       return "";
                     }
                     auto attr =
                         reinterpret_cast<mlir::Operation*>(op_ptr)
                             ->getAttrOfType<mlir::StringAttr>(attr_name);
                     if (!attr) {
                       return "";
                     }
                     return attr.getValue().data();
                   });
  register_binding(
      "mlir::Operation::getAttrOfType<IntegerAttr>",
      [](uint64_t op_ptr, const char* attr_name,
         int64_t default_val) -> int64_t {
        if (!op_ptr) {
          return default_val;
        }
        if (auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                            ->getAttrOfType<mlir::IntegerAttr>(attr_name)) {
          return attr.getValue().getSExtValue();
        }
        return default_val;
      });
  register_binding(
      "mlir::Operation::hasAttr",
      [](uint64_t op_ptr, const char* attr_name) -> llvm::Expected<int> {
        if (!op_ptr) {
          return fail("mlir::Operation::hasAttr",
                      llvm::Twine("operation must not be null"));
        }
        return reinterpret_cast<mlir::Operation*>(op_ptr)->hasAttr(attr_name)
                   ? 1
                   : 0;
      });
  // mlir::verify: 1 when the operation and everything nested in it verifies,
  // else 0 (the diagnostics are emitted).
  register_binding(
      "mlir::Operation::verify", [](uint64_t op_ptr) -> llvm::Expected<int> {
        if (!op_ptr) {
          return fail("mlir::Operation::verify",
                      llvm::Twine("operation must not be null"));
        }
        return mlir::succeeded(
                   mlir::verify(reinterpret_cast<mlir::Operation*>(op_ptr)))
                   ? 1
                   : 0;
      });
  register_binding("mlir::Operation::emitError",
                   [](uint64_t op_ptr, const char* msg) -> void {
                     if (!op_ptr) {
                       mlir_support_logging_error(msg);
                       return;
                     }
                     reinterpret_cast<mlir::Operation*>(op_ptr)->emitError(msg);
                   });
  // mlir::Operation::emitOpError (uptr op, string message) -> void
  //
  // An error that names the op: "'dialect.op' op message".
  register_binding("mlir::Operation::emitOpError",
                   [](uint64_t op_ptr, const char* msg) -> void {
                     reinterpret_cast<mlir::Operation*>(op_ptr)->emitOpError(
                         msg);
                   });
  register_binding("mlir::Operation::emitWarning",
                   [](uint64_t op_ptr, const char* msg) -> void {
                     if (!op_ptr) {
                       mlir_support_logging_warning(msg);
                       return;
                     }
                     reinterpret_cast<mlir::Operation*>(op_ptr)->emitWarning(
                         msg);
                   });
  register_binding("mlir::Operation::emitRemark",
                   [](uint64_t op_ptr, const char* msg) -> void {
                     if (!op_ptr) {
                       mlir_support_logging_info(msg);
                       return;
                     }
                     reinterpret_cast<mlir::Operation*>(op_ptr)->emitRemark(
                         msg);
                   });
  register_binding("mlir::Operation::print", [](uint64_t op_ptr) -> ptr {
    if (!op_ptr) {
      return Sstring("");
    }
    std::string str;
    llvm::raw_string_ostream os(str);
    reinterpret_cast<mlir::Operation*>(op_ptr)->print(
        os, mlir::OpPrintingFlags().assumeVerified());
    return Sstring(str.c_str());
  });
  register_binding("mlir::Operation::erase", [](uint64_t op_ptr) -> void {
    if (!op_ptr) {
      return;
    }
    reinterpret_cast<mlir::Operation*>(op_ptr)->erase();
  });
  register_binding("mlir::Operation::getAttrDictionary",
                   [](uint64_t op_ptr) -> llvm::Expected<uint64_t> {
                     if (!op_ptr) {
                       return fail("mlir::Operation::getAttrDictionary",
                                   llvm::Twine("null op pointer"));
                     }
                     return reinterpret_cast<uint64_t>(
                         reinterpret_cast<mlir::Operation*>(op_ptr)
                             ->getAttrDictionary()
                             .getAsOpaquePointer());
                   });
  register_binding("mlir::Operation::setAttrs",
                   [](uint64_t op_ptr, uint64_t dict_ptr) -> llvm::Error {
                     if (!op_ptr) {
                       return fail("mlir::Operation::setAttrs",
                                   llvm::Twine("null op pointer"));
                     }
                     if (!dict_ptr) {
                       return fail("mlir::Operation::setAttrs",
                                   llvm::Twine("null dict pointer"));
                     }
                     reinterpret_cast<mlir::Operation*>(op_ptr)->setAttrs(
                         mlir::DictionaryAttr::getFromOpaquePointer(
                             reinterpret_cast<const void*>(dict_ptr)));
                     return llvm::Error::success();
                   });
  register_binding(
      "mlir::Operation::getRegion",
      [](uint64_t op_ptr, int region_idx) -> llvm::Expected<uint64_t> {
        if (!op_ptr) {
          return fail("mlir::Operation::getRegion",
                      llvm::Twine("operation must not be null"));
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        if (region_idx < 0 || region_idx >= (int)op->getNumRegions()) {
          return fail("mlir::Operation::getRegion",
                      llvm::Twine("index out of range: ") + " " +
                          llvm::Twine((int64_t)region_idx) + " " + " (size " +
                          " " + llvm::Twine((int64_t)op->getNumRegions()) +
                          " " + ")");
        }
        return reinterpret_cast<uint64_t>(
            &op->getRegion(static_cast<unsigned>(region_idx)));
      });
  register_binding(
      "mlir::Operation::getAttr",
      [](uint64_t op_ptr, const char* name) -> llvm::Expected<uint64_t> {
        if (!op_ptr) {
          return fail("mlir::Operation::getAttr",
                      llvm::Twine("operation must not be null"));
        }
        if (!name) {
          return fail("mlir::Operation::getAttr",
                      llvm::Twine("attribute name must not be null"));
        }
        auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
        auto attr = op->getAttr(name);
        return attr ? reinterpret_cast<uint64_t>(attr.getAsOpaquePointer()) : 0;
      });
  register_binding(
      "mlir::Operation::setAttr",
      [](uint64_t op_ptr, const char* name, uint64_t attr_ptr) -> void {
        if (!op_ptr || !attr_ptr) {
          return;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->setAttr(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
      });
  // Aliases with ? and ! suffix (Scheme predicate/mutator convention)
  register_binding("mlir::Operation::use_empty?", [](uint64_t op_ptr) -> int {
    if (!op_ptr) {
      return 1;
    }
    return reinterpret_cast<mlir::Operation*>(op_ptr)->use_empty() ? 1 : 0;
  });
  register_binding(
      "mlir::Operation::hasAttr?",
      [](uint64_t op_ptr, const char* attr_name) -> llvm::Expected<int> {
        if (!op_ptr) {
          return fail("mlir::Operation::hasAttr?",
                      llvm::Twine("operation must not be null"));
        }
        return reinterpret_cast<mlir::Operation*>(op_ptr)->hasAttr(attr_name)
                   ? 1
                   : 0;
      });
  register_binding(
      "mlir::Operation::setAttr!",
      [](uint64_t op_ptr, const char* name, uint64_t attr_ptr) -> void {
        if (!op_ptr || !attr_ptr) {
          return;
        }
        reinterpret_cast<mlir::Operation*>(op_ptr)->setAttr(
            name, mlir::Attribute::getFromOpaquePointer(
                      reinterpret_cast<const void*>(attr_ptr)));
      });
  // mlir::Operation::removeAttr (uptr op, string name) -> uptr
  //
  // Removes the attribute and answers it, or 0 when the op has none of that
  // name.
  register_binding(
      "mlir::Operation::removeAttr",
      [](uint64_t op_ptr, const char* name) -> uint64_t {
        if (!op_ptr || !name) {
          return 0;
        }
        mlir::Attribute removed =
            reinterpret_cast<mlir::Operation*>(op_ptr)->removeAttr(name);
        return reinterpret_cast<uint64_t>(removed.getAsOpaquePointer());
      });
  register_binding("mlir::Operation::emitError!",
                   [](uint64_t op_ptr, const char* msg) -> void {
                     if (!op_ptr) {
                       mlir_support_logging_error(msg);
                       return;
                     }
                     reinterpret_cast<mlir::Operation*>(op_ptr)->emitError(msg);
                   });
  register_binding("mlir::Operation::getAttrOfType<FloatAttr>",
                   [](uint64_t op_ptr, const char* name) -> double {
                     if (!op_ptr || !name) {
                       return std::numeric_limits<double>::quiet_NaN();
                     }
                     auto attr = reinterpret_cast<mlir::Operation*>(op_ptr)
                                     ->getAttrOfType<mlir::FloatAttr>(name);
                     return attr ? attr.getValueAsDouble()
                                 : std::numeric_limits<double>::quiet_NaN();
                   });

  register_binding("mlir::Operation::dump", [](uint64_t op_ptr) -> void {
    if (!op_ptr) {
      return;
    }
    reinterpret_cast<mlir::Operation*>(op_ptr)->dump();
  });

  register_binding("mlir::OperationName::getStringRef",
                   [](uint64_t op_name_ptr) -> const char* {
                     auto* name =
                         reinterpret_cast<mlir::OperationName*>(op_name_ptr);
                     return name->getStringRef().data();
                   });

  register_binding(
      "mlir::Operation::getBlock", [](uint64_t op_ptr) -> uint64_t {
        return reinterpret_cast<uint64_t>(
            reinterpret_cast<mlir::Operation*>(op_ptr)->getBlock());
      });

  register_binding("mlir::Operation::moveBefore",
                   [](uint64_t op_ptr, uint64_t other_ptr) -> void {
                     reinterpret_cast<mlir::Operation*>(op_ptr)->moveBefore(
                         reinterpret_cast<mlir::Operation*>(other_ptr));
                   });

  register_binding("mlir::Operation::setOperands",
                   [](uint64_t op_ptr, uint64_t arr_ptr) -> void {
                     auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
                     auto* arr =
                         reinterpret_cast<CArrayRef<uintptr_t>*>(arr_ptr);
                     llvm::SmallVector<mlir::Value> values;
                     values.reserve(arr->size);
                     for (size_t i = 0; i < arr->size; ++i) {
                       values.push_back(mlir::Value::getFromOpaquePointer(
                           reinterpret_cast<const void*>(arr->data[i])));
                     }
                     op->setOperands(values);
                   });

  // mlir::Operation::getParentOfType<ModuleOp>: get enclosing module.
  // (op-ptr) → Operation* uptr (or 0)
  register_binding("mlir::Operation::getParentOfType<ModuleOp>",
                   [](uint64_t op_ptr) -> uint64_t {
                     auto* op = reinterpret_cast<mlir::Operation*>(op_ptr);
                     auto parent = op->getParentOfType<mlir::ModuleOp>();
                     if (!parent) {
                       return 0;
                     }
                     return reinterpret_cast<uint64_t>(parent.getOperation());
                   });
}

} // namespace crest
