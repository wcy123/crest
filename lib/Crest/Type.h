/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Dialect types defined in Scheme — lib/Crest/Type.h
//
// A Scheme dialect's `define-type` becomes a mlir::DynamicTypeDefinition: a
// type with a name and a list of attribute parameters, a verifier, and an
// optional parser and printer for the text after the name. The registry keeps
// the definition of each (context, dialect, name) so Scheme can build the type,
// test for it and read its parameters.

#ifndef CREST_TYPE_H
#define CREST_TYPE_H

namespace crest {

void registerCrestDynamicTypeBindings();

} // namespace crest

#endif // CREST_TYPE_H
