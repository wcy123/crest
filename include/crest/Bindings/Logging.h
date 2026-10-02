/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_BINDINGS_LOGGING_H
#define CREST_BINDINGS_LOGGING_H

// Logging functions defined in lib/Bindings/Logging.cpp.
// Include this header in any Bindings .cpp file that calls mlir_log_*.
extern "C" {
void mlir_log_trace(const char* msg);
void mlir_log_debug(const char* msg);
void mlir_log_info(const char* msg);
void mlir_log_warning(const char* msg);
void mlir_log_error(const char* msg);
void mlir_log_fatal(const char* msg);
} // extern "C"

#endif // CREST_BINDINGS_LOGGING_H
