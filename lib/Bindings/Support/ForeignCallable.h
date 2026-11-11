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

template <typename T> inline constexpr bool kAlwaysFalse = false;

/// The name that a foreign-callable gives a C++ type in its prototype. A type
/// that is not listed below cannot cross the boundary.
template <typename T> struct ForeignTypeName {
  static_assert(kAlwaysFalse<T>,
                "this type cannot cross the boundary of a ForeignCallable: use "
                "uint64_t, int, unsigned, uint8_t, void or a pointer");
  static constexpr const char* value = "";
};
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

/// The Scheme procedure that makes a callable of one prototype: `(lambda
/// (procedure) ...)` answers the entry point of a `foreign-callable` of the
/// procedure, with its code object locked. It is compiled on every call; the
/// caller keeps the result (see `ForeignSignature::maker`).
ptr foreignCallableMaker(const std::string& signature);

/// A prototype R(Args...), and the maker of the callables of that prototype.
///
/// Every prototype is its own type, so the maker is a static member: there is
/// no table, and nothing is allocated in C++. The maker is compiled the first
/// time the prototype is used. This type owns it and keeps it locked until the
/// process ends, then unlocks it.
///
/// The unlock happens while the process exits. It is safe because Chez does not
/// free its memory then: nothing calls `Sscheme_deinit`, and the `(exit)` of
/// Scheme ends in the C `exit()`. The test
/// test/dsl/one-shot-callbacks/exit.mlir ends a program both ways. If a
/// shutdown of Chez is ever added, it must come after these unlocks.
template <typename R, typename... Args> struct ForeignSignature {
  /// The maker, compiled on first use. Scheme must be running. Call it on the
  /// thread that runs Scheme: it is not thread-safe.
  static ptr maker() {
    if (maker_.get() == Sfalse) {
      maker_ = LockedSchemeObject(foreignCallableMaker(text()));
    }
    return maker_.get();
  }

private:
  /// The prototype as Scheme writes it, for example "(uptr int) void".
  static std::string text() {
    std::string signature = "(";
    const char* separator = "";
    ((signature += separator, signature += ForeignTypeName<Args>::value,
      separator = " "),
     ...);
    signature += ") ";
    signature += ForeignTypeName<R>::value;
    return signature;
  }

  static inline LockedSchemeObject maker_;
};

} // namespace detail

template <typename Signature> class ForeignCallable;

