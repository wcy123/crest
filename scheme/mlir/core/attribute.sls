#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (mlir core attribute) — MLIR attribute API.
;;
;; Four generic functions cover all attribute operations:
;;
;;   (mlir-make-attr [:ctx] :type value) → attr-uptr
;;     Construct an attribute. :type is a symbol like 'i64, 'f32, etc.
;;     Discovers mlir_make_attr_<type> dynamically — no Scheme change needed
;;     for new types.  Optional ctx defaults to (current-mlir-context).
;;
;;   (mlir-attr-isa attr-uptr :type) → #t/#f
;;     Type predicate. Discovers mlir_attr_isa_<type> dynamically.
;;
;;   (mlir-attr-as attr-uptr :type) → scheme-val
;;     Fast scalar extraction (scalars only). Discovers mlir_attr_as_<type>.
;;     Signals error on type mismatch — caught by DDR guard → match failure.
;;
;;   (mlir-attr-into attr-uptr :type) → scheme-val
;;     General conversion (may allocate). Discovers mlir_attr_into_<type>.
;;     For complex types: :i32-array → list, :splat-float → flonum, etc.
;;
;; Type keywords (identifier-syntax) expand at compile time to plain symbols:
;;   :i64 ≡ 'i64,  :f32 ≡ 'f32,  etc.
;;   Runtime symbols also accepted: (let ([ty 'i64]) (mlir-attr-isa attr ty))
;;
;; C++ convention: all *_<type> families share uniform per-family signatures
;; so Scheme discovers them automatically via foreign-entry?.
;;
;;===----------------------------------------------------------------------===;;

(library (mlir core attribute)
  (export
    ;; Four generic functions
    mlir-make-attr
    mlir-attr-isa
    mlir-attr-as
    mlir-attr-into
    :i32 :i64 :f32 :f64 :index
    :integer :float :string
    :opaque     ; parse MLIR attr syntax string → attr uptr (OpaqueAttr or real if dialect loaded)
    :dense-elements :dense-elements-splat
    :splat-float :splat-integer
    :i32-array :i64-array :dense-resource)

  (import (rnrs)
          (only (chezscheme) foreign-procedure foreign-entry?
                make-eq-hashtable hashtable-ref hashtable-set!)
          (mlir core context))

  ;;===--------------------------------------------------------------------===;;
  ;; Type keyword identifier-syntax
  ;;===--------------------------------------------------------------------===;;
  (define-syntax :i32            (identifier-syntax 'i32))
  (define-syntax :i64            (identifier-syntax 'i64))
  (define-syntax :f32            (identifier-syntax 'f32))
  (define-syntax :f64            (identifier-syntax 'f64))
  (define-syntax :index          (identifier-syntax 'index))
  (define-syntax :opaque         (identifier-syntax 'opaque))
  (define-syntax :integer        (identifier-syntax 'integer))
  (define-syntax :float          (identifier-syntax 'float))
  (define-syntax :string         (identifier-syntax 'string))
  (define-syntax :dense-elements       (identifier-syntax 'dense-elements))
  (define-syntax :dense-elements-splat (identifier-syntax 'dense-elements-splat))
  (define-syntax :splat-float          (identifier-syntax 'splat-float))
  (define-syntax :splat-integer        (identifier-syntax 'splat-integer))
  (define-syntax :i32-array      (identifier-syntax 'i32-array))
  (define-syntax :i64-array      (identifier-syntax 'i64-array))
  (define-syntax :dense-resource (identifier-syntax 'dense-resource))

  ;;===--------------------------------------------------------------------===;;
  ;; Open-ended lookup infrastructure
  ;;===--------------------------------------------------------------------===;;

  ;; Convert type symbol to C suffix: 'dense-elements → "dense_elements"
  ;; Also accepts legacy colon-prefixed symbols: ':i64 → "i64" (strips leading ':')
  (define (type->c-body type)
    (let* ([s (symbol->string type)]
           [s (if (and (> (string-length s) 0) (char=? (string-ref s 0) #\:))
                  (substring s 1 (string-length s))
                  s)])
      (list->string (map (lambda (c) (if (char=? c #\-) #\_ c)) (string->list s)))))

  ;; Unique sentinel: "not yet looked up" vs "looked up, not found" (#f).
  (define %uncached (list 'uncached))

  ;; Factory: open-ended lookup by C symbol name convention.
  (define (make-lookup prefix make-proc)
    (let ([cache (make-eq-hashtable)])
      (lambda (type)
        (let ([cached (hashtable-ref cache type %uncached)])
          (if (eq? cached %uncached)
              (let* ([sym  (string-append prefix (type->c-body type))]
                     [proc (and (foreign-entry? sym) (make-proc sym))])
                (hashtable-set! cache type proc)
                proc)
              cached)))))

  (define %lookup-make
    (make-lookup "mlir_make_attr_"
                 (lambda (sym) (foreign-procedure sym (uptr scheme-object) uptr))))
  (define %lookup-isa
    (make-lookup "mlir_attr_isa_"
                 (lambda (sym) (foreign-procedure sym (uptr) int))))
  (define %lookup-as
    (make-lookup "mlir_attr_as_"
                 (lambda (sym) (foreign-procedure sym (uptr) scheme-object))))
  (define %lookup-into
    (make-lookup "mlir_attr_into_"
                 (lambda (sym) (foreign-procedure sym (uptr) scheme-object))))

  ;;===--------------------------------------------------------------------===;;
  ;; mlir-make-attr
  ;;===--------------------------------------------------------------------===;;
  (define mlir-make-attr
    (case-lambda
      [(type value)
       (mlir-make-attr (or (current-mlir-context)
                           (error 'mlir-make-attr
                                  "no ctx and current-mlir-context is unset"))
                       type value)]
      [(ctx type value)
       (let ([proc (%lookup-make type)])
         (if proc
             (proc ctx value)
             (error 'mlir-make-attr "unknown or unavailable attr type" type)))]))

  ;;===--------------------------------------------------------------------===;;
  ;; mlir-attr-isa
  ;;===--------------------------------------------------------------------===;;
  (define mlir-attr-isa
    (case-lambda
      ;; (mlir-attr-isa :integer) → curried predicate; errors if type unknown.
      [(type)
       (let ([proc (%lookup-isa type)])
         (unless proc (error 'mlir-attr-isa "unknown attr type" type))
         (lambda (attr) (not (zero? (proc attr)))))]
      ;; (mlir-attr-isa attr :integer) → direct predicate.
      [(attr type)
       ((mlir-attr-isa type) attr)]))

  ;;===--------------------------------------------------------------------===;;
  ;; mlir-attr-as
  ;;===--------------------------------------------------------------------===;;

  (define mlir-attr-as
    (case-lambda
      ;; (mlir-attr-as :f32) → curried extractor.
      ;; Lookup done once here; the returned lambda closes over the resolved procs.
      ;; Errors immediately if the type is unknown or has no as-extractor.
      [(type)
       (let ([isa-proc (%lookup-isa type)]
             [as-proc  (%lookup-as  type)])
         (unless isa-proc (error 'mlir-attr-as "unknown attr type" type))
         (unless as-proc  (error 'mlir-attr-as "zero-overhead access not supported for type" type))
         (lambda (attr)
           (if (not (zero? (isa-proc attr)))
               (as-proc attr)
               (error 'mlir-attr-as "attribute is not of type" type))))]
      ;; (mlir-attr-as attr :f32) → apply the curried form immediately.
      ;; Delegates to the 1-arg arm: lookup is done once, no code duplication.
      [(attr type)
       ((mlir-attr-as type) attr)]))

  ;;===--------------------------------------------------------------------===;;
  ;; mlir-attr-into
  ;;===--------------------------------------------------------------------===;;
  (define mlir-attr-into
    (case-lambda
      ;; (mlir-attr-into :splat-float) → curried converter; errors if type unknown.
      [(type)
       (let ([proc (%lookup-into type)])
         (unless proc (error 'mlir-attr-into "no into-converter registered for type" type))
         (lambda (attr) (proc attr)))]
      ;; (mlir-attr-into attr :splat-float) → direct conversion.
      [(attr type)
       ((mlir-attr-into type) attr)]))

) ;; end library (mlir core attribute)
