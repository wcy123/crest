#!r6rs
;;===----------------------------------------------------------------------===;;
;;
;; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
;; Licensed under the MIT License.
;;
;;===----------------------------------------------------------------------===;;
;;
;; (passes hip-fusion fusion) — hip dialect helpers for quantized op fusion patterns.
;;
;; Implements the constraint and attribute-extraction helpers needed by DDR
;; rewrite patterns in (passes hip-fusion).  All logic is pure Scheme built on
;; generic MLIR primitives — no hip-specific C++ is required.
;;
;; The eight functions that hip-ep implements in C++ (Hip.cpp) are re-expressed
;; here using generic MLIR attr/type/operand APIs from (mlir core operation),
;; (mlir ir value), (mlir ir builtin-attributes), and (mlir dialects builtin):
;;   hip-extract-splat-scale         — mlir::DenseElementsAttr::getSplatValue<APFloat>
;;   hip-build-init                  — mlir-build-operation "tensor.empty"
;;   hip-create-requantized-layout-op — mlir-op-clone-with-types
;;   hip-extractable-qdq-zeropoint?  — operand count + mlir::DenseElementsAttr::isSplat
;;   hip-extract-qdq-zeropoint-i64   — mlir-operation-get-integer-attr on zp op
;;   hip-qdq-value-bits-c            — alias for pure-Scheme hip-qdq-value-bits
;;   hip-fusable-conv-geometry?      — integer-array attr reads
;;   hip-l2-equiv-rms-norm?          — epsilon, axis, splat scale vs 1/sqrt(N)
;;
;;===----------------------------------------------------------------------===;;

