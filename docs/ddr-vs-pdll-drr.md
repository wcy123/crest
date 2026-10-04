<!--
Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
Licensed under the MIT License.
-->

**Date:** 2026-10-01
**Document Type:** Tech Note
**Status:** Draft
**Related:** [MLIR Dialect Conversion](https://mlir.llvm.org/docs/DialectConversion/), [MLIR PDLL](https://mlir.llvm.org/docs/PDLL/)

---

# DDR vs. MLIR DRR and PDLL

## Overview

This note compares the CREST DDR (Declarative Dialect Rewriting) against
MLIR's two established pattern DSLs —
[DRR](https://mlir.llvm.org/docs/DeclarativeRewrites/) (TableGen-based) and
[PDLL](https://mlir.llvm.org/docs/PDLL/) — for writing dialect conversion
patterns. The comparison is scoped to the onnx→HipSR lowering pass.

---

## Analysis

### Capability: Dialect Conversion

[PDLL documents this limitation explicitly](https://mlir.llvm.org/docs/PDLL/#planned-features):

> *"Planned but missing PDLL features include: Support for use in dialect conversion (no RFC yet)"*

DRR has the same limitation. Neither generates
[`ConversionPattern`](https://mlir.llvm.org/docs/DialectConversion/#conversion-patterns)
subclasses.

The onnx→HipSR pass uses
[`applyFullConversion`](https://mlir.llvm.org/docs/DialectConversion/#conversion-patterns)
with a `TypeConverter`. Every pattern receives type-converted operands via
`ConversionPatternRewriter`. DDR's `SchemeConversionPattern` inherits from
`mlir::ConversionPattern` and is the only DSL-based approach that supports
this today.

### Edit-Test Loop

| Approach | Steps to test a pattern change |
|---|---|
| DRR | Edit `.td` → run `mlir-tblgen` → rebuild binary |
| PDLL | Edit `.pdll` → run `mlir-pdll` → include header → rebuild binary |
| DDR | Edit `.sls` → reload |

PDLL requires `mlir-pdll` installed and version-matched to the MLIR build.
DDR requires no additional tools beyond Chez Scheme.

### Constraints and Rewrites

PDLL's `Constraint` and `Rewrite` declarations are backed by C++ `native`
blocks — C++ code embedded inside the `.pdll` file. DRR uses `NativeCodeCall`
(C++ string escapes). CREST embeds DDR in Scheme: the `:where` clause and
`:rewrite` body accept any Scheme expression. A named Scheme function serves
the same purpose without C++:

```scheme
;; Named constraint — callable from any pattern:
(define (device-tensor? v)
  (= 1 (mlir-type-is-device-tensor (mlir-value-get-type v))))

;; Usage in match:
(define-conversion-pattern (lower-op op operands-ref rw tc)
  %op = "my.op" (%data)
  :where (device-tensor? %data)
  :rewrite ...)
```

### Turing-Complete Pattern Computation

DRR and PDLL require C++ escapes for complex pattern logic (axis
normalization, shape broadcasting, `operandSegmentSizes` construction from
memory addresses). CREST expresses this in Scheme, in the same file as the
pattern, with no C++ required.

### Debugging

DDR provides `:debug-codegen` (prints the generated Scheme lambda) and
`:debug-matching` (traces execution at runtime). DRR and PDLL require gdb or
compile-time instrumentation.

### Deployment

| Property | DRR | PDLL | DDR |
|---|---|---|---|
| Patterns in binary | Yes | Yes | Yes ([boot mode](architecture.md#boot-mode--dcrest_embed_scheme_booton)) |
| Cold-start cost | Zero | Zero | ~100–200ms (first `import`, cached after) |
| Out-of-sync failure | Build error | Build error | Runtime failure |

In [boot mode](architecture.md#boot-mode--dcrest_embed_scheme_booton), `.sls`
files are compiled into the binary at build time; the cold-start cost and
out-of-sync failure mode no longer apply.

### FFI Maintenance

Each MLIR API function used from Scheme requires a C++ `Sregister_symbol`
registration and a Scheme `foreign-procedure` declaration. DRR and PDLL
operate within MLIR's type system and have no equivalent cost. The
`foreign-entry?` dynamic dispatch partially mitigates this for attribute types.

### Summary

| Dimension | DRR | PDLL | DDR |
|---|---|---|---|
| [Dialect conversion](https://mlir.llvm.org/docs/DialectConversion/#conversion-patterns) | No | [No](https://mlir.llvm.org/docs/PDLL/#planned-features) | **Yes** |
| Edit→test loop | Rebuild | Rebuild | **Reload** |
| Extra toolchain | `mlir-tblgen` | `mlir-pdll` + `mlir-tblgen` | **None** |
| Constraints without C++ | No | No | **Yes** |
| Turing-complete computation | Via C++ | Via C++ | **Native Scheme** |
| Interactive debugging | No | No | **Yes** |
| Patterns in binary | Yes | Yes | **Yes (boot mode)** |
| FFI maintenance burden | None | None | Real |

---

## Conclusion

DDR is the only DSL-based option for dialect conversion patterns today. PDLL
and DRR cannot generate `ConversionPattern` subclasses.

Within dialect conversion use cases, embedding DDR in Scheme provides
advantages over hypothetical future PDLL dialect-conversion support: no C++
required for constraints or rewrites, reload-based edit–test cycle, and
runtime debugging.

The two operational costs — FFI maintenance burden and (in development mode)
filesystem coupling — are engineering discipline problems, not language design
problems. Boot mode eliminates the filesystem coupling.

---

## Related Documents

- [MLIR PDLL](https://mlir.llvm.org/docs/PDLL/) — PDLL language reference and known limitations
- [MLIR Dialect Conversion](https://mlir.llvm.org/docs/DialectConversion/) — `ConversionPattern` and `TypeConverter`
- [MLIR Declarative Rewrites (DRR)](https://mlir.llvm.org/docs/DeclarativeRewrites/) — TableGen-based rewrite DSL