/// @brief A C function that calls a Scheme procedure. It stays valid for as
/// long as this object lives.
///
/// Use it in a C++ binding that receives a Scheme procedure and must call it
/// later. You need it when the code that makes the call can only call a C
/// function. Examples are an MLIR visitor, a rewrite pattern, a legality check
/// and a type conversion.
///
/// C++ cannot simply keep the Scheme procedure. The garbage collector of Chez
/// Scheme moves objects around, so a stored pointer to the procedure would
/// soon be wrong. Instead, `ForeignCallable` asks Scheme to build a C function
/// that calls the procedure (a Chez `foreign-callable`). The object keeps that
/// C function valid, and you call it with `operator()`. When the object is
/// destroyed, the C function is released and Scheme can free it.
///
/// @tparam R     The type the C function returns.
/// @tparam Args  The types of its arguments. You write them as a C++ function
///               type, for example `ForeignCallable<void(uint64_t)>`.
///
/// @par What can be passed
/// The C function takes and returns only numbers: `uint64_t`, `int`,
/// `unsigned` and `uint8_t`, or `void` as the result. A pointer is also
/// allowed. It is passed as a number, its address. So an `mlir::Operation*`, a
/// `Type` or a `Value` goes to Scheme as its address (`uint64_t`), and Scheme
/// turns the number back into the object.
///
/// The C function cannot take a Scheme string or a Scheme list. To send many
/// values to Scheme, pass a pointer to an array and the number of elements.
/// Scheme reads them with `crest-callback-pointer-list`. To get many values (or
/// a string) back from Scheme, let the procedure call a C++ function once for
/// each value, and let that C++ function collect them. `crest::Fold::addValue`
/// is an example.
///
/// @par What the Scheme procedure must do
/// It takes the same arguments as `Args` and returns a value of type `R`. For
/// `int` and the other integer types it returns a number. To return true or
/// false, return 1 or 0, for example `(if ok 1 0)`.
///
/// If the procedure raises an error, the error jumps out through the C++ code
/// that called the function, and the destructors of that C++ code do not run.
/// So a procedure that can fail should catch its errors (with `guard`) and
/// return a value that means "failed". The verifiers in CREST do this.
///
/// @par How long the C function lives
/// The C function is valid from the moment the object is created until the
/// object is destroyed. Do not call it after that.
///
/// The object can be moved but not copied. Sometimes MLIR copies your callback,
/// because it keeps it in a `std::function`. In that case put the object in a
/// `std::shared_ptr` and let the lambda capture the pointer, as the second
/// example does. The C function is released when the last copy goes away.
///
/// Destroy the object on the thread that runs Scheme, because releasing the
/// function calls into Scheme.
///
/// @par The order of work in a binding
/// 1. Copy what you need out of Scheme memory. Creating the object runs
///    Scheme code, and that can move Scheme objects. A `const char*` that
///    Scheme gave you can then point to the wrong place. So first turn it into
///    a `std::string`, and read the elements of a Scheme list into a C++
///    container.
/// 2. Do the checks that can raise an error (for example with `scheme_error`).
///    An error that happens while the object exists skips its destructor. The
///    C function then stays locked and is never freed. This is a small leak,
///    not a crash.
/// 3. Create the object with `fromProcedure`.
/// 4. Use it. Do not raise errors while it exists.
///
/// @par When not to use it
/// Some callbacks live as long as the program: the verifier of an op, or a
/// clause of an interface. The library that defines them builds their C
/// functions once, when the library is loaded (`crest-callback-entry-point` in
/// scheme/crest/callback.sls). C++ keeps only the function pointer and never
/// frees it. Do not use this class for those.
///
/// Use this class for callbacks that a caller passes in for one run. If a
/// function was built by `crest-callback-entry-point` but must be freed later,
/// the constructor that takes an entry point lets this object take it over.
///
/// @par Cost
/// The first time a prototype is used, Scheme compiles a small helper for it,
/// which takes about 0.6 milliseconds (measured). The helper belongs to the
/// prototype and is kept until the process ends. After that, creating and
/// releasing a function takes about 0.6 microseconds (measured).
///
/// @par Example: a callback that is used while the binding runs
/// The Scheme call is `(mlir::Operation::walk op (lambda (nested-op) ...))`.
/// C++ visits every operation under `op` and calls the Scheme procedure for
/// each one. The callback is only used while the binding runs, so a local
/// object is enough.
/// @code
/// Sregister_symbol(
///     "mlir::Operation::walk", (void*)+[](uint64_t op, ptr callback) -> void {
///       // The object releases the function on every path out of the binding.
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
/// The `TypeConverter` stores a type conversion and calls it later, after the
/// binding has returned. So the C function must live as long as the converter.
/// MLIR copies the lambda, so the object is shared. The last copy releases the
/// function.
/// @code
/// // A Scheme procedure that takes a Type and answers a Type, or 0.
/// using Conversion = crest::ForeignCallable<uint64_t(uint64_t)>;
/// Sregister_symbol(
///     "mlir::TypeConverter::addConversion",
///     (void*)+[](uint64_t converter_ptr, ptr callback) -> void {
///       auto owned = std::make_shared<Conversion>(
///           Conversion::fromProcedure(callback));
///       auto& converter = crest::CrestBox<mlir::TypeConverter>::inner(
///           converter_ptr, "mlir::TypeConverter::addConversion");
///       converter.addConversion(
///           [owned](mlir::Type type) -> std::optional<mlir::Type> {
///             uint64_t answer =
///                 (*owned)(reinterpret_cast<uint64_t>(type.getAsOpaquePointer()));
///             // 0 means that Scheme does not convert this type.
///             if (answer == 0) {
///               return std::nullopt;
///             }
///             return mlir::Type::getFromOpaquePointer(
///                 reinterpret_cast<const void*>(answer));
///           });
///     });
/// @endcode
template <typename R, typename... Args> class ForeignCallable<R(Args...)> {
public:
  /// Creates an empty object. It holds no function: `entry()` is 0 and
  /// `operator bool` is false.
  ForeignCallable() = default;

  /// Takes over a C function that Scheme has already built and locked with
  /// `crest-callback-entry-point`. The destructor releases it. Create the
  /// object as the first thing in the binding: until then, an early `return`
  /// leaves the function locked.
  explicit ForeignCallable(uint64_t entry) : entry_(entry) {}

  /// Releases the C function, so that Scheme can free it.
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

  /// @brief Builds a C function that calls a Scheme procedure.
  ///
  /// @param procedure  The Scheme procedure, exactly as the binding got it.
  ///                   It must take the arguments in `Args` and return `R`.
  ///                   The C function keeps it alive until this object is
  ///                   destroyed.
  /// @return An object that owns the new C function. Its prototype is
  ///         `R(Args...)`.
  /// @note If `procedure` is not a procedure, this raises the Scheme error
  ///       "the callback is not a procedure".
  static ForeignCallable fromProcedure(ptr procedure) {
    // Locked before anything that can call Scheme: the garbage collector moves
    // objects.
    LockedSchemeObject locked(procedure);
    if (!Sprocedurep(locked.get())) {
      scheme_error("crest::ForeignCallable::fromProcedure",
                   "the callback is not a procedure");
    }
    ptr maker = detail::ForeignSignature<R, Args...>::maker();
    return ForeignCallable(Sunsigned64_value(scheme_call(maker, locked.get())));
  }

  /// Returns the address of the C function, or 0 if the object is empty. Use
  /// it only when you need the raw address. The object still releases the
  /// function.
  uint64_t entry() const { return entry_; }

  /// True if the object holds a C function.
  explicit operator bool() const { return entry_ != 0; }

  /// Calls the Scheme procedure through its C function and returns the
  /// result. Do not call it on an empty object.
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
