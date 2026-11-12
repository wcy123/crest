;; Test driver for scheme-mlir: checks that every C symbol the Scheme sources name is registered
;; (CLAUDE.md Rule 14). It reads every .sls file under the Scheme roots and looks for
;;   (foreign-procedure "name" ...)                          the symbol "name"
;;   (crest-foreign-procedure "name" ...)                    the symbol "name", which C++ registered with
;;                                                           register_binding (it answers a Scheme object)
;;   (define-builder-binding var "name" ...)                 the three variants NAME<OpBuilder>,
;;                                                           NAME<RewriterBase*>, NAME<OpBuilder*>
;; and asks Chez whether each is a registered entry. A symbol that C++ registered with register_binding must
;; be called through crest-foreign-procedure, and one that it did not through foreign-procedure: the two
;; sides read the answer differently, and a mismatch is a crash, not an error. A missing symbol raises "no entry" when the
;; library is instantiated, so it stays hidden until a pass imports that library; this finds it in
;; every library, including ones nothing imports yet.
;;
;; Usage: scheme-mlir check-ffi-symbols.sls <scheme-dir>
(import (chezscheme))

(define (ends-with? s suffix)
  (let ([n (string-length s)] [m (string-length suffix)])
    (and (>= n m) (string=? (substring s (- n m) n) suffix))))

(define (sls-files dir)
  (apply append
         (map (lambda (entry)
                (let ([full (string-append dir "/" entry)])
                  (cond [(file-directory? full) (sls-files full)]
                        [(ends-with? entry ".sls") (list full)]
                        [else '()])))
              (directory-list dir))))

(define (read-all path)
  (call-with-input-file path
    (lambda (port)
      (let loop ([forms '()])
        (let ([form (guard (e [#t (eof-object)]) (read port))])
          (if (eof-object? form) (reverse forms) (loop (cons form forms))))))))

;; every (entry . source-file) a form tree names
(define (entries form file)
  (cond
   [(and (pair? form) (memq (car form) '(foreign-procedure crest-foreign-procedure))
         (pair? (cdr form)) (string? (cadr form)))
    (list (list (cadr form) file (car form)))]
   [(and (pair? form) (eq? (car form) 'define-builder-binding)
         (pair? (cdr form)) (pair? (cddr form)) (string? (caddr form)))
    (let* ([name (caddr form)]
           [n (string-length name)]
           [with-kind (lambda (kind)
                        (if (char=? (string-ref name (- n 1)) #\>)
                            (string-append (substring name 0 (- n 1)) "," kind ">")
                            (string-append name "<" kind ">")))])
      (map (lambda (kind) (list (with-kind kind) file 'define-builder-binding))
           '("OpBuilder" "RewriterBase*" "OpBuilder*")))]
   [(pair? form) (append (entries (car form) file) (entries (cdr form) file))]
   [else '()]))

(define scheme (car (command-line-arguments)))
(define seen (make-hashtable string-hash string=?))
(define answers-object? (foreign-procedure "crest::bindings::answersObject" (string) int))
(define missing 0)

(for-each
 (lambda (file)
   (for-each
    (lambda (form)
      (for-each
       (lambda (entry)
         (let ([name (car entry)])
           (unless (hashtable-ref seen name #f)
             (hashtable-set! seen name #t)
             (cond
              [(not (foreign-entry? name))
               (set! missing (+ missing 1))
               (display "NOT REGISTERED ") (write name)
               (display " in ") (display (cadr entry)) (newline)]
              [(and (eq? (caddr entry) 'foreign-procedure) (= 1 (answers-object? name)))
               (set! missing (+ missing 1))
               (display "REGISTERED WITH register_binding, CALLED WITH foreign-procedure ") (write name)
               (display " in ") (display (cadr entry)) (newline)]
              [(and (memq (caddr entry) '(crest-foreign-procedure define-builder-binding))
                    (= 0 (answers-object? name)))
               (set! missing (+ missing 1))
               (display "CALLED WITH crest-foreign-procedure (or define-builder-binding), NOT REGISTERED WITH register_binding or register_builder_binding ") (write name)
               (display " in ") (display (cadr entry)) (newline)]))))
       (entries form file)))
    (read-all file)))
 (sls-files scheme))

(display (list 'symbols (hashtable-size seen) 'missing missing))
(newline)
(exit (if (zero? missing) 0 1))
