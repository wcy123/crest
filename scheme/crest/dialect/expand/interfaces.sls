;; Interface registration code generator for define-dialect ops.
;; Generates per-op dispatcher functions and interface registration calls
;; at dialect initialisation time.
;; The C++ global op-interface registry in Dialect.cpp handles lookups at runtime.
(library (crest dialect expand interfaces)
  (export generate-interface-registrations
          dialect-cbs-with-interfaces)
  (import (chezscheme)
          (crest dialect ast)
          (crest dialect expand utils))

  ;; Generate per-op dispatcher defines and interface registration calls
  ;; for ALL ops that declare :interfaces entries.
  ;;
  ;; Returns (values (list define-stx ...) (list setup-call-stx ...)).
  ;; define-stxs go at top level; setup-calls go into %%<dialect>:initialize.
  ;;
  ;; Generated dispatcher shape:
  ;;   (define (%%toy.func:mlir::FunctionOpInterface method)
  ;;     (case method
  ;;       ((operation_name) "toy.func")
  ;;       ((getFunctionType) (lambda (self) ...))   ; if declared
  ;;       ...
  ;;       (else #f)))                               ; #f → use C++ default
  ;;
  ;; Registration call — inline foreign-procedure so no Scheme identifier for
  ;; the interface function is needed at the define-dialect call site:
  ;;   ((foreign-procedure "mlir::FunctionOpInterface" (scheme-object) void)
  ;;    %%toy.func:mlir::FunctionOpInterface)
  (define (generate-interface-registrations ctx ops)
    (let ([op-prefix (string-append (%%id->str ctx) ".")])
      (let loop ([ops ops] [defs '()] [calls '()])
        (if (null? ops)
            (values (reverse defs) (reverse calls))
            (let* ([op            (car ops)]
                   [op-name-str   (string-append op-prefix (%%id->str (op-parse-name op)))]
                   [iface-entries (op-parse-interfaces op)])
              (if (null? iface-entries)
                  (loop (cdr ops) defs calls)
                  (let per-iface ([entries iface-entries] [defs defs] [calls calls])
                    (if (null? entries)
                        (loop (cdr ops) defs calls)
                        (let* ([entry          (car entries)]
                               [iface-stx      (interface-entry-name entry)]
                               [iface-name-str (%%id->str iface-stx)]
                               [methods        (interface-entry-methods entry)]
                               ;; %%toy.func:mlir::FunctionOpInterface
                               [proc-id        (%%id ctx "%%" op-name-str ":" iface-stx)])
                          (with-syntax
                              ([dispatch-proc  proc-id]
                               [iface-sym      iface-name-str]
                               [op-name-s      op-name-str]
                               [(method-clause ...)
                                (map (lambda (m)
                                       (with-syntax
                                           ([mname   (datum->syntax ctx (interface-method-name m))]
                                            [formals (interface-method-formals m)]
                                            [body    (interface-method-body m)])
                                         #'((mname) (lambda formals . body))))
                                     methods)])
                            (per-iface
                             (cdr entries)
                             (cons #'(define (dispatch-proc method)
                                       (case method
                                         ((operation_name) op-name-s)
                                         method-clause ...
                                         (else #f)))
                                   defs)
                             (cons #'((foreign-procedure iface-sym (scheme-object) void)
                                      dispatch-proc)
                                   calls))))))))))))

  ;; Build the 11-slot dialect callbacks vector (slots 0-10).
  ;; Slot 11 (:get-registered-interface-for-op) is removed — LookupInterfaceForOp
  ;; is now called directly in CrestDialect::getRegisteredInterfaceForOp.
  ;; Slot 0 → %%<dialect>:initialize (registers interface concepts).
  (define (dialect-cbs-with-interfaces ctx dialect-cbs ops)
    (let ([v (list->vector (map (lambda (i) (or (vector-ref dialect-cbs i) #'#f))
                                '(0 1 2 3 4 5 6 7 8 9 10)))])
      (vector-set! v 0 (%%id ctx "%%" ctx ":initialize"))
      (vector->list v)))

  ) ;; end library (crest dialect expand interfaces)
