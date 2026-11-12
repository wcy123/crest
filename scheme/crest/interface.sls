#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (crest interface) — what the macro of an interface of an op does (the entries of the :interfaces
;; clause of define-op), written once.
;;
;; An interface macro, say (mlir::CallableOpInterface clause ...), answers the pair of the TypeID of the
;; interface and a dispatcher: from the name of a method to the entry point of a callable that Scheme
;; made once, when the library was loaded, which C++ puts in the slot of the Concept of the op
;; (lib/Crest/Interface.h). The macro of an interface only says what its methods are:
;;
;;   (define-syntax mlir::XInterface
;;     (lambda (stx)
;;       (op-interface-expand stx 'mlir::XInterface #'(mlir::XInterface::getInterfaceID)
;;         #'((method (kind ...) result adapter default keywords) ...))))
;;
;;   method    the name of the method of the Concept
;;   kind...   the C++ types of its arguments after the op, and result the C++ type of its answer,
;;             as crest-slot-callable (scheme/crest/callback.sls) takes them
;;   adapter   #f, or a procedure from the procedure of the clause to the procedure that the slot
;;             calls with the numbers and lists of the kinds (it turns a list of types into a range,
;;             a verdict into 1 or 0 with a diagnostic, ...)
;;   default   #f when the op has to give the method; else what stands for the method of an op that
;;             does not give it, which is what MLIR does when it has a default for it: a procedure,
;;             or (cpp expression) for a C function that CREST ships (its address)
;;   keywords  an alist ((:keyword . (scheme procedure)) or (:keyword . (cpp entry-point)) ...): a
;;             clause (method :keyword) is the procedure, or the C function that CREST ships for a
;;             slot that Scheme cannot implement. :standard is special: (X :standard clause ...) uses
;;             the :standard of every method that has no clause.
;;
;; The clauses are checked when the library compiles: a missing clause, a clause with a method that
;; the interface does not have, two clauses for one method, and a clause that does not take the
;; arguments of the method are errors.
;;
;;===----------------------------------------------------------------------===;;
(library (crest interface)
  (export op-interface-expand)
  (import (chezscheme)
          (crest callback))

  (define (op-interface-expand stx interface-name id table)
    (define (violation message . subform)
      (syntax-violation ':interfaces
                        (string-append (symbol->string interface-name) " " message)
                        stx
                        (if (null? subform) #f (car subform))))

    (define (keyword? datum)
      (and (symbol? datum)
           (let ([name (symbol->string datum)])
             (and (> (string-length name) 1) (char=? (string-ref name 0) #\:)))))

    ;; A method of the table: (name kinds result adapter default keywords).
    (define-record-type method
      (fields name kinds result adapter default keywords))

    (define methods
      (map (lambda (entry)
             (syntax-case entry ()
               [(name (kind ...) result adapter default keywords)
                (make-method (syntax->datum #'name) #'(kind ...) #'result #'adapter #'default
                             (map (lambda (pair)
                                    (syntax-case pair ()
                                      [(keyword . value) (cons (syntax->datum #'keyword) #'value)]))
                                  (syntax->list #'keywords)))]))
           (syntax->list table)))

    (define (find-method name)
      (let loop ([rest methods])
        (cond [(null? rest) #f]
              [(eq? (method-name (car rest)) name) (car rest)]
              [else (loop (cdr rest))])))

    (define (method-names)
      (apply string-append
             (let loop ([rest methods] [first? #t])
               (if (null? rest)
                   '()
                   (cons (string-append (if first? "" ", ") (symbol->string (method-name (car rest))))
                         (loop (cdr rest) #f))))))

    (define (no-default? m)
      (eq? (syntax->datum (method-default m)) #f))

    (define forms (cdr (syntax->list stx)))
    (define standard? (and (pair? forms) (eq? (syntax->datum (car forms)) ':standard)))
    (define clauses (if standard? (cdr forms) forms))

    ;; clause: a pair of the method and what stands for its procedure, as syntax:
    ;;   (scheme . expression) | (cpp . expression)
    (define parsed
      (map (lambda (clause)
             (syntax-case clause ()
               [(name (formal ...) body ...)
                (identifier? #'name)
                (let ([m (find-method (syntax->datum #'name))])
                  (unless m
                    (violation (string-append "has no method " (symbol->string (syntax->datum #'name))
                                              ": its methods are " (method-names))
                               clause))
                  (unless (= (length (syntax->list #'(formal ...))) (length (syntax->list (method-kinds m))))
                    (violation (string-append "takes (op ...) with "
                                              (number->string (length (syntax->list (method-kinds m))))
                                              " argument(s) in the clause of "
                                              (symbol->string (method-name m)))
                               clause))
                  (list m 'scheme #'(lambda (formal ...) body ...) clause))]
               [(name keyword)
                (and (identifier? #'name) (keyword? (syntax->datum #'keyword)))
                (let ([m (find-method (syntax->datum #'name))])
                  (unless m
                    (violation (string-append "has no method " (symbol->string (syntax->datum #'name))
                                              ": its methods are " (method-names))
                               clause))
                  (let ([found (assq (syntax->datum #'keyword) (method-keywords m))])
                    (unless found
                      (violation (string-append (symbol->string (method-name m)) " has no "
                                                (symbol->string (syntax->datum #'keyword)))
                                 clause))
                    (syntax-case (cdr found) ()
                      [(kind expression) (list m (syntax->datum #'kind) #'expression clause)])))]
               [_ (violation "clauses are written (method (op ...) body ...) or (method :keyword)"
                             clause)]))
           clauses))

    (define (duplicates!)
      (let loop ([rest parsed])
        (unless (null? rest)
          (when (memq (method-name (car (car rest)))
                      (map (lambda (p) (method-name (car p))) (cdr rest)))
            (violation (string-append "has two clauses for "
                                      (symbol->string (method-name (car (car rest)))))
                       (cadddr (car rest))))
          (loop (cdr rest)))))

    ;; What stands for the method: (scheme . expression), (cpp . expression) or #f.
    (define (source m)
      (let ([given (find (lambda (p) (eq? (car p) m)) parsed)])
        (cond
         [given (cons (cadr given) (caddr given))]
         [(and standard? (assq ':standard (method-keywords m)))
          => (lambda (found)
               (syntax-case (cdr found) ()
                 [(kind expression) (cons (syntax->datum #'kind) #'expression)]))]
         [(not (no-default? m))
          (syntax-case (method-default m) (cpp)
            [(cpp expression) (cons 'cpp #'expression)]
            [procedure (cons 'scheme #'procedure)])]
         [else #f])))

    (define (entry m)
      (let ([from (source m)])
        (unless from
          (violation (string-append "needs a clause for " (symbol->string (method-name m)))
                     stx))
        (if (eq? (car from) 'cpp)
            (cdr from)
            (let ([procedure (if (eq? (syntax->datum (method-adapter m)) #f)
                                 (cdr from)
                                 #`(#,(method-adapter m) #,(cdr from)))])
              #`(crest-slot-callable #,(method-kinds m) #,(method-result m) #,procedure
                                     :source #,(cdr from))))))

    (duplicates!)
    (for-each (lambda (m)
                (unless (source m)
                  (violation (string-append "needs a clause for " (symbol->string (method-name m)))
                             stx)))
              methods)
    (with-syntax ([((name entry) ...)
                   (map (lambda (m) (list (datum->syntax (car (syntax->list stx)) (method-name m)) (entry m)))
                        methods)])
      #`(cons #,id (crest-callback-entry-dispatcher (list (cons 'name entry) ...)))))

  ) ;; end library (crest interface)
