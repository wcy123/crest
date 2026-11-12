#pragma once
#include "CrestObject.h"
#include <cstddef>
#include <cstdint>

// CArrayRef<T> — typed CREST-managed foreign object wrapping a (data, size)
// pair. Inherits from crest::AsCrest<CArrayRef<T>>, placing the deletor at
// offset 0.
//
// Binary layout (64-bit) — same for all T:
//   offset 0:  deletor (8B) — from AsCrest<CArrayRef<T>>; type tag + destructor
//   offset 8:  data    (8B) — non-owning const T* pointer to first element
//   offset 16: size    (8B) — number of elements
//
// One instantiation is used in CREST:
//   CArrayRef<uintptr_t> — mlir::Value* operands-ref  (stride 8B)
// C++ owns it (a view of memory that C++ keeps): Scheme only reads it, through
// the predicate crest::CArrayRef<uptr>?. A view that C++ makes for Scheme to
// free leaked when Scheme forgot: DenseI32/I64ArrayAttr::asArrayRef answer a
// Scheme list instead.
template <typename T> struct CArrayRef : public crest::AsCrest<CArrayRef<T>> {
  const T* data; // offset 8  — non-owning, do NOT free
  size_t size;   // offset 16

  CArrayRef(const T* d, size_t s)
      : crest::AsCrest<CArrayRef<T>>(), data(d), size(s) {}
};

namespace crest {
void registerArrayRefBindings();
} // namespace crest
