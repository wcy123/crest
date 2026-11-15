/*
 * Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
 * Licensed under the MIT License.
 */
// Scheme and the worker threads of MLIR — lib/Interpreter/SchemeThreads.cpp

#include "SchemeThreads.h"
#include "SchemeWrapper.h"
#include "llvm/Support/ThreadPool.h"
#include "mlir/IR/MLIRContext.h"

// What a __collect_safe foreign-callable of Chez Scheme does on entry and
// exit (c/thread.c, in the Chez Scheme that cmake/deps.cmake pins; it is not
// in scheme.h). Activate answers how the thread was: unknown to Scheme (the
// thread is made, and unactivate forgets it again), inactive (unactivate makes
// it inactive again) or active (nothing to undo).
extern "C" int S_activate_thread(void);
extern "C" void S_unactivate_thread(int mode);

namespace crest {

namespace {

// While it lives, the calling thread is not active.
class StopBeingActive {
public:
  StopBeingActive() : scope_() { Sdeactivate_thread(); }
  ~StopBeingActive() { Sactivate_thread(); }
  StopBeingActive(const StopBeingActive&) = delete;
  StopBeingActive& operator=(const StopBeingActive&) = delete;

private:
  // Brings the thread to the state that it had, when the thread is done.
  SchemeThreadScope scope_;
};

// A worker is made known to Scheme, inactive, before it runs its first task,
// and forgotten when it ends.
class KnownToScheme {
public:
  KnownToScheme() {
    Sactivate_thread();
    Sdeactivate_thread();
  }
  ~KnownToScheme() { Sdestroy_thread(); }
};

class SchemeThreadPool final : public llvm::ThreadPoolInterface {
public:
  void wait() override {
    StopBeingActive stop;
    pool_.wait();
  }
  void wait(llvm::ThreadPoolTaskGroup& group) override {
    StopBeingActive stop;
    pool_.wait(group);
  }
  unsigned getMaxConcurrency() const override {
    return pool_.getMaxConcurrency();
  }

private:
  void asyncEnqueue(llvm::unique_function<void()> task,
                    llvm::ThreadPoolTaskGroup* group) override {
    auto wrapped = [task = std::move(task)]() mutable {
      thread_local KnownToScheme known;
      task();
    };
    if (group) {
      pool_.async(*group, std::move(wrapped));
    } else {
      pool_.async(std::move(wrapped));
    }
  }

  llvm::DefaultThreadPool pool_;
};

} // namespace

SchemeThreadScope::SchemeThreadScope() : mode_(S_activate_thread()) {}

SchemeThreadScope::~SchemeThreadScope() { S_unactivate_thread(mode_); }

llvm::ThreadPoolInterface& schemeThreadPool() {
  static SchemeThreadPool* pool = new SchemeThreadPool();
  return *pool;
}

void useSchemeThreadPool(mlir::MLIRContext& context) {
  // setThreadPool needs multithreading off and turns it on.
  bool wasEnabled = context.isMultithreadingEnabled();
  context.disableMultithreading();
  context.setThreadPool(schemeThreadPool());
  if (!wasEnabled) {
    context.disableMultithreading();
  }
}

} // namespace crest
