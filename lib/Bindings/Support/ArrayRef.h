#pragma once
#include "CrestObject.h"
#include <cstddef>
#include <cstdint>

// CArrayRef — CREST-managed foreign object wrapping a (data, size) pair.
// Inherits from crest::AsCrest<CArrayRef> which places the deletor at offset 0.
//
// Binary layout (64-bit):
//   offset 0:  deletor (8B) — from crest::AsCrest<CArrayRef>; type tag +
//   destructor offset 8:  data    (8B) — non-owning pointer to first element
//   offset 16: size    (8B) — number of elements
//
// Scheme accesses data and size via foreign-ref at offsets 8 and 16
// respectively.
struct CArrayRef : public crest::AsCrest<CArrayRef> {
  const void* data; // offset 8  — non-owning, do NOT free
  size_t size;      // offset 16

  CArrayRef(const void* d, size_t s)
      : crest::AsCrest<CArrayRef>(), data(d), size(s) {}
};

namespace crest {
void registerArrayRefBindings();
}
