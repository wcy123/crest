;; scheme-mlir driver: runs each way of using a per-run callback (conversions, rewrite patterns,
;; modifyOpInPlace, registrations that are never applied, handles of the wrong kind) many times, each on
;; a context of its own, and prints "<name>: ok" or "<name>: leaked <n>".
;;
;; A per-run callback is a C function that C++ makes for one run: a code object that Chez keeps locked
;; until C++ unlocks it. A leak shows as code objects that outlive the run.
(import (except (rnrs) =)
        (only (chezscheme) collect object-counts enable-object-counts command-line-arguments)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation)
        (mlir Dialect Func IR FuncOps)
        (mlir Transforms DialectConversion)
        (only (mlir IR PatternMatch) with-RewritePatternSet)
        (only (mlir Pass PassManager)
              with-PassManager mlir::PassManager::nest mlir::PassManager::addPass
              mlir::OpPassManager::addPass mlir::PassManager::run!)
        (crest pass)
        (passes leaks))

(define (code-count)
  (collect 4 4)
  (let ([entry (assq 'code (object-counts))])
    (apply + (map cadr (cdr entry)))))

(define path (car (command-line-arguments)))

;; Runs (action ctx module) on a context of its own, with a module parsed from the input file.
(define (in-fresh-context action)
  (with-DialectRegistry reg ()
    (mlir::DialectRegistry::insert<mlir::func::FuncDialect> reg)
    (with-MLIRContext ctx (reg)
      (mlir::MLIRContext::allowUnregisteredDialects ctx #t)
      (mlir::MLIRContext::getOrLoadDialect ctx "func")
      (action ctx (mlir::parseSourceFile ctx path)))))

;; The error is the point of the scenario: it is caught here, in Scheme, so the run goes on.
(define (ignoring-errors thunk)
  (guard (c [#t #f]) (thunk)))

(define runs 100)

;; A run makes at least one callable: a leak is at least one code object per run. The loose bound
;; leaves room for the code that Chez compiles or loads lazily.
(define (check name once)
  (enable-object-counts #t)
  (once)
  (let ([before (code-count)])
    (do ([i 0 (+ i 1)]) ((= i runs)) (once))
    (let ([growth (- (code-count) before)])
      (display name)
      (display ": ")
      (display (if (< growth (quotient runs 4)) "ok" (list "leaked" growth)))
      (newline))))

(define-syntax scenario
  (syntax-rules ()
    [(_ name (ctx module) body ...)
     (check name (lambda () (in-fresh-context (lambda (ctx module) body ...))))]))

(scenario "conversion-full" (ctx module) (conversion-full module))
(scenario "conversion-partial" (ctx module) (conversion-partial module))
(scenario "unused-sets" (ctx module) (unused-sets module))
(scenario "rewrite-greedy" (ctx module) (rewrite-greedy module))
(scenario "modify-in-place" (ctx module) (modify-in-place module))

;; The body of a pass is made into a C function once, when define-pass is evaluated; making pass
;; managers and running them does not make more.
(define-pass (leak-pass op) #t)

(scenario "pass-pipeline" (ctx module)
          (with-PassManager pm (ctx)
            (mlir::PassManager::addPass pm (leak-pass))
            (mlir::OpPassManager::addPass (mlir::PassManager::nest pm "func.func") (leak-pass))
            (mlir::PassManager::run! pm module)))
