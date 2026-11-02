/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#pragma once
// CREST binding for the Toy StructType used in Ch7.
// Implements a proper MLIR TypeStorage so that StructType is uniqued
// correctly in the MLIRContext and can round-trip through the type system.

void registerToyStructTypeBindings();
