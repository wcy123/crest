/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */

#include "SchemeWrapper.h"

SValue convert_to_scheme_func(const char* fname) {
  SValue f = Stop_level_value(Sstring_to_symbol(fname));
  if (f == Sfalse) {
    fprintf(stderr, "error: scheme_call: unbound Scheme function '%s'\n",
            fname);
    std::abort();
  }
  return f;
}
