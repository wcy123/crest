#pragma once
#include <cstdint>

// CArrayRef — plain-C struct for passing ArrayRef<T> across the FFI boundary.
// Binary layout (64-bit):
//   offset 0: data uptr  — pointer to first element
//   offset 8: size uptr  — number of elements
// Compatible with Chez Scheme's foreign-ref at offsets 0 and 8.
struct CArrayRef {
  uint64_t data;
  uint64_t size;
};

namespace crest {
void registerArrayRefBindings();
}
