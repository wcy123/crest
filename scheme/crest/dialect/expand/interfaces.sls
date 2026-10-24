;; Interface registration code generator for define-dialect ops.
;; Replaces the old Scheme-side getRegisteredInterfaceForOp cond chain with
;; calls to crest::Interface::registerConcept at dialect initialisation time.
;; The C++ global op-interface registry in Dialect.cpp handles lookups at
;; runtime — no Scheme callback needed for slot 11.
(library (crest dialect expand interfaces)
  (export generate-interface-registrations
          dialect-cbs-with-interfaces)
  (import (chezscheme)
          (crest dialect ast)
          (crest dialect expand utils)
          (crest dialect ffi))

  ;; Map interface name → registerConcept symbol in client scope.
  ;; Validates that the interface is supported; errors at expansion time otherwise.
  (define (%%register-symbol-for ctx entry)
    (let ([name (%%id->str (interface-entry-name entry))])
      (cond
       [(string=? name "mlir::FunctionOpInterface")
        (%%id ctx 'crest::FunctionOpInterface::registerConcept)]
       [else
        (syntax-violation ':interfaces
                          (string-append "unsupported interface — only mlir::FunctionOpInterface is supported: " name)
                          (interface-entry-name entry))])))

  ;; Generate per-op Scheme dispatch procedure defines and registerConcept calls
  ;; for ALL ops that declare :interfaces entries.
  ;;
  ;; Returns (values (list define-stx ...) (list setup-call-stx ...)).
  ;; define-stxs go at top level; setup-calls go into %%<dialect>:initialize.
  ;;
  ;; For entries with method bodies: generates %%op:interface dispatch proc +
  ;;   (registerConcept op-name dispatch-proc).
  ;; For entries without method bodies: generates
  ;;   (registerConcept op-name #f) — C++ default concept is used.
  (define (generate-interface-registrations ctx ops)
    (let ([op-prefix (string-append (%%id->str ctx) ".")])
      (let loop ([ops ops] [defs '()] [calls '()])
        (if (null? ops)
            (values (reverse defs) (reverse calls))
            (let* ([op          (car ops)]
                   [op-name-str (string-append op-prefix (%%id->str (op-parse-name op)))]
                   [iface-entries (op-parse-interfaces op)])
              (if (null? iface-entries)
                  (loop (cdr ops) defs calls)
                  (let per-iface ([entries iface-entries] [defs defs] [calls calls])
                    (if (null? entries)
                        (loop (cdr ops) defs calls)
                        (let* ([entry     (car entries)]
                               [iface-stx (interface-entry-name entry)]
                               [iface-name (%%id->str iface-stx)]
                               [methods   (interface-entry-methods entry)]
                               [declared  (map interface-method-name methods)]
                               ;; cloneTypeWith cannot be overridden from Scheme.
                               [_         (when (memq 'cloneTypeWith declared)
                                            (syntax-violation ':interfaces
                                                              "cloneTypeWith cannot be overridden from Scheme (TypeRange cannot cross the FFI boundary)"
                                                              iface-stx))]
                               [reg-sym   (%%register-symbol-for ctx entry)]
                               ;; %%toy.func:mlir::FunctionOpInterface
                               [proc-id   (%%id ctx "%%" op-name-str ":" iface-stx)]
                               [err-tag   (string-append op-name-str ":" iface-name)])
                          (if (null? methods)
                              ;; No method bodies — use C++ default concept.
                              (with-syntax ([register reg-sym]
                                            [op-name-s op-name-str])
                                (per-iface
                                 (cdr entries) defs
                                 (cons #'(register op-name-s #f) calls)))
                              ;; Method bodies — generate dispatch proc + registerConcept.
                              (with-syntax
                                  ([dispatch-proc proc-id]
                                   [op-name-s     op-name-str]
                                   [err-tag-s     err-tag]
                                   [register      reg-sym]
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
                                 (cons #'(define (dispatch-proc method . args)
                                           (let ([method-impl
                                                  (case method
                                                    method-clause ...
                                                    (else #f))])
                                             (unless method-impl
                                               (error err-tag-s
                                                      "method not implemented" method))
                                             (apply method-impl args)))
                                       defs)
                                 (cons #'(register op-name-s dispatch-proc)
                                       calls)))))))))))))

  ;; Build the 12-slot dialect callbacks vector.
  ;; Slot 0 → %%<dialect>:initialize.
  ;; Slot 11 is NOT set here — getRegisteredInterfaceForOp is handled by the
  ;; C++ global op-interface registry populated at initialisation time.
  ;; User-provided slot 11 callback is still honoured as an escape hatch.
  (define (dialect-cbs-with-interfaces ctx dialect-cbs ops)
    (let ([v (list->vector (map (lambda (i) (or (vector-ref dialect-cbs i) #'#f))
                                '(0 1 2 3 4 5 6 7 8 9 10 11)))])
      (vector-set! v 0 (%%id ctx "%%" ctx ":initialize"))
      (vector->list v)))

  ) ;; end library (crest dialect expand interfaces)
