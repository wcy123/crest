;; Interface dispatch code generator for define-dialect ops.
;; Generates the auto :get-registered-interface-for-op implementation
;; from :interfaces clauses declared on individual ops.
(library (crest dialect expand interfaces)
  (export generate-interface-dispatch
          generate-scheme-dispatch-defs
          dialect-cbs-with-interfaces)
  (import (chezscheme)
          (crest dialect ast)
          (crest dialect expand utils)
          (crest dialect ffi))

  ;; Map from interface-entry → concept-provider identifier in client scope.
  ;; Validates that the interface name is supported; errors at expansion time otherwise.
  (define (%%concept-provider-for ctx entry)
    (let ([name (%%id->str (interface-entry-name entry))])
      (cond
       [(string=? name "mlir::FunctionOpInterface")
        (if (null? (interface-entry-methods entry))
            (%%id ctx 'crest::FunctionOpInterface::getConcept)
            (%%id ctx 'crest::FunctionOpInterface::getSchemeConceptPtr))]
       [else
        (syntax-violation ':interfaces
                          (string-append "unsupported interface for :interfaces — only mlir::FunctionOpInterface is supported: " name)
                          (interface-entry-name entry))])))

  ;; Generate %%<dialect>:get-registered-interface-for-op-auto.
  ;; Returns a define syntax object, or #f when no op declares :interfaces.
  ;;
  ;; Generated shape:
  ;;   (define (%%toy:get-registered-interface-for-op-auto iface-id op-name)
  ;;     (let ([op-name (%mlir::OperationName::getStringRef op-name)])
  ;;       (cond [(string=? op-name "toy.func")
  ;;              (let try ([ps (list provider ...)])
  ;;                (if (null? ps) 0
  ;;                    (let ([r ((car ps) iface-id)])
  ;;                      (if (zero? r) (try (cdr ps)) r))))]
  ;;             ...
  ;;             [else 0])))
  (define (generate-interface-dispatch ctx ops)
    (let* ([op-prefix (string-append (%%id->str ctx) ".")]
           [entries
            (filter (lambda (e) (not (null? (cdr e))))
                    (map (lambda (op)
                           (cons (string-append op-prefix (%%id->str (op-parse-name op)))
                                 (op-parse-interfaces op)))
                         ops))])
      (and (not (null? entries))
           (with-syntax
               ([auto-fn (%%id ctx "%%" ctx ":get-registered-interface-for-op-auto")]
                [getref  #'%mlir::OperationName::getStringRef]
                [(clause ...)
                 (map (lambda (entry)
                        (with-syntax
                            ([name-str (car entry)]
                             [(prov ...)
                              (map (lambda (e) (%%concept-provider-for ctx e)) (cdr entry))])
                          #'[(string=? op-name name-str)
                             (let try ([ps (list prov ...)])
                               (if (null? ps) 0
                                   (let ([r ((car ps) iface-id)])
                                     (if (zero? r) (try (cdr ps)) r))))]))
                      entries)])
             #'(define (auto-fn iface-id op-name)
                 (let ([op-name (getref op-name)])
                   (cond clause ... [else 0])))))))

  ;; Generate per-op Scheme dispatch procedure defines and their registration
  ;; calls for ops whose :interfaces entries have method bodies.
  ;;
  ;; Returns (values (list define-stx ...) (list setup-call-stx ...)).
  ;; define-stxs go at top level; setup-calls go into %%<dialect>:initialize.
  (define (generate-scheme-dispatch-defs ctx ops)
    (let ([op-prefix (string-append (%%id->str ctx) ".")])
      (let loop ([ops ops] [defs '()] [calls '()])
        (if (null? ops)
            (values (reverse defs) (reverse calls))
            (let* ([op          (car ops)]
                   [op-name-str (string-append op-prefix (%%id->str (op-parse-name op)))]
                   [iface-entries
                    (filter (lambda (e) (not (null? (interface-entry-methods e))))
                            (op-parse-interfaces op))])
              (if (null? iface-entries)
                  (loop (cdr ops) defs calls)
                  ;; For each interface-entry with methods, generate a dispatch proc.
                  (let per-iface ([entries iface-entries] [defs defs] [calls calls])
                    (if (null? entries)
                        (loop (cdr ops) defs calls)
                        (let* ([entry     (car entries)]
                               [iface-stx (interface-entry-name entry)]
                               [_         (unless (string=? (%%id->str iface-stx)
                                                            "mlir::FunctionOpInterface")
                                            (syntax-violation ':interfaces
                                                              "method bodies only supported for mlir::FunctionOpInterface"
                                                              iface-stx))]
                               [methods  (interface-entry-methods entry)]
                               ;; %%toy.func:mlir::FunctionOpInterface
                               [proc-id  (%%id ctx "%%" op-name-str ":" iface-stx)])
                          (with-syntax
                              ([dispatch-proc proc-id]
                               [parent-iface  iface-stx]
                               [op-name-s     op-name-str]
                               [set-dispatch  (%%id ctx 'crest::FunctionOpInterface::setSchemeDispatch)]
                               [(method-clause ...)
                                (map (lambda (m)
                                       (with-syntax
                                           ([mname   (datum->syntax ctx (interface-method-name m))]
                                            [formals (interface-method-formals m)]
                                            [body    (interface-method-body m)])
                                         #'((mname) (apply (lambda formals . body) args))))
                                     methods)])
                            (per-iface
                             (cdr entries)
                             (cons #'(define (dispatch-proc method . args)
                                       (case method
                                         method-clause ...
                                         (else (apply parent-iface method args))))
                                   defs)
                             (cons #'(set-dispatch op-name-s dispatch-proc)
                                   calls))))))))))))

  ;; Build the 12-slot dialect callbacks vector with:
  ;;   slot 0  wired to %%<dialect>:initialize
  ;;   slot 11 combining auto-dispatch with user-provided (auto first, user fallback)
  (define (dialect-cbs-with-interfaces ctx dialect-cbs ops)
    (let* ([v           (list->vector (map (lambda (i) (or (vector-ref dialect-cbs i) #'#f))
                                           '(0 1 2 3 4 5 6 7 8 9 10 11)))]
           [auto-fn-stx (%%id ctx "%%" ctx ":get-registered-interface-for-op-auto")]
           [user-iface  (vector-ref dialect-cbs 11)]
           [has-ifaces  (exists (lambda (op) (not (null? (op-parse-interfaces op)))) ops)])
      (vector-set! v 0 (%%id ctx "%%" ctx ":initialize"))
      (when has-ifaces
        (vector-set! v 11
                     (if user-iface
                         (with-syntax ([auto auto-fn-stx] [user user-iface])
                           #'(lambda (iface-id op-name)
                               (let ([r (auto iface-id op-name)])
                                 (if (zero? r) (user iface-id op-name) r))))
                         auto-fn-stx)))
      (vector->list v)))

  ) ;; end library (crest dialect expand interfaces)
