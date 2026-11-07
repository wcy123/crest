/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Dialect types defined in Scheme — lib/Crest/Type.cpp

#include "Type.h"
#include "../Bindings/Support/LockedSchemeObject.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/Diagnostics.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/Location.h"
#include <map>
#include <optional>
#include <string>
#include <tuple>

namespace crest {

namespace {

using Key = std::tuple<mlir::MLIRContext*, std::string, std::string>;

std::map<Key, mlir::DynamicTypeDefinition*>& registry() {
  static std::map<Key, mlir::DynamicTypeDefinition*> table;
  return table;
}

mlir::DynamicTypeDefinition* lookup(mlir::MLIRContext* ctx,
                                    const std::string& dialect,
                                    const std::string& name) {
  auto it = registry().find({ctx, dialect, name});
  return it == registry().end() ? nullptr : it->second;
}

// A Scheme list of attribute pointers.
ptr attributeList(llvm::ArrayRef<mlir::Attribute> attrs) {
  ptr list = Snil;
  for (auto it = attrs.rbegin(); it != attrs.rend(); ++it) {
    list =
        Scons(Sunsigned64(reinterpret_cast<uint64_t>(it->getAsOpaquePointer())),
              list);
  }
  return list;
}

std::optional<LockedSchemeObject> procedureOrNone(ptr slot, const char* what) {
  if (Sprocedurep(slot)) {
    return LockedSchemeObject(slot);
  }
  if (slot != Sfalse) {
    scheme_error("crest::register-dynamic-type!", what,
                 "must be a procedure or #f");
  }
  return std::nullopt;
}

} // namespace

void registerCrestDynamicTypeBindings() {
  // crest::register-dynamic-type! (uptr dialect) (string name) (scheme-object
  // vector/3) → void
  //
  // Must be called from the dialect's :initialize. Slots (#f = default):
  //   0 verify  (list-of-attributes) → #t | #f | error-message-string
  //   1 parse   (parser) → list-of-attributes | #f      (the text after the
  //   type name) 2 print   (printer list-of-attributes) → void      (the text
  //   after the type name)
  Sregister_symbol(
      "crest::register-dynamic-type!",
      (void*)+[](uint64_t dialect_ptr, const char* name, ptr cbs) -> void {
        auto* dialect = reinterpret_cast<mlir::ExtensibleDialect*>(dialect_ptr);
        auto verify = procedureOrNone(Svector_ref(cbs, 0), "the verify slot ");
        auto parse = procedureOrNone(Svector_ref(cbs, 1), "the parse slot ");
        auto print = procedureOrNone(Svector_ref(cbs, 2), "the print slot ");
        if (parse.has_value() != print.has_value()) {
          scheme_error("crest::register-dynamic-type!",
                       "a type needs both :parse and :print, or neither");
        }

        mlir::DynamicTypeDefinition::VerifierFn verifier =
            [verify = std::move(verify)](
                llvm::function_ref<mlir::InFlightDiagnostic()> emitError,
                llvm::ArrayRef<mlir::Attribute> params) -> mlir::LogicalResult {
          if (!verify) {
            return mlir::success();
          }
          LockedSchemeObject result(
              scheme_call(verify->get(), attributeList(params)));
          if (result.get() == Sfalse) {
            emitError() << "invalid type parameters";
            return mlir::failure();
          }
          if (Sstringp(result.get())) {
            std::string message;
            for (iptr i = 0; i < Sstring_length(result.get()); ++i) {
              message.push_back(
                  static_cast<char>(Sstring_ref(result.get(), i)));
            }
            emitError() << message;
            return mlir::failure();
          }
          return mlir::success();
        };

        std::unique_ptr<mlir::DynamicTypeDefinition> def;
        if (parse) {
          mlir::DynamicTypeDefinition::ParserFn parser =
              [parse = std::move(parse)](
                  mlir::AsmParser& p,
                  llvm::SmallVectorImpl<mlir::Attribute>& parsed)
              -> mlir::ParseResult {
            LockedSchemeObject result(scheme_call(parse->get(), &p));
            if (result.get() == Sfalse) {
              return mlir::failure();
            }
            for (ptr l = result.get(); Spairp(l); l = Scdr(l)) {
              parsed.push_back(mlir::Attribute::getFromOpaquePointer(
                  reinterpret_cast<const void*>(Sunsigned64_value(Scar(l)))));
            }
            return mlir::success();
          };
          mlir::DynamicTypeDefinition::PrinterFn printer =
              [print = std::move(print)](
                  mlir::AsmPrinter& p, llvm::ArrayRef<mlir::Attribute> params) {
                scheme_call(print->get(), &p, attributeList(params));
              };
          def = mlir::DynamicTypeDefinition::get(
              name, dialect, std::move(verifier), std::move(parser),
              std::move(printer));
        } else {
          def = mlir::DynamicTypeDefinition::get(name, dialect,
                                                 std::move(verifier));
        }
        registry()[{dialect->getContext(), dialect->getNamespace().str(),
                    name}] = def.get();
        dialect->registerDynamicType(std::move(def));
      });

  // crest::DynamicType::get (string dialect) (string name) (scheme-object
  // params) (uptr ctx) → uptr The type with these attribute parameters,
  // verified; 0 when verification fails.
  Sregister_symbol(
      "crest::DynamicType::get",
      (void*)+[](const char* dialect, const char* name, ptr params,
                 uint64_t ctx_ptr) -> uint64_t {
        auto* ctx = crest::as_ptr<mlir::MLIRContext>(ctx_ptr, __func__);
        auto* def = lookup(ctx, dialect, name);
        if (!def) {
          scheme_error("crest::DynamicType::get", "unknown type ", dialect, ".",
                       name);
        }
        llvm::SmallVector<mlir::Attribute> attrs;
        for (ptr l = params; Spairp(l); l = Scdr(l)) {
          attrs.push_back(mlir::Attribute::getFromOpaquePointer(
              reinterpret_cast<const void*>(Sunsigned64_value(Scar(l)))));
        }
        auto type = mlir::DynamicType::getChecked(
            [ctx]() { return mlir::emitError(mlir::UnknownLoc::get(ctx)); },
            def, attrs);
        return reinterpret_cast<uint64_t>(type.getAsOpaquePointer());
      });

  // crest::DynamicType::isa (string dialect) (string name) (uptr type) → int
  Sregister_symbol(
      "crest::DynamicType::isa",
      (void*)+[](const char* dialect, const char* name,
                 uint64_t type_ptr) -> int {
        if (!type_ptr) {
          return 0;
        }
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto dynamic = mlir::dyn_cast<mlir::DynamicType>(type);
        return dynamic && dynamic.getTypeDef() ==
                              lookup(type.getContext(), dialect, name)
                   ? 1
                   : 0;
      });

  // crest::DynamicType::getParams (uptr type) → list of attribute pointers
  Sregister_symbol(
      "crest::DynamicType::getParams", (void*)+[](uint64_t type_ptr) -> ptr {
        auto dynamic = mlir::dyn_cast_if_present<mlir::DynamicType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        if (!dynamic) {
          scheme_error("crest::DynamicType::getParams", "not a dynamic type");
        }
        return attributeList(dynamic.getParams());
      });
}

} // namespace crest
