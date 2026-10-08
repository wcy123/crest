# CREST — Conversion and Rewriting Engine for Scheme Transformations

CREST is a homoiconic pattern DSL for MLIR — patterns are Scheme macros, so
constraints and rewrite logic are plain Scheme functions with no C++ escapes
and a seconds-level edit-reload cycle. Unlike [PDL](https://mlir.llvm.org/docs/PDLL/)
and [DRR](https://mlir.llvm.org/docs/DeclarativeRewrites/), CREST generates
both `RewritePattern` and `ConversionPattern` subclasses, covering dialect
conversion passes that neither DSL supports.

## Quick start

```bash
CREST_PATH=$(pwd)/samples cmake --build build --target check-crest
```

Run the sample hip-fusion pass:

```bash
CREST_PATH=/path/to/crest/samples \
  build/tools/crest-opt/crest-opt \
  --crest-pass="module=passes/hip-fusion" \
  my-module.mlir
```

→ See [docs/install.md](docs/install.md) for build instructions.

## Writing a pattern

```scheme
(define-rewrite-pattern (hip-qadd-fusion op rewriter)
  :if-match
    %q       = hip.quantize_linear   (%ctx %sum %out_scale)
      :where (hip-splat-scale? %out_scale)
    %sum     = hip.add               (%ctx %dq_lhs %dq_rhs %init)
      :where (hip-value-single-use? %sum)
    %dq_lhs  = hip.dequantize_linear (%ctx %lhs %lhs_scale)
    %dq_rhs  = hip.dequantize_linear (%ctx %rhs %rhs_scale)
  :then-let
    ([!out-type  (mlir::Value::getType %q)]
     [lhs-scale  (hip-extract-splat-scale %lhs_scale)]
     [out-scale  (hip-extract-splat-scale %out_scale)])
  :rewrite %q :with
    (%result = hip.qadd (%ctx %lhs %rhs %init)
              ("lhs_scale"    = lhs-scale :f32)
              ("output_scale" = out-scale :f32)
              -> !out-type))
```

`:if-match` traverses the def-use graph structurally. `:where` guards are
plain Scheme — any predicate, no C++ required. `:rewrite :with` uses
`begin-mlir-code` to emit new ops with inline attribute modifiers; CREST calls
`replaceOp` automatically. Every emitted op carries a `FileLineColLoc` derived
from its Scheme source position.

## Architecture

```
samples/passes/      — example passes (hip-fusion, onnx-to-hipsr)
scheme/              — core Scheme libraries (mlir IR/dialects/support)
lib/Interpreter/     — Chez Scheme runtime wrapper
lib/Bindings/        — MLIR → Scheme FFI
lib/Passes/          — --crest-pass pipeline registration
tools/crest-opt/     — mlir-opt-style driver
```

→ See [docs/architecture.md](docs/architecture.md) for the full design.

## License

MIT — see [LICENSE](LICENSE).
