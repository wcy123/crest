#!r6rs
;; A Scheme dialect with types that exercise what dt (dialect-types) does not: no parameters, a
;; verifier that answers #f, a parser that fails and a verifier that raises a Scheme error.
(library (passes tcb)
  (export tcb)
  (import (except (rnrs) =)
          (mlir IR Value)
          (mlir IR OpImplementation)
          (crest dialect))

  (define-dialect tcb
    ;; No parameters: the text after the name is empty, and so is the list.
    (define-type empty
      (:parse (parser) '())
      (:print (printer params) #t))
    ;; The verifier says no without saying why: MLIR's own message.
    (define-type bad
      (:verify (params) #f)
      (:parse (parser) '())
      (:print (printer params) #t))
    (define-type broken
      (:parse (parser)
        (mlir::OpAsmParser::emitError parser "this type cannot be parsed")
        #f)
      (:print (printer params) #t))
    (define-type raises
      (:verify (params) (error 'verify "the type verifier is broken"))
      (:parse (parser) '())
      (:print (printer params) #t))
    (define-op make
      :results ((out tcb.empty?)))))
