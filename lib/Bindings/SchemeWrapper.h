/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#ifndef CREST_BINDINGS_SCHEME_WRAPPER_H
#define CREST_BINDINGS_SCHEME_WRAPPER_H

// Wrapper for Chez Scheme's scheme.h
//
// Chez Scheme's generated scheme.h does NOT have include guards,
// which causes redefinition errors if included multiple times.
// This wrapper provides the protection.

extern "C" {
#include "boot/ta6le/scheme.h"
}

#endif // CREST_BINDINGS_SCHEME_WRAPPER_H
