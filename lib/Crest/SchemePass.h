/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Passes written in Scheme — lib/Crest/SchemePass.h
//
// `define-pass` makes an mlir::Pass whose runOnOperation calls a Scheme
// procedure on the anchor op. The pass is returned as a raw mlir::Pass*, like
// every create...Pass binding, and the pass manager that addPass adds it to
// owns it.

#ifndef CREST_SCHEME_PASS_H
#define CREST_SCHEME_PASS_H

namespace crest {

void registerCrestSchemePassBindings();

} // namespace crest

#endif // CREST_SCHEME_PASS_H
