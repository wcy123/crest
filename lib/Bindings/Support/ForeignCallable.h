/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_BINDINGS_FOREIGN_CALLABLE_H
#define CREST_BINDINGS_FOREIGN_CALLABLE_H

#include "LockedSchemeObject.h"
#include "SchemeWrapper.h"
#include <cstddef>
#include <cstdint>
#include <string>
#include <utility>

namespace crest {

namespace detail {

/// The name that a foreign-callable gives a C++ type in its prototype.
template <typename T> struct ForeignTypeName;
#define CREST_FOREIGN_TYPE_NAME(Type, Name)                                    \
  template <> struct ForeignTypeName<Type> {                                   \
    static constexpr const char* value = Name;                                 \
  };
CREST_FOREIGN_TYPE_NAME(uint64_t, "uptr")
CREST_FOREIGN_TYPE_NAME(int, "int")
CREST_FOREIGN_TYPE_NAME(unsigned, "unsigned-32")
CREST_FOREIGN_TYPE_NAME(uint8_t, "unsigned-8")
CREST_FOREIGN_TYPE_NAME(void, "void")
#undef CREST_FOREIGN_TYPE_NAME

/// A pointer crosses as the number that is its address.
template <typename T> struct ForeignTypeName<T*> {
  static constexpr const char* value = "uptr";
};

/// The prototype of a foreign-callable as Scheme writes it, "(uptr int) void".
template <typename R, typename... Args> std::string foreignSignature() {
  std::string signature = "(";
  const char* separator = "";
  ((signature += separator, signature += ForeignTypeName<Args>::value,
    separator = " "),
   ...);
  signature += ") ";
  signature += ForeignTypeName<R>::value;
  return signature;
}

/// The Scheme procedure that makes the callables of one prototype: (lambda
/// (procedure) ...) answers the entry point of a foreign-callable of the
/// procedure, with its code object locked. It is compiled the first time the
/// prototype is used and kept, locked, for the life of the process.
ptr foreignCallableMaker(const std::string& signature);

/// How many makers there are: one per prototype that was used.
size_t foreignCallableMakerCount();

} // namespace detail

template <typename Signature> class ForeignCallable;

/// @brief A C function that runs a Scheme procedure, for as long as this object
/// lives.
///
/// Use it in a binding that gets a Scheme procedure from Scheme and has to call
/// it later from C++ code that only knows how to call a C function: an MLIR
/// visitor, a rewrite pattern, a legality check, a type conversion. C++ cannot
/// keep the procedure itself, because the garbage collector of Chez Scheme
/// moves it. A `ForeignCallable` asks Scheme for a C function that calls the
/// procedure (a Chez `foreign-callable`), keeps that function valid, lets you
/// call it, and releases it when the object is destroyed.
///
/// @tparam R     What the C function returns.
/// @tparam Args  The types of its arguments. The whole prototype is written as
///               a C++ function type: `ForeignCallable<void(uint64_t)>`.
///
/// The types that can cross the boundary are `uint64_t`, `int`, `unsigned`,
/// `uint8_t`, `void` (as a result) and any pointer (it crosses as an integer,
/// the address). A Scheme object such as an `mlir::Operation*`, a `Type` or a
/// `Value` crosses as its address, `uint64_t`, and Scheme wraps it again. A
/// range crosses as a pointer and a count. A string or a list does not cross as
/// a Scheme value: C++ gives Scheme a `foreign-procedure` that takes it and
/// pushes it into a C++ object.
///
/// @par What the Scheme procedure must do
/// It takes exactly the arguments of `Args` and answers `R`: a number for `int`
/// and the integer types, nothing for `void`. A boolean is `(if x 1 0)`. If it
/// raises an error, the error leaves through the C++ frames above it and their
/// destructors do not run: a procedure that can fail should catch the error
/// (`guard`) and answer a failure value, as the verifiers of CREST do.
///
/// @par Lifetime
/// The C function is valid from the creation of the object until its
/// destruction. Destroy the object on the thread that runs Scheme (it unlocks a
/// Scheme object), and never call the function afterwards. The class is
/// movable, not copyable; if MLIR copies your callback (a `std::function`),
/// keep the object in a `std::shared_ptr` that the lambda captures, as the
/// second example does. Create the object first in a binding, before a return
/// or a check that can raise, so that no path leaks it.
///
/// @par Not for callables that live as long as the process
/// A callback that a library defines once (the verifier of an op, a clause of
/// an interface) is made when the library loads, by
/// `crest-callback-entry-point` (scheme/crest/callback.sls), and C++ keeps its
/// address as a plain function pointer that is never released. This class is
/// for the callbacks that a caller passes for one run. The constructor from an
/// entry point takes over a callable that `crest-callback-entry-point` made,
/// when it must be released.
///
/// @par Cost
/// The first use of a prototype compiles a small maker procedure in Scheme and
/// keeps it. After that, creating and releasing a callable takes about a
/// microsecond (measured).
///
/// @par Example: a callback that is used while the binding runs
/// The Scheme call is `(mlir::Operation::walk op (lambda (nested-op) ...))`;
/// C++ visits every operation under `op` and calls the procedure for each.
/// @code
/// Sregister_symbol(
///     "mlir::Operation::walk", (void*)+[](uint64_t op, ptr callback) -> void {
///       // Made first: the return below must not leak it.
///       auto owned =
///           crest::ForeignCallable<void(uint64_t)>::fromProcedure(callback);
///       if (!op) {
///         return;
///       }
///       reinterpret_cast<mlir::Operation*>(op)->walk(
///           [&owned](mlir::Operation* nested) {
///             owned(reinterpret_cast<uint64_t>(nested));  // calls the lambda
///           });
///     });  // `owned` dies here: the C function is released
/// @endcode
///
/// @par Example: a callback that MLIR keeps
/// A type conversion is stored by the `TypeConverter` and called later, so the
/// callable must live as long as the converter does. MLIR copies the lambda, so
/// the owner is shared:
/// @code
/// using TypeConversionFn = uint64_t(uint64_t);   // Type in, Type or 0 out
/// Sregister_symbol(
///     "mlir::TypeConverter::addConversion",
///     (void*)+[](uint64_t converter_ptr, ptr callback) -> void {
///       auto owned =
///       std::make_shared<crest::ForeignCallable<TypeConversionFn>>(
///           crest::ForeignCallable<TypeConversionFn>::fromProcedure(callback));
///       auto& converter = crest::CrestBox<mlir::TypeConverter>::inner(
///           converter_ptr, "mlir::TypeConverter::addConversion");
///       converter.addConversion(
///           [owned](mlir::Type type) -> std::optional<mlir::Type> {
///             uint64_t result =
///                 (*owned)(reinterpret_cast<uint64_t>(type.getAsOpaquePointer()));
///             if (!result) {
///               return std::nullopt;                  // Scheme said "not
///               mine"
///             }
///             return mlir::Type::getFromOpaquePointer(
///                 reinterpret_cast<const void*>(result));
///           });
///     });  // the last copy of `owned` dies with the converter: released then
/// @endcode
template <typename R, typename... Args> class ForeignCallable<R(Args...)> {
public:
  /// An owner that holds no function (`entry()` is 0, `operator bool` is
  /// false).
  ForeignCallable() = default;

  /// Takes over the function at `entry`, a callable that Scheme made and
  /// locked (`crest-callback-entry-point`). The destructor releases it.
  explicit ForeignCallable(uint64_t entry) : entry_(entry) {}

  /// Releases the C function, so that Scheme can collect it.
  ~ForeignCallable() { release(); }

  ForeignCallable(const ForeignCallable&) = delete;
  ForeignCallable& operator=(const ForeignCallable&) = delete;

  ForeignCallable(ForeignCallable&& other) noexcept : entry_(other.entry_) {
    other.entry_ = 0;
  }
  ForeignCallable& operator=(ForeignCallable&& other) noexcept {
    if (this != &other) {
      release();
      entry_ = other.entry_;
      other.entry_ = 0;
    }
    return *this;
  }

  /// @brief Makes the C function of a Scheme procedure.
  ///
  /// @param procedure  The Scheme procedure, as the binding received it. It
  /// must
  ///                   take the arguments of `Args` and answer `R`. It is
  ///                   locked while the function is made, and the function
  ///                   holds it until the owner is destroyed.
  /// @return The owner of a C function with the prototype `R(Args...)`.
  /// @note Raises a Scheme error ("the callback is not a procedure") if
  ///       `procedure` is not a procedure. Make the owner before anything else
  ///       that can raise.
  static ForeignCallable fromProcedure(ptr procedure) {
    // Locked before anything that can call Scheme: the garbage collector moves
    // objects.
    LockedSchemeObject locked(procedure);
    if (!Sprocedurep(locked.get())) {
      scheme_error("crest::ForeignCallable::fromProcedure",
                   "the callback is not a procedure");
    }
    ptr maker =
        detail::foreignCallableMaker(detail::foreignSignature<R, Args...>());
    return ForeignCallable(Sunsigned64_value(scheme_call(maker, locked.get())));
  }

  /// The address of the C function, 0 when there is none. For code that needs
  /// the raw address; the owner still releases the function.
  uint64_t entry() const { return entry_; }

  /// Whether the owner holds a function.
  explicit operator bool() const { return entry_ != 0; }

  /// Calls the Scheme procedure through its C function and returns its answer.
  /// Not for an empty owner.
  R operator()(Args... args) const {
    // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
    return reinterpret_cast<R (*)(Args...)>(entry_)(args...);
  }

private:
  void release() {
    if (entry_ != 0) {
      // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
      Sunlock_object(Sforeign_callable_code_object(
          reinterpret_cast<void*>(static_cast<uintptr_t>(entry_))));
      entry_ = 0;
    }
  }

  uint64_t entry_ = 0;
};

} // namespace crest

#endif // CREST_BINDINGS_FOREIGN_CALLABLE_H
