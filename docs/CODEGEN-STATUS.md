# CREST Code Generation - Status and Roadmap

**Last Updated:** 2026-10-17  
**PR:** #115  
**Status:** Foundation Complete, Testing Infrastructure Ready

---

## What's Done

### ✅ Phase 1: Dialect Code Generation (Complete)

**Implementation:**
- [x] Semantic model (\`dialect\` record type)
- [x] User DSL (\`define-dialect\` macro)
- [x] C++ code generation (declarations + definitions)
- [x] S-expression to C++ printer
- [x] Example: HIP dialect

**Testing:**
- [x] Regression test infrastructure
- [x] Automated test runner
- [x] Reference output management
- [x] First test case (Arith dialect)

**Documentation:**
- [x] Design document (architecture, philosophy)
- [x] User guide (API reference, integration)
- [x] Tutorial (5 lessons, hands-on)

**Total Effort:** ~5 days (as estimated)

---

## What's Next

### ⏳ Phase 2: Operation Definitions (3-4 weeks)

**Goal:** Generate operation C++ classes from Scheme definitions

**Example:**
\`\`\`scheme
(define-mlir-op hip.conv
  :arguments [(Hip_ContextType \$ctx)
              (Hip_Tensor \$input)
              (Hip_Tensor \$weights)
              (Optional Hip_Tensor \$bias)
              (Hip_Tensor \$output)]
  :results [(Hip_Tensor \$result)]
  :traits [NoMemoryEffect DPS_Op]
  :assembly-format (seq \$ctx \",\" \$input \",\" \$weights
                        (optional-group \",\" \$bias)
                        (attr-dict)
                        \":\" (type-of \$result))
  :verify (lambda (op)
            (check-conv-shapes op 'input 'weights 'output)))
\`\`\`

**Tasks:**
- [ ] \`dag\` type representation in Scheme
- [ ] Operand/result handling
- [ ] Optional/variadic operands
- [ ] Trait system integration
- [ ] Assembly format DSL (composable S-expressions, not strings)
- [ ] Verifier code generation
- [ ] Builder generation
- [ ] Regression tests vs TableGen ODS

**Challenges:**
- Assembly format: most complex feature
- Verifier: need to generate C++ from Scheme predicates
- Operand segments: \`operandSegmentSizes\` attribute handling

### ⏳ Phase 3: Type/Attribute Definitions (2-3 weeks)

\`\`\`scheme
(define-mlir-type Hip_QuantizedTensor
  :parameters [(IntegerType \$element-type)
               (FloatAttr \$scale)
               (IntegerAttr \$zero-point)]
  :assembly-format \"<\" \$element-type \",\" \$scale \",\" \$zero-point \">\")

(define-mlir-attr Hip_ConvConfig
  :parameters [(I64ArrayAttr \$kernel-shape)
               (I64ArrayAttr \$strides)
               (I64ArrayAttr \$pads)]
  :assembly-format \"<\" \$kernel-shape \",\" \$strides \",\" \$pads \">\")
\`\`\`

**Tasks:**
- [ ] Type definition macro
- [ ] Attribute definition macro
- [ ] Parameter handling
- [ ] Assembly format for types/attrs
- [ ] Storage class generation

### ⏳ Phase 4: CMake Integration (1 week)

\`\`\`cmake
# CMake helper function
add_crest_dialect(HIP hip-ops.sls)

# Generates:
#   HipDialect.h.inc
#   HipDialect.cpp.inc
#   HipOps.h.inc
#   HipOps.cpp.inc
\`\`\`

**Tasks:**
- [ ] \`add_crest_dialect()\` CMake function
- [ ] Dependency tracking
- [ ] Incremental builds
- [ ] Parallel generation
- [ ] Fallback to TableGen if CREST not available

### ⏳ Phase 5: Standalone Tool (1-2 weeks)

\`\`\`bash
# Command-line tool (like mlir-tblgen)
crest-tblgen --gen-op-decls hip-ops.sls > HipOps.h.inc
crest-tblgen --gen-op-defs hip-ops.sls > HipOps.cpp.inc
\`\`\`

**Tasks:**
- [ ] CLI argument parsing
- [ ] Multi-file support
- [ ] Include paths
- [ ] Error reporting
- [ ] \`--help\` documentation

---

## Testing Status

### Regression Tests

**Framework:** ✅ Complete
- Test runner: \`test/codegen/run-all-tests.sh\`
- Reference management
- Diff reporting
- CI integration ready

**Coverage:**

| Feature | Test Case | Status |
|---------|-----------|--------|
| Basic dialect | Arith dialect | ✅ Framework ready |
| Dependencies | Tensor dialect | ⏳ Needs reference |
| Extra class decl | Custom dialect | ⏳ Needs reference |
| Operations | hip.conv | ❌ Phase 2 |
| Types | Hip_QuantizedTensor | ❌ Phase 3 |

**To Complete Phase 1 Testing:**
1. Generate TableGen references from MLIR upstream
2. Run: \`cd test/codegen && ./run-all-tests.sh\`
3. Fix any discrepancies
4. Add CI/CD workflow

---

## Documentation Status

### ✅ Complete

- **Design Document** (\`codegen-design.md\`): 500 lines
  - Architecture explanation
  - TableGen comparison
  - Homoiconicity rationale
  - Extension points

- **User Guide** (\`codegen-user-guide.md\`): 400 lines
  - Installation
  - API reference
  - Integration (CMake/Bazel)
  - Best practices

- **Tutorial** (\`codegen-tutorial.md\`): 300 lines
  - 5 progressive lessons
  - Hands-on exercises
  - External data integration

### ⏳ To Add (Phase 2+)

- Operation definition guide
- Assembly format DSL reference
- Migration guide (TableGen → CREST)
- Performance comparison
- Troubleshooting cookbook

---

## Validation Checklist

### Before Claiming \"Production Ready\"

**Phase 1 (Dialects):**
- [ ] All regression tests pass
- [ ] Byte-for-byte match with TableGen for basic dialects
- [ ] CI/CD running on every commit
- [ ] At least 3 dialect test cases

**Phase 2 (Operations):**
- [ ] 10+ operation test cases
- [ ] All assembly format features covered
- [ ] Verifier generation validated
- [ ] Build and run MLIR tests with generated code

**Phase 3 (Types/Attrs):**
- [ ] 5+ type test cases
- [ ] 5+ attribute test cases
- [ ] Parameterized types working

**Phase 4 (Integration):**
- [ ] CMake integration tested in real MLIR project
- [ ] Build times measured vs TableGen
- [ ] Incremental builds working

**Phase 5 (Production):**
- [ ] Used in at least one AMD dialect
- [ ] Performance benchmarks published
- [ ] Migration guide written
- [ ] Upstream LLVM discussion started

---

## Estimated Timeline

| Phase | Duration | Start | Complete |
|-------|----------|-------|----------|
| **Phase 1: Dialects** | 5 days | 2026-10-17 | **✅ 2026-10-17** |
| **Phase 2: Operations** | 3-4 weeks | 2026-10-18 | ~2026-11-15 |
| **Phase 3: Types/Attrs** | 2-3 weeks | 2026-11-16 | ~2026-12-05 |
| **Phase 4: CMake** | 1 week | 2026-12-06 | ~2026-12-13 |
| **Phase 5: CLI Tool** | 1-2 weeks | 2026-12-14 | ~2026-12-27 |
| **Production Validation** | 2-3 weeks | 2027-01-01 | ~2027-01-21 |

**Total:** ~14-16 weeks from start to production-ready

**Current:** Week 1, Phase 1 complete

---

## Success Criteria

### Minimum Viable Product (MVP)

**Defined as:** Can generate a complete custom dialect end-to-end

**Requirements:**
- ✅ Dialect definitions
- ⏳ Operation definitions
- ⏳ Basic types/attributes
- ⏳ CMake integration
- ⏳ Regression tests pass
- ⏳ Used in one real project

**Timeline:** End of Phase 4 (~12 weeks)

### Production Ready

**Defined as:** AMD teams can use for new dialects instead of TableGen

**Requirements:**
- All MVP requirements
- Performance on par with TableGen
- Complete documentation
- CI/CD integration
- Support commitment

**Timeline:** End of Phase 5 (~16 weeks)

---

## Risks and Mitigation

### Risk 1: Assembly Format Complexity

**Problem:** TableGen's assembly format DSL is complex, many edge cases

**Mitigation:**
- Start with subset (positional operands only)
- Add features incrementally
- Extensive regression testing
- Can fallback to string for complex cases

### Risk 2: Byte-for-Byte Match Unrealistic

**Problem:** May never match TableGen exactly (whitespace, comments)

**Mitigation:**
- Define \"acceptable differences\" policy
- Focus on semantic equivalence
- Normalize whitespace in comparison
- Document intentional differences

### Risk 3: Maintenance Burden

**Problem:** MLIR/TableGen evolves, CREST must keep up

**Mitigation:**
- Automated regression tests catch changes
- Subscribe to MLIR commits/discussions
- Version lock to specific MLIR release
- Community contributions

### Risk 4: Performance

**Problem:** Scheme might be slower than C++ for code generation

**Mitigation:**
- Measure early (Phase 2)
- Optimize hot paths
- Compile Scheme to binary
- Parallelize generation
- Cache compiled .sls files

---

## Community and Adoption

### Feedback Channels

- **GitHub Issues:** Bug reports, feature requests
- **GitHub Discussions:** Questions, ideas
- **PR Reviews:** Code quality, architecture
- **LLVM Discourse:** When ready for upstream discussion

### Adoption Strategy

1. **Internal (AMD):** Use in HIP/VAIP dialects first
2. **Early Adopters:** Projects needing custom dialects
3. **LLVM Discourse:** Present results, gather feedback
4. **Gradual Expansion:** More features based on demand

**Not aiming for:** Upstream LLVM replacement of TableGen (unrealistic)

**Aiming for:** Viable alternative for custom dialects

---

## How to Contribute

### Testing

1. Generate TableGen references from MLIR dialects
2. Add test cases in \`test/codegen/dialects/\`
3. Run regression tests
4. Report discrepancies

### Documentation

1. Improve tutorials with real-world examples
2. Add troubleshooting entries
3. Write migration guides
4. Create video walkthroughs

### Implementation

1. Phase 2: Operation definitions
2. Phase 3: Type/attribute definitions
3. Phase 4: CMake integration
4. Phase 5: CLI tool

See \`CONTRIBUTING.md\` (to be created)

---

## Questions?

- **Technical:** Open GitHub issue
- **Usage:** Check tutorial/user guide
- **Design:** Read design document
- **Feedback:** GitHub Discussions

**PR #115:** https://github.com/wcy123/crest/pull/115
