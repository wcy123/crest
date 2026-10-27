;; Interface registration code generator for define-dialect ops.
;; Generates per-op dispatcher functions and interface registration calls
;; at dialect initialisation time.
;; The C++ global op-interface registry in Dialect.cpp handles lookups at runtime.
;;
;; An interface is a function that accepts a dispatch function (dispatcher).
;; The interface name in the DSL (e.g. mlir::FunctionOpInterface) IS the
;; Scheme function that takes the dispatcher and registers the C++ concept.
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
  ;; Registration call (interface name IS the registration function):
  ;;   (mlir::FunctionOpInterface %%toy.func:mlir::FunctionOpInterface)
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
                        (let* ([entry     (car entries)]
                               [iface-stx (interface-entry-name entry)]
                               [methods   (interface-entry-methods entry)]
                               ;; %%toy.func:mlir::FunctionOpInterface
                               [proc-id   (%%id ctx "%%" op-name-str ":" iface-stx)]
                               ;; Create a fresh identifier in ctx's scope so the
                               ;; generated call resolves in the client module.
                               [iface-fn-id (%%id ctx iface-stx)])
                          (with-syntax
                              ([dispatch-proc proc-id]
                               [iface-fn      iface-fn-id]
                               [op-name-s     op-name-str]
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
                             (cons #'(iface-fn dispatch-proc)
                                   calls))))))))))))

  ;; Build the 12-slot dialect callbacks vector.
  ;; Slot 0 → %%<dialect>:initialize (registers interface concepts).
  (define (dialect-cbs-with-interfaces ctx dialect-cbs ops)
    (let ([v (list->vector (map (lambda (i) (or (vector-ref dialect-cbs i) #'#f))
                                '(0 1 2 3 4 5 6 7 8 9 10 11)))])
      (vector-set! v 0 (%%id ctx "%%" ctx ":initialize"))
      (vector->list v)))

  ) ;; end library (crest dialect expand interfaces)
