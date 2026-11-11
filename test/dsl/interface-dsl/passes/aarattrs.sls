#!r6rs
;; An op whose ArgAndResultAttrsOpInterface is the standard one: it keeps arg_attrs and res_attrs.
(library (passes aarattrs)
  (export aarattrs)
  (import (chezscheme)
          (crest dialect)
          (mlir IR Operation)
          (only (mlir Interfaces CallInterfaces) mlir::ArgAndResultAttrsOpInterface))

  (define-dialect aarattrs
    (define-op fn
      :interfaces ((mlir::ArgAndResultAttrsOpInterface :standard)))))
