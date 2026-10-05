/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_BINDINGS_LOGGING_H
#define CREST_BINDINGS_LOGGING_H

// Logging functions defined in lib/Bindings/Support/Logging.cpp.
// Include this header in any Bindings .cpp file that calls
// mlir_support_logging_*.
extern "C" {
void mlir_support_logging_trace(const char* msg);
void mlir_support_logging_debug(const char* msg);
void mlir_support_logging_info(const char* msg);
void mlir_support_logging_warning(const char* msg);
void mlir_support_logging_error(const char* msg);
void mlir_support_logging_fatal(const char* msg);
} // extern "C"

namespace crest {
void registerLoggingBindings();
} // namespace crest

#endif // CREST_BINDINGS_LOGGING_H
