/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// HipSR dialect stub bindings for CREST.
//
// These follow CREST naming conventions so they are auto-discoverable via
// foreign-entry? without explicit Scheme changes.
//
// STUB IMPLEMENTATIONS: HipSR dialect headers are not available in the
// standalone CREST build. These stubs return safe sentinel values so the
// framework compiles and loads; patterns simply fail to match on non-HipSR
// tensors. A full hip-ep build provides the real implementations.
//
// Function families:
//   mlir_make_attr_hipsr_*   (uptr ctx, ptr value) → uptr  [mlir_make_attr_* convention]
//   mlir_attr_isa_hipsr_*    (uptr attr)            → int   [mlir_attr_isa_* convention]
//   mlir_type_is_device_tensor / mlir_tensor_type_in_host_space / etc.

#include "../SchemeWrapper.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/Operation.h"
#include <cstdint>
#include <cstring>

extern "C" {

// ── mlir_make_attr_* family ──────────────────────────────────────────────────

// Create HipSR MemorySpaceAttr(Device). Stub: returns 0 (null attr).
uint64_t mlir_make_attr_hipsr_device_space(uint64_t /*ctx*/, ptr /*value*/) {
  return 0;
}

// Create HipSR PlaceholderTypeAttr(Barrier). Stub: returns 0.
uint64_t mlir_make_attr_hipsr_barrier_type(uint64_t /*ctx*/, ptr /*value*/) {
  return 0;
}

// ── mlir_attr_isa_* family ───────────────────────────────────────────────────

// 1 if attr is MemorySpaceAttr(Device). Stub: always 0.
int mlir_attr_isa_hipsr_device_space(uint64_t /*attr*/) { return 0; }

// 1 if attr is PlaceholderTypeAttr(Barrier). Stub: always 0.
int mlir_attr_isa_hipsr_barrier_type(uint64_t /*attr*/) { return 0; }

// ── Type and op helpers ──────────────────────────────────────────────────────

// 1 if type is a RankedTensorType with a HipSR device MemorySpaceAttr.
// Stub: always 0 (no device tensors without the HipSR dialect).
int mlir_type_is_device_tensor(uint64_t /*type_ptr*/) { return 0; }

// Clone a RankedTensorType with the HipSR host memory space encoding.
// Stub: returns the input type unchanged.
uint64_t mlir_tensor_type_in_host_space(uint64_t type_ptr) { return type_ptr; }

// Return the !hipsr.context type for the given MLIRContext. Stub: returns 0.
uint64_t mlir_get_hipsr_context_type(uint64_t /*ctx_ptr*/) { return 0; }

// Set placeholder_type attr to Barrier. Stub: no-op.
void mlir_placeholder_set_barrier_type(uint64_t /*op_ptr*/) {}

// Memory-map a file. Stub: returns 0 (mapping unavailable).
uint64_t mlir_hipsr_load_file_map(uint64_t /*ctx_ptr*/, const char* /*path*/) {
  return 0;
}

} // extern "C"

namespace crest {

void registerHipSRDialectBindings() {
  // mlir_make_attr_hipsr_* — follows mlir_make_attr_* convention, auto-discovered
  Sregister_symbol("mlir_make_attr_hipsr_device_space",
                   (void*)::mlir_make_attr_hipsr_device_space);
  Sregister_symbol("mlir_make_attr_hipsr_barrier_type",
                   (void*)::mlir_make_attr_hipsr_barrier_type);
  // mlir_attr_isa_hipsr_* — auto-discovered by mlir-attr-isa
  Sregister_symbol("mlir_attr_isa_hipsr_device_space",
                   (void*)::mlir_attr_isa_hipsr_device_space);
  Sregister_symbol("mlir_attr_isa_hipsr_barrier_type",
                   (void*)::mlir_attr_isa_hipsr_barrier_type);
  // Type and op helpers
  Sregister_symbol("mlir_type_is_device_tensor",
                   (void*)::mlir_type_is_device_tensor);
  Sregister_symbol("mlir_tensor_type_in_host_space",
                   (void*)::mlir_tensor_type_in_host_space);
  Sregister_symbol("mlir_get_hipsr_context_type",
                   (void*)::mlir_get_hipsr_context_type);
  Sregister_symbol("mlir_placeholder_set_barrier_type",
                   (void*)::mlir_placeholder_set_barrier_type);
  Sregister_symbol("mlir_hipsr_load_file_map",
                   (void*)::mlir_hipsr_load_file_map);
}

} // namespace crest
