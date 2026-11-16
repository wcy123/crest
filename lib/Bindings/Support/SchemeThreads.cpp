/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Scheme and threads — lib/Bindings/Support/SchemeThreads.cpp

#include "SchemeThreads.h"
#include "SchemeWrapper.h"

// What a __collect_safe foreign-callable of Chez Scheme does on entry and
// exit (c/thread.c, in the Chez Scheme that cmake/deps.cmake pins; it is not
// in scheme.h). Activate answers how the thread was: unknown to Scheme (the
// thread is made, and unactivate forgets it again), inactive (unactivate makes
// it inactive again) or active (nothing to undo).
extern "C" int S_activate_thread(void);
extern "C" void S_unactivate_thread(int mode);

namespace crest {

SchemeThreadScope::SchemeThreadScope() : mode_(S_activate_thread()) {}

SchemeThreadScope::~SchemeThreadScope() { S_unactivate_thread(mode_); }

} // namespace crest
