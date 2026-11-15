/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#ifndef CREST_INTERPRETER_SCHEMETHREADS_H
#define CREST_INTERPRETER_SCHEMETHREADS_H

// Scheme and threads (docs/manual.md, "Threads").
//
// Chez Scheme keeps a record for each thread that runs Scheme, and the record
// says whether the thread is active. A garbage collection waits until every
// active thread has stopped at a safe point in Scheme code, so a thread that is
// active but busy in C++ (MLIR waiting for its worker threads, say) blocks
// every collection for ever. The rule that follows: a thread is active only
// while it runs Scheme.
//   - The interpreter makes the thread that started Scheme inactive when it has
//     started it.
//   - A callable that Scheme makes is __collect_safe: the thread is active for
//     the call and is put back afterwards (scheme/crest/callback.sls).
//   - C++ that calls Scheme or builds Scheme objects (Sstring, Scar, ...) from
//     any other code than a binding that Scheme called uses SchemeThreadScope.

namespace crest {

/// For the length of the scope, the calling thread can run Scheme (it is
/// active), and afterwards it is as it was: a thread that Scheme did not know
/// is forgotten again, an inactive one is inactive again, an active one (inside
/// a callable, or in a binding that Scheme called) stays active.
class SchemeThreadScope {
public:
  SchemeThreadScope();
  ~SchemeThreadScope();
  SchemeThreadScope(const SchemeThreadScope&) = delete;
  SchemeThreadScope& operator=(const SchemeThreadScope&) = delete;

private:
  int mode_;
};

} // namespace crest

#endif // CREST_INTERPRETER_SCHEMETHREADS_H
