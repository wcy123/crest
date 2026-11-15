/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
#ifndef CREST_INTERPRETER_SCHEMETHREADS_H
#define CREST_INTERPRETER_SCHEMETHREADS_H

// Scheme and the worker threads of MLIR (docs/manual.md, "Threads").
//
// Chez Scheme runs on several threads, but it needs to know about each one:
// a thread that runs Scheme is "active", and a garbage collection waits until
// every active thread but the collecting one has stopped. So
//   - a thread of MLIR must be active while it runs Scheme and not otherwise
//     (the callables that Scheme makes see to it themselves,
//     scheme/crest/callback.sls; C++ that calls Scheme uses SchemeThreadScope);
//   - a thread that waits for the others must not be active while it waits, or
//     a collection that one of them starts waits for it for ever
//     (schemeThreadPool does that for MLIR's waits).

namespace llvm {
class ThreadPoolInterface;
} // namespace llvm

namespace mlir {
class MLIRContext;
} // namespace mlir

namespace crest {

/// For the length of the scope, the calling thread can run Scheme (it is
/// active), and afterwards it is as it was: a thread that Scheme did not know
/// is forgotten again, an inactive one is inactive again, an active one (the
/// thread that started Scheme, or a worker inside a callable) stays active.
class SchemeThreadScope {
public:
  SchemeThreadScope();
  ~SchemeThreadScope();
  SchemeThreadScope(const SchemeThreadScope&) = delete;
  SchemeThreadScope& operator=(const SchemeThreadScope&) = delete;

private:
  int mode_;
};

/// The thread pool for a context whose ops run Scheme: MLIR's own pool, with
/// two changes. A task runs on a worker that Scheme knows, inactive, until the
/// task ends (a callable or a SchemeThreadScope makes it active when it runs
/// Scheme). A wait leaves the waiting thread inactive. One pool serves all
/// contexts; it lives until the process ends.
llvm::ThreadPoolInterface& schemeThreadPool();

/// Make `context` use schemeThreadPool(). Whether the context runs on several
/// threads stays as it is; a later enableMultithreading keeps the pool.
void useSchemeThreadPool(mlir::MLIRContext& context);

} // namespace crest

#endif // CREST_INTERPRETER_SCHEMETHREADS_H
