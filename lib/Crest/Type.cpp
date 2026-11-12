/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Dialect types defined in Scheme — lib/Crest/Type.cpp

#include "Type.h"
#include "../Bindings/Support/Result.h"
#include "../Bindings/Support/SchemeWrapper.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/Diagnostics.h"
#include "mlir/IR/ExtensibleDialect.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/OpImplementation.h"
#include <string>

namespace crest {

namespace {

// The definition of a dynamic type, found in the dialect that registered it.
// The dialect keeps its definitions as long as its context lives. (A global map
// from (context, dialect, name) to the definition used to be kept here: its
// entries were never removed, so it grew with every context that loaded a
// dialect, and its keys outlived their contexts.)
mlir::DynamicTypeDefinition* lookup(mlir::MLIRContext* ctx,
                                    const std::string& dialect,
                                    const std::string& name) {
  mlir::Dialect* loaded = ctx->getLoadedDialect(dialect);
  auto* extensible =
      loaded ? mlir::dyn_cast<mlir::ExtensibleDialect>(loaded) : nullptr;
  return extensible ? extensible->lookupTypeDefinition(name) : nullptr;
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

// What the callables of a type's verifier and parser fill in: the attributes
// that a parser produced (crest::DynamicType::addParam) and the message of a
// failure (crest::DynamicType::setMessage).
struct TypeSink {
  llvm::SmallVectorImpl<mlir::Attribute>* parsed = nullptr;
  std::string message;
};

// The attribute parameters as the array of opaque pointers that Scheme reads.
llvm::SmallVector<const void*, 4>
opaquePointers(llvm::ArrayRef<mlir::Attribute> attrs) {
  llvm::SmallVector<const void*, 4> pointers;
  for (mlir::Attribute attr : attrs) {
    pointers.push_back(attr.getAsOpaquePointer());
  }
  return pointers;
}

} // namespace

void registerCrestDynamicTypeBindings() {
  // crest::DynamicType::addParam (uptr sink) (uptr attribute)
  // crest::DynamicType::setMessage (uptr sink) (string message)
  //
  // The callables of a type give their answers to the `sink` that C++ passed.
  Sregister_symbol(
      "crest::DynamicType::addParam",
      (void*)+[](uint64_t sink, uint64_t attribute) -> ptr {
        reinterpret_cast<TypeSink*>(sink)->parsed->push_back(
            mlir::Attribute::getFromOpaquePointer(
                reinterpret_cast<const void*>(attribute)));
        return Svoid;
      });
  Sregister_symbol(
      "crest::DynamicType::setMessage",
      (void*)+[](uint64_t sink, const char* message) -> ptr {
        reinterpret_cast<TypeSink*>(sink)->message = message;
        return Svoid;
      });

  // crest::register-dynamic-type! (uptr dialect) (string name) (scheme-object
  // vector/3) → void
  //
  // Must be called from the dialect's :initialize. The vector is made once by
  // define-dialect ((crest dialect callbacks)). Slots (0 = default; the others
  // are the entry point of a foreign-callable, which answers a Scheme object:
  // what is written below as int or void, or the pair (who . why) when its
  // Scheme procedure raised an error, which is reported as a diagnostic):
  //   0 verify  (uptr params, uptr n, uptr sink) → int
  //             1 ok, 0 invalid (MLIR's message), 2 invalid, message in the
  //             sink
  //   1 parse   (uptr parser, uptr sink) → int      (the text after the type
  //             name) 1 ok with the parameters in the sink, 0 failed, 2 failed
  //             with the message in the sink
  //   2 print   (uptr printer, uptr params, uptr n) → void   (the text after
  //             the type name)
  Sregister_symbol(
      "crest::register-dynamic-type!",
      (void*)+[](uint64_t dialect_ptr, const char* name, ptr cbs) -> ptr {
        auto* dialect = reinterpret_cast<mlir::ExtensibleDialect*>(dialect_ptr);
        for (int slot = 0; slot < 3; ++slot) {
          ptr value = Svector_ref(cbs, slot);
          if (!Sfixnump(value) && !Sbignump(value)) {
            return scheme_error(
                "crest::register-dynamic-type!",
                "callback slot must be the entry point of a callable "
                "or 0");
          }
        }
        auto entry = [&](int slot) -> uint64_t {
          return static_cast<uint64_t>(
              Sinteger64_value(Svector_ref(cbs, slot)));
        };
        // Each callable answers a Scheme object: the number above, or the pair
        // (who . why) when its Scheme procedure raised an error.
        using VerifyFn = ptr (*)(const void* const*, uint64_t, uint64_t);
        using ParseFn = ptr (*)(uint64_t, uint64_t);
        using PrintFn = ptr (*)(uint64_t, const void* const*, uint64_t);
        auto verify = reinterpret_cast<VerifyFn>(entry(0));
        auto parse = reinterpret_cast<ParseFn>(entry(1));
        auto print = reinterpret_cast<PrintFn>(entry(2));
        if ((parse != nullptr) != (print != nullptr)) {
          return scheme_error(
              "crest::register-dynamic-type!",
              "a type needs both :parse and :print, or neither");
        }

        mlir::DynamicTypeDefinition::VerifierFn verifier =
            [verify](
                llvm::function_ref<mlir::InFlightDiagnostic()> emitError,
                llvm::ArrayRef<mlir::Attribute> params) -> mlir::LogicalResult {
          if (!verify) {
            return mlir::success();
          }
          auto pointers = opaquePointers(params);
          TypeSink sink;
          ptr scheme_answer =
              verify(pointers.data(), static_cast<uint64_t>(pointers.size()),
                     reinterpret_cast<uint64_t>(&sink));
          if (isSchemeError(scheme_answer)) {
            emitError() << schemeErrorText(scheme_answer);
            return mlir::failure();
          }
          int answer = static_cast<int>(Sinteger64_value(scheme_answer));
          if (answer == 1) {
            return mlir::success();
          }
          if (answer == 2) {
            emitError() << sink.message;
          } else {
            emitError() << "invalid type parameters";
          }
          return mlir::failure();
        };

        std::unique_ptr<mlir::DynamicTypeDefinition> def;
        if (parse) {
          mlir::DynamicTypeDefinition::ParserFn parser =
              [parse](mlir::AsmParser& p,
                      llvm::SmallVectorImpl<mlir::Attribute>& parsed)
              -> mlir::ParseResult {
            TypeSink sink;
            sink.parsed = &parsed;
            ptr scheme_answer = parse(reinterpret_cast<uint64_t>(&p),
                                      reinterpret_cast<uint64_t>(&sink));
            if (isSchemeError(scheme_answer)) {
              mlir::InFlightDiagnostic diagnostic =
                  p.emitError(p.getCurrentLocation());
              diagnostic << schemeErrorText(scheme_answer);
              return mlir::failure();
            }
            int answer = static_cast<int>(Sinteger64_value(scheme_answer));
            if (answer == 1) {
              return mlir::success();
            }
            if (answer == 2) {
              mlir::InFlightDiagnostic diagnostic =
                  p.emitError(p.getCurrentLocation());
              diagnostic << sink.message;
            }
            return mlir::failure();
          };
          mlir::DynamicTypeDefinition::PrinterFn printer =
              [print, dialect](mlir::AsmPrinter& p,
                               llvm::ArrayRef<mlir::Attribute> params) {
                auto pointers = opaquePointers(params);
                ptr answer =
                    print(reinterpret_cast<uint64_t>(&p), pointers.data(),
                          static_cast<uint64_t>(pointers.size()));
                if (isSchemeError(answer)) {
                  emitSchemeError(mlir::UnknownLoc::get(dialect->getContext()),
                                  answer);
                }
              };
          def = mlir::DynamicTypeDefinition::get(
              name, dialect, std::move(verifier), std::move(parser),
              std::move(printer));
        } else {
          def = mlir::DynamicTypeDefinition::get(name, dialect,
                                                 std::move(verifier));
        }
        dialect->registerDynamicType(std::move(def));
        return Svoid;
      });

  // crest::DynamicType::get (string dialect) (string name) (scheme-object
  // params) (uptr ctx) → uptr The type with these attribute parameters,
  // verified; 0 when verification fails.
  Sregister_symbol(
      "crest::DynamicType::get",
      (void*)+[](const char* dialect, const char* name, ptr params,
                 uint64_t ctx_ptr) -> ptr {
        auto* ctx = crest::as_context(ctx_ptr);
        if (!ctx) {
          return scheme_error("crest::DynamicType::get",
                              "null MLIRContext pointer");
        }
        auto* def = lookup(ctx, dialect, name);
        if (!def) {
          return scheme_error("crest::DynamicType::get",
                              llvm::Twine("unknown type ") + " " +
                                  llvm::Twine(dialect) + " " + "." + " " +
                                  llvm::Twine(name));
        }
        llvm::SmallVector<mlir::Attribute> attrs;
        for (ptr l = params; Spairp(l); l = Scdr(l)) {
          attrs.push_back(mlir::Attribute::getFromOpaquePointer(
              reinterpret_cast<const void*>(Sunsigned64_value(Scar(l)))));
        }
        auto type = mlir::DynamicType::getChecked(
            [ctx]() { return mlir::emitError(mlir::UnknownLoc::get(ctx)); },
            def, attrs);
        return Sunsigned64(
            reinterpret_cast<uint64_t>(type.getAsOpaquePointer()));
      });

  // crest::DynamicType::isa (string dialect) (string name) (uptr type) → int
  Sregister_symbol(
      "crest::DynamicType::isa",
      (void*)+[](const char* dialect, const char* name,
                 uint64_t type_ptr) -> ptr {
        if (!type_ptr) {
          return Sinteger64(0);
        }
        auto type = mlir::Type::getFromOpaquePointer(
            reinterpret_cast<const void*>(type_ptr));
        auto dynamic = mlir::dyn_cast<mlir::DynamicType>(type);
        return Sinteger64(dynamic &&
                                  dynamic.getTypeDef() ==
                                      lookup(type.getContext(), dialect, name)
                              ? 1
                              : 0);
      });

  // crest::DynamicType::getParams (uptr type) → list of attribute pointers
  Sregister_symbol(
      "crest::DynamicType::getParams", (void*)+[](uint64_t type_ptr) -> ptr {
        auto dynamic = mlir::dyn_cast_if_present<mlir::DynamicType>(
            mlir::Type::getFromOpaquePointer(
                reinterpret_cast<const void*>(type_ptr)));
        if (!dynamic) {
          return scheme_error("crest::DynamicType::getParams",
                              "not a dynamic type");
        }
        return attributeList(dynamic.getParams());
      });
}

} // namespace crest
