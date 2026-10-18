;; Expand-phase helper for (crest op) macros.
;; Imported at (for ... expand) so it is available inside macro transformers.
(library (crest op expand)
  (export expand-op-defs)
  (import (chezscheme)
          (mlir IR Operation))

  ;; Returns a list of (define ...) syntax objects for a single op.
  ;; ctx         — syntax object used as datum->syntax context
  ;; full-name   — string e.g. "toy.constant"
  ;; op-plist    — datum list: (:operands (...) :attributes (...) :results (...))
  (define (expand-op-defs ctx full-name op-plist)
    (define (extract-kw kw plist default)
      (let loop ([rest plist])
        (cond [(null? rest)        default]
              [(eq? (car rest) kw) (cadr rest)]
              [else                (loop (cddr rest))])))
    (let* ([operands   (extract-kw ':operands   op-plist '())]
           [attributes (extract-kw ':attributes op-plist '())]
           [results    (extract-kw ':results    op-plist '())]
           [make-id    (lambda (sfx)
                         (datum->syntax ctx
                                        (string->symbol
                                         (string-append full-name ":" sfx))))]
           [pred-id    (datum->syntax ctx
                                      (string->symbol
                                       (string-append full-name "?")))])
      (append
       (list (with-syntax ([?pred pred-id] [n full-name])
               #'(define (?pred op)
                   (string=? (mlir::Operation::getName op) n))))
       (let loop ([fs operands] [i 0])
         (if (null? fs) '()
             (cons (with-syntax ([id (make-id (symbol->string (caar fs)))] [idx i])
                     #'(define (id op) (mlir::Operation::getOperand op idx)))
                   (loop (cdr fs) (+ i 1)))))
       (map (lambda (f)
              (with-syntax ([id    (make-id (symbol->string (car f)))]
                            [aname (symbol->string (car f))])
                #'(define (id op) (mlir::Operation::getAttr op aname))))
            attributes)
       (let loop ([fs results] [i 0])
         (if (null? fs) '()
             (cons (with-syntax ([id (make-id (symbol->string (caar fs)))] [idx i])
                     #'(define (id op) (mlir::Operation::getResult op idx)))
                   (loop (cdr fs) (+ i 1))))))))
  )
