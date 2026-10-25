;; Interface registration code generator for define-dialect ops.
;; Generates per-op dispatcher functions and crest::registerInterfaceForOperation
;; calls at dialect initialisation time.
;; The C++ global op-interface registry in Dialect.cpp handles lookups at runtime.
(library (crest dialect expand interfaces)
  (export generate-interface-registrations
          dialect-cbs-with-interfaces)
  (import (chezscheme)
          (crest dialect ast)
          (crest dialect expand utils)
          (crest dialect ffi))

  ;; Map interface name → TypeID accessor symbol in client scope.
  ;; Validates that the interface is supported; errors at expansion time otherwise.
  (define (%%iface-id-sym-for ctx entry)
    (let ([name (%%id->str (interface-entry-name entry))])
      (cond
       [(string=? name "mlir::FunctionOpInterface")
        (%%id ctx 'crest::FunctionOpInterface::getInterfaceID)]
       [else
        (syntax-violation ':interfaces
                          (string-append "unsupported interface — only mlir::FunctionOpInterface is supported: " name)
                          (interface-entry-name entry))])))

  ;; Generate per-op dispatcher defines and crest::registerInterfaceForOperation
  ;; calls for ALL ops that declare :interfaces entries.
  ;;
  ;; Returns (values (list define-stx ...) (list setup-call-stx ...)).
  ;; define-stxs go at top level; setup-calls go into %%<dialect>:initialize.
  ;;
  ;; Generated dispatcher shape:
  ;;   (define (%%toy.func:mlir::FunctionOpInterface method)
  ;;     (case method
  ;;       ((id)             (crest::FunctionOpInterface::getInterfaceID))
  ;;       ((operation_name) "toy.func")
  ;;       ((getFunctionType) (lambda (self) ...))   ; if declared
  ;;       ...
  ;;       (else #f)))
  ;;
  ;; The C++ registerInterfaceForOperation calls the dispatcher with each
  ;; symbol at registration time to build the concept.
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
                               ;; %%toy.func:mlir::FunctionOpInterface
                               [proc-id   (%%id ctx "%%" op-name-str ":" iface-stx)]
                               [id-sym    (%%iface-id-sym-for ctx entry)]
                               [register  (%%id ctx 'crest::registerInterfaceForOperation)])
                          (with-syntax
                              ([dispatch-proc proc-id]
                               [get-id        id-sym]
                               [op-name-s     op-name-str]
                               [reg           register]
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
                                         ((id)             (get-id))
                                         ((operation_name) op-name-s)
                                         method-clause ...
                                         (else #f)))
                                   defs)
                             (cons #'(reg dispatch-proc)
                                   calls))))))))))))

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