(library (passes hip-fusion fusion)
  (export
    ;; Single-use guard
    hip-op-single-use?

    ;; Q/DQ operand access (respects AttrSizedOperandSegments)
    hip-qdq-input-operand      ; Value: tensor being quantized/dequantized
    hip-qdq-scale-operand      ; Value: scale
    hip-qdq-zeropoint          ; int64 zero-point or absent-val when absent

    ;; Scale checks
    hip-splat-scale?           ; guard: scale Value is a splat float constant

    ;; Type / width checks
    hip-qdq-element-type       ; element IntegerType of the quantized result
    hip-qdq-value-bits         ; logical bit width (4 when packed_int4, else storage width)
    hip-qdq-unsigned?          ; element type is unsigned
    hip-qdq-quantized-width?   ; bit width is in an allowed set

    ;; Matching helpers
    hip-matching-qdq-params?   ; Q and DQ carry identical scale + zero-point
    hip-identity-roundtrip?    ; Q output type equals DQ input type

    ;; Layout op helpers (for QdqRoundTrip patterns)
    hip-can-requantize-layout-op?  ; op name is in the allowed layout-op list
    hip-layout-op-has-ctx?         ; layout op is a DPS hip op (takes ctx arg)

    ;; Attribute helpers
    hip-int-attr-equal?            ; op's named int attr equals expected value
    hip-l2-equiv-rms-norm?         ; rms_norm is equivalent to L2 normalization
    hip-fusable-conv-geometry?     ; 1x1, unit stride/dilation, no pad, no group
    hip-per-axis-weight?           ; dq is per-axis weight at given rank/axis
    hip-per-channel-weight?        ; dq is per-channel weight for gemm consumer

    ;; Init guard
    hip-can-build-init?        ; result type rank matches shape-source rank

    ;; Value-level single-use check
    hip-value-single-use?

    ;; Zero-point extraction (pure Scheme)
    hip-extractable-qdq-zeropoint?
    hip-extract-qdq-zeropoint-i64
    hip-qdq-value-bits-c

    ;; Scale / builder helpers (pure Scheme)
    hip-extract-splat-scale
    hip-build-init
    hip-create-requantized-layout-op)

  (import (rnrs)
          (only (chezscheme) nan? foreign-procedure)
          (rename (only (mlir ir operation)
                       op-operand-get-value
                       op-result-get-value
                       operation-get-attr
                       operation-get-integer-attr
                       operation-get-integer-array-attr
                       operation-get-name
                       operation-get-num-operands
                       operation-get-result
                       operation-has-attr?)
                 (op-operand-get-value              mlir-operation-get-operand-value)
                 (op-result-get-value               mlir-operation-get-result-value)
                 (operation-get-attr                mlir-operation-get-attribute)
                 (operation-get-integer-attr        mlir-operation-get-integer-attr)
                 (operation-get-integer-array-attr  mlir-operation-get-integer-array-attr)
                 (operation-get-name                mlir-operation-name)
                 (operation-get-num-operands        mlir-operation-num-operands)
                 (operation-get-result              mlir-operation-get-result)
                 (operation-has-attr?               mlir-operation-has-attr?))
          (rename (mlir ir value)
            (get-defining-op   mlir-value-get-defining-op)
            (get-type          mlir-value-get-type)
            (num-uses          mlir-value-num-uses))
          (only (mlir ir builtin-attributes)
                mlir::DenseElementsAttr::isSplat
                mlir::FloatAttr::getValueAsDouble.f32
                mlir::DenseElementsAttr::getSplatValue<APFloat>
                mlir::DenseElementsAttr::getSplatValue<APInt>)
          (only (mlir core builder) mlir-build-op mlir-op-clone-with-types)
          (mlir dialects builtin))

  ;; Local helpers — expressed via explicit builtin-attributes functions.

  ;; Private: fetch a named attr uptr from an op (0 if absent).
  (define %op-get-attr
    (foreign-procedure "mlir_operation_get_attribute" (uptr string) uptr))




  ;;===--------------------------------------------------------------------===;;
  ;; Single-use guard
  ;;===--------------------------------------------------------------------===;;

  ;; Returns #t when op's first result has exactly one use.
  (define (hip-op-single-use? op)
    (= (mlir-value-num-uses (mlir-operation-get-result op 0)) 1))

  ;;===--------------------------------------------------------------------===;;
  ;; Q/DQ operand access
  ;;
  ;; hip.quantize_linear / hip.dequantize_linear operand layout:
  ;;   4 operands: ctx(0), input(1), scale(2), init(3)        — no zero_point
  ;;   5 operands: ctx(0), input(1), scale(2), zp(3), init(4) — has zero_point
  ;;===--------------------------------------------------------------------===;;

  (define (hip-qdq-has-zeropoint? op)
    (= (mlir-operation-num-operands op) 5))

  (define (hip-qdq-input-operand op)
    (mlir-operation-get-operand-value op 1))

  (define (hip-qdq-scale-operand op)
    (mlir-operation-get-operand-value op 2))

  (define (hip-qdq-zeropoint op absent-val)
    (if (hip-qdq-has-zeropoint? op)
        (mlir-operation-get-operand-value op 3)
        absent-val))

  ;;===--------------------------------------------------------------------===;;
  ;; Scale checks
  ;;===--------------------------------------------------------------------===;;

  ;; Returns #t when val's defining op is a hip.constant whose "value" attr
  ;; is a splat DenseElementsAttr.
  (define (hip-splat-scale? val)
    (let ([def (mlir-value-get-defining-op val)])
      (and def
           (string=? (mlir-operation-name def) "hip.constant")
           (let ([a (mlir-operation-get-attribute def "value")])
             (and (not (zero? a))
                  (mlir::DenseElementsAttr::isSplat a))))))

  ;;===--------------------------------------------------------------------===;;
  ;; Type / width checks
  ;;===--------------------------------------------------------------------===;;

  (define (hip-qdq-element-type op)
    ;; Q: result 0 is the integer tensor.
    ;; DQ: operand 1 (input) is the integer tensor; result 0 is float.
    (if (string=? (mlir-operation-name op) "hip.quantize_linear")
        (mlir-type-element-type
          (mlir-value-get-type (mlir-operation-get-result op 0)))
        (mlir-type-element-type
          (mlir-value-get-type (hip-qdq-input-operand op)))))

  (define (hip-qdq-value-bits op)
    ;; packed_int4 is a UnitAttr — test with has-attr?, not get-integer-attr.
    (if (mlir-operation-has-attr? op "packed_int4")
        4
        (mlir-type-integer-width (hip-qdq-element-type op))))

  (define (hip-qdq-unsigned? op)
    (mlir-type-is-unsigned (hip-qdq-element-type op)))

  (define (hip-qdq-quantized-width? op allowed-widths)
    (let ([w (hip-qdq-value-bits op)])
      (and (member w allowed-widths) #t)))

  ;;===--------------------------------------------------------------------===;;
  ;; Matching helpers
  ;;===--------------------------------------------------------------------===;;

  (define (hip-matching-qdq-params? dq-op q-op)
    ;; Same SSA Value pointers mean identical scale and zero-point.
    (let ([dq-scale (hip-qdq-scale-operand dq-op)]
          [q-scale  (hip-qdq-scale-operand q-op)]
          [dq-zp    (hip-qdq-zeropoint dq-op 0)]
          [q-zp     (hip-qdq-zeropoint q-op  0)])
      (and (= dq-scale q-scale)
           (if (and (integer? dq-zp) (integer? q-zp))
               (= dq-zp q-zp)
               (eqv? dq-zp q-zp)))))

  (define (hip-identity-roundtrip? dq-op q-op)
    (= (hip-qdq-element-type dq-op) (hip-qdq-element-type q-op)))

  ;;===--------------------------------------------------------------------===;;
  ;; Layout op helpers
  ;;===--------------------------------------------------------------------===;;

  (define %hip-requantizable-ops
    '("hip.transpose" "tensor.collapse_shape" "tensor.expand_shape"))

  (define (hip-can-requantize-layout-op? layout-op q-op)
    (and (member (mlir-operation-name layout-op) %hip-requantizable-ops) #t))

  (define (hip-layout-op-has-ctx? layout-op)
    ;; DPS hip ops take a ctx as their first operand; pure tensor ops do not.
    (let ([name (mlir-operation-name layout-op)]
          [n    (string-length "hip.")])
      (and (>= (string-length name) n)
           (string=? (substring name 0 n) "hip."))))

  ;;===--------------------------------------------------------------------===;;
  ;; Attribute helpers
  ;;===--------------------------------------------------------------------===;;

  (define (hip-int-attr-equal? op name expected absent-val)
    (= (mlir-operation-get-integer-attr op name absent-val) expected))

  ;; Check whether a hip.rms_norm op is equivalent to L2 normalization:
  ;;   epsilon = 0, axis = last dimension, scale ≈ 1/sqrt(N) in float.
  ;; Mirrors hip_is_l2_equiv_rms_norm in Hip.cpp.
  (define (hip-l2-equiv-rms-norm? op)
    (let ([eps  (let ([a (%op-get-attr op "epsilon")])
                  (if (zero? a) +nan.0 (mlir::FloatAttr::getValueAsDouble.f32 a)))]
          [axis (mlir-operation-get-integer-attr op "axis" -999)])
      (and
        ;; epsilon must be 0.0
        (= eps 0.0)
        ;; axis must be -1 (trailing)
        (= axis -1)
        ;; scale operand must be a splat float hip.constant
        (let ([scale-val (mlir-operation-get-operand-value op 2)])
          (and (hip-splat-scale? scale-val)
               ;; scale value must equal 1/sqrt(N) where N is the last dim
               (let* ([in-type   (mlir-value-get-type
                                   (mlir-operation-get-operand-value op 1))]
                      [rank      (mlir-type-get-rank in-type)]
                      [shape     (mlir-type-get-shape in-type)]
                      [n         (and (> rank 0) (list-ref shape (- rank 1)))])
                 (and n
                      (> n 0)
                      (let* ([expected  (/ 1.0 (sqrt (inexact n)))]
                             [actual    (mlir::DenseElementsAttr::getSplatValue<APFloat>
                                          (mlir-operation-get-attribute
                                            (mlir-value-get-defining-op scale-val)
                                            "value"))]
                             ;; Use relative tolerance to match float rounding.
                             [rel-err   (abs (- actual expected))])
                        (< rel-err (* 2.0 (expt 2.0 -23) (abs expected)))))))))))

  ;; Check whether a hip.conv op has fusable geometry:
  ;; 1x1 kernel, unit strides, unit dilations, zero pads, group=1.
  ;; Mirrors hip_is_fusable_conv_geometry in Hip.cpp.
  (define (hip-fusable-conv-geometry? op)
    (let ([ks    (mlir-operation-get-integer-array-attr op "kernel_shape")]
          [st    (mlir-operation-get-integer-array-attr op "strides")]
          [di    (mlir-operation-get-integer-array-attr op "dilations")]
          [pd    (mlir-operation-get-integer-array-attr op "pads")]
          [group (mlir-operation-get-integer-attr op "group" 0)])
      (and (equal? ks '(1 1))
           (equal? st '(1 1))
           (equal? di '(1 1))
           (equal? pd '(0 0 0 0))
           (= group 1))))

  (define (hip-per-axis-weight? dq-op rank axis packed-int4?)
    ;; Scale must be rank-1 and packed_int4 must match.
    (let* ([scale-val  (hip-qdq-scale-operand dq-op)]
           [scale-rank (mlir-type-get-rank (mlir-value-get-type scale-val))]
           [bits       (hip-qdq-value-bits dq-op)])
      (and (= scale-rank 1)
           (= bits (if packed-int4? 4 8)))))

  (define (hip-per-channel-weight? dq-op q-op)
    (= (mlir-type-get-rank (mlir-value-get-type (hip-qdq-scale-operand dq-op))) 1))

  ;;===--------------------------------------------------------------------===;;
  ;; Init guard
  ;;===--------------------------------------------------------------------===;;

  (define (hip-can-build-init? q-op shape-source)
    (= (mlir-type-get-rank (mlir-value-get-type (mlir-operation-get-result q-op 0)))
       (mlir-type-get-rank (mlir-value-get-type shape-source))))

  ;;===--------------------------------------------------------------------===;;
  ;; Value-level single-use helper
  ;;===--------------------------------------------------------------------===;;

  (define (hip-value-single-use? val)
    (= (mlir-value-num-uses val) 1))

  ;;===--------------------------------------------------------------------===;;
  ;; Zero-point extraction — pure Scheme
  ;;===--------------------------------------------------------------------===;;

  ;; Returns #t when the zero-point is absent (4-operand) or is a splat
  ;; integer hip.constant — i.e. it can be extracted as a scalar i64.
  (define (hip-extractable-qdq-zeropoint? op)
    (if (= (mlir-operation-num-operands op) 4)
        #t
        (let* ([zp-val (mlir-operation-get-operand-value op 3)]
               [def    (mlir-value-get-defining-op zp-val)])
          (and def
               (string=? (mlir-operation-name def) "hip.constant")
               (let ([a (mlir-operation-get-attribute def "value")])
                 (and (not (zero? a))
                      (mlir::DenseElementsAttr::isSplat a)))))))

  ;; Extract zero-point of op as i64.  Returns absent-val when absent.
  ;; Reads the splat integer value from the DenseElementsAttr on the
  ;; hip.constant defining the zero-point operand.
  (define (hip-extract-qdq-zeropoint-i64 op absent-val)
    (if (= (mlir-operation-num-operands op) 4)
        absent-val
        (let* ([zp-val (mlir-operation-get-operand-value op 3)]
               [def    (mlir-value-get-defining-op zp-val)])
          (if (and def (string=? (mlir-operation-name def) "hip.constant"))
              (if (mlir::DenseElementsAttr::isSplat (mlir-operation-get-attribute def "value"))
                  (mlir::DenseElementsAttr::getSplatValue<APInt>
                    (mlir-operation-get-attribute def "value"))
                  absent-val)
              absent-val))))

  ;; Logical quantized bit-width — pure-Scheme alias for hip-qdq-value-bits.
  (define (hip-qdq-value-bits-c op)
    (hip-qdq-value-bits op))

  ;;===--------------------------------------------------------------------===;;
  ;; Scale extraction — pure Scheme via mlir::DenseElementsAttr::getSplatValue<APFloat>
  ;;===--------------------------------------------------------------------===;;

  ;; Extract the splat float64 value from a hip.constant scale Value.
  (define (hip-extract-splat-scale val)
    (mlir::DenseElementsAttr::getSplatValue<APFloat>
      (mlir-operation-get-attribute (mlir-value-get-defining-op val) "value")))

  ;;===--------------------------------------------------------------------===;;
  ;; Init builder — pure Scheme using mlir-build-operation
  ;;===--------------------------------------------------------------------===;;

  ;; Build a tensor.empty whose result type is out-type.
  ;; Uses mlir-build-op directly with the provided rewriter uptr so this works
  ;; both inside and outside the with-rewrite-builder context (e.g. :then-let).
  ;; The loc-op anchor is the defining op of shape-source.
  ;; Returns result Value (index 0) of the new tensor.empty op.
  (define (hip-build-init rewriter out-type shape-source)
    (let ([loc-op (mlir-value-get-defining-op shape-source)])
      (mlir-operation-get-result
        (mlir-build-op rewriter loc-op "tensor.empty" '() (list out-type))
        0)))

  ;;===--------------------------------------------------------------------===;;
  ;; Requantized layout op — pure Scheme via mlir-op-clone-with-types
  ;;===--------------------------------------------------------------------===;;

  ;; Clone layout-op substituting the quantized output type from q-op.
  ;; Works for hip.transpose (has ctx, last operand is DPS init) and
  ;; tensor.{collapse,expand}_shape (no ctx, no init).
  ;; Returns the result Value of the cloned op.
  ;;
  ;; Note: hip.transpose is an unregistered op and does not implement
  ;; DestinationStyleOpInterface, so we detect the init by position:
  ;; for hip.* ops the operand order is [ctx, input(s)..., init] where
  ;; the LAST operand is always the output buffer.
  (define (hip-create-requantized-layout-op rewriter dq-op layout-op q-op)
    (let* ([q-type    (mlir-value-get-type (mlir-operation-get-result q-op 0))]
           [dq-result (mlir-operation-get-result-value dq-op 0)]
           [dq-input  (hip-qdq-input-operand dq-op)]
           [n         (mlir-operation-num-operands layout-op)]
           ;; For hip.* ops the last operand is the DPS init; for tensor.* ops there is none.
           [has-ctx?  (hip-layout-op-has-ctx? layout-op)]
           [init-idx  (if has-ctx? (- n 1) -1)]
           ;; Build a new tensor.empty for the init when needed.
           [new-init  (if has-ctx?
                          (mlir-operation-get-result
                            (mlir-build-op rewriter layout-op
                                           "tensor.empty" '() (list q-type))
                            0)
                          0)]
           ;; Rebuild operand list: replace dq-result with dq-input, and replace
           ;; the last operand (DPS init for hip.*) with the typed init.
           [operands  (let loop ([i 0] [acc '()])
                        (if (= i n)
                            (reverse acc)
                            (let ([v (mlir-operation-get-operand-value layout-op i)])
                              (loop (+ i 1)
                                    (cons (cond
                                            [(= v dq-result) dq-input]
                                            [(= i init-idx)  new-init]
                                            [else v])
                                          acc)))))]
           [new-op    (mlir-op-clone-with-types rewriter layout-op
                                               operands (list q-type))])
      (mlir-operation-get-result new-op 0)))

) ;; end library (passes hip-fusion fusion)
