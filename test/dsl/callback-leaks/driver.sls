;; scheme-mlir driver: runs each way of using a per-run callback (conversions, rewrite patterns,
;; modifyOpInPlace, registrations that are never applied, handles of the wrong kind) many times, each on
;; a context of its own, and prints "<name>: ok" or "<name>: leaked <n>".
;;
;; A per-run callback is a C function that C++ makes for one run: a code object that Chez keeps locked
;; until C++ unlocks it. A leak shows as code objects that outlive the run.
(import (except (rnrs) =)
        (only (crest dialect) load-scheme-dialect!)
        (only (chezscheme) collect object-counts enable-object-counts command-line-arguments)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR Operation) (mlir IR OwningOpRef)
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
      (with-mlir::OwningOpRef module (mlir::parseSourceFile ctx path)
        (action ctx module)))))

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

;; A mistake of the caller: a handle of the wrong kind. The binding raises an error. The callback was
;; given first, so a C function exists by then, and it must be released on this path too.
(scenario "wrong-handle-conversion" (ctx module)
          (with-TypeConverter tc ()
            (with-ConversionTarget target (ctx)
              (ignoring-errors
               (lambda () (type-converter-add-conversion target (lambda (type) type)))))))

(scenario "wrong-handle-materialization" (ctx module)
          (with-TypeConverter tc ()
            (with-ConversionTarget target (ctx)
              (ignoring-errors
               (lambda ()
                 (mlir::TypeConverter::addSourceMaterialization target (lambda (b t i l) #f))))
              (ignoring-errors
               (lambda ()
                 (mlir::TypeConverter::addTargetMaterialization target (lambda (b t i l) #f)))))))

(scenario "wrong-handle-legality" (ctx module)
          (with-TypeConverter tc ()
            (ignoring-errors
             (lambda () (target-add-dynamically-legal-op tc ctx "test.a" (lambda (op) #f))))
            (ignoring-errors
             (lambda () (target-mark-unknown-ops-dynamically-legal tc (lambda (op) #t))))))

(scenario "wrong-handle-patterns" (ctx module)
          (with-TypeConverter tc ()
            (with-ConversionTarget target (ctx)
              (with-RewritePatternSet patterns (ctx)
                (ignoring-errors
                 (lambda () (add-rewrite-pattern tc "test.a" (lambda (op rewriter) #f) 1)))
                (ignoring-errors
                 (lambda () (add-conversion-pattern patterns "test.a" (lambda (op o r t) #f) target 1)))
                (ignoring-errors
                 (lambda () (add-conversion-pattern/ctx tc "test.a" (lambda (op o r t) #f) 1)))))))

(scenario "wrong-handle-modify" (ctx module)
          (with-TypeConverter tc ()
            (ignoring-errors
             (lambda () (mlir::RewriterBase::modifyOpInPlace tc module (lambda () #t))))))

;; The callables of a dialect (the clauses of its interfaces, its inliner, its ops and types) are made
;; once, when its library is loaded. A context that loads the dialect makes none of its own.
(check "dialect-load"
       (lambda ()
         (with-DialectRegistry reg ()
           (with-MLIRContext ctx (reg)
             (load-scheme-dialect! ctx "leaks" "passes/leaks-dialect")))))
