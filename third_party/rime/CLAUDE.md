# Claude Instructions for Rime Project

## Bug Fix Workflow

**CRITICAL**: Always reproduce the bug FIRST, then fix it.

When you find a problem in the code:

1. **Create a branch**
   ```bash
   git checkout -b fix-<problem-description>
   ```

2. **Create a test that reproduces the bug**
   - Test should FAIL initially (proving the bug exists)
   - Verify the test actually fails before proceeding
   - **For keyword bugs**: Use standalone tests in `test/standalone/`
   - **For other bugs**: Add unit tests in `test/rime/loop/<feature>-test.sls`

3. **Verify the test fails**
   - Run the test and confirm it fails with the expected error
   - For standalone tests: `make test-standalone`
   - For unit tests: `make test-chez/<feature>-test`
   - Commit the failing test BEFORE fixing

4. **Fix the bug**
   - Make minimal changes to fix the issue
   - Explain root cause before applying fix
   - Update documentation if behavior changes

5. **Verify the fix works**
   - Run the same test - it should now PASS
   - Run full test suite: `make test`
   - Commit the fix

6. **Create a pull request**
   - Write clear commit messages with "Co-Authored-By: Claude <noreply@anthropic.com>"
   - Push branch and create PR
   - Include: what was broken, root cause, how fixed, test evidence

7. **Fix any CI errors**
   - All three platforms must pass: Ubuntu, macOS, Windows
   - Check logs if CI fails
   - Fix and push until all CI passes

## Test Coverage - CRITICAL LESSONS LEARNED

### The Problem

**Unit tests may pass even with bugs due to compilation caching.** This creates a false sense of security.

### Keyword Registration Bugs

Keyword registration bugs (like missing `:step`) are **NOT caught by unit tests** but **ARE caught by standalone scripts**.

**Why**: Chez Scheme's macro expander succeeds during batch compilation even with missing keywords, but fails when loading libraries fresh in standalone scripts.

### Solution: Standalone Tests

For keyword registration bugs, use standalone tests:

1. **Create test** in `test/rime/loop/<feature>-standalone.scm`:
   ```scheme
   #!r6rs
   (import (rnrs (6)) (rime loop))
   (display "Testing :keyword: ")
   (let ([result (loop ... :keyword ...)])
     (if (equal? result expected)
         (begin (display "PASS\n") (exit 0))
         (begin (display "FAIL\n") (exit 1))))
   ```
   
   **Naming convention**: `*-standalone.scm` (not `.sls`)
   - Placed alongside regular tests in `test/rime/loop/`
   - Discovered automatically by `make test-standalone`

2. **Run standalone tests**: `make test-standalone`

3. **CI runs them automatically** on all platforms

### Testing Checklist

For ANY fix, verify with ALL methods:

- ✅ **Standalone test** (for keywords): `make test-standalone`  
- ✅ **Unit test**: `make test-chez/<feature>-test`
- ✅ **Full suite**: `make test`
- ✅ **CI**: All platforms must pass

## Documentation Verification

**CRITICAL**: Always ensure all examples in `doc/loop.md` work in the real world.

- Every code example must be tested with actual Chez Scheme execution
- Include actual output in comments (not guessed output)
- If you update functionality, update ALL affected examples
- Standalone tests can verify documentation examples

## Adding New Keywords

When adding a new keyword (e.g., `:step`):

1. **Add to exports** in `rime/loop/keywords.sls`:
   ```scheme
   (export ... :step ...)
   ```

2. **Add to exports** in `rime/loop.sls`:
   ```scheme
   (export loop ... :step ...)
   ```

3. **Define the keyword** in `rime/loop/keywords.sls`:
   ```scheme
   (define-keyword :step)
   ```

4. **Add to keyword? predicate list** in `rime/loop/keywords.sls`:
   ```scheme
   (define (keyword? e)
     (exists (lambda (keyword) ...)
       (list ... (syntax :step) ...)))
   ```

5. **Implement in plugin** (e.g., `rime/loop/count.sls`):
   ```scheme
   (syntax-case e (:count ... :step ...))
   ```

6. **CREATE STANDALONE TEST FIRST** in `test/rime/loop/<keyword>-standalone.scm`:
   - Naming: `*-standalone.scm` to distinguish from `.sls` unit tests
   - Test should FAIL without keyword registration
   - Proves the bug exists
   - Will pass after fix is applied

7. **Test thoroughly**:
   - Run standalone test - should FAIL initially
   - Apply fix
   - Run standalone test again - should PASS
   - Run full test suite
   - Verify CI passes

## Project Structure

- `rime/loop/` - Loop macro implementation
  - `core.sls` - Parser and code generator
  - `keywords.sls` - Keyword definitions
  - `<feature>.sls` - Individual feature plugins (count, collect, etc.)
- `test/rime/loop/` - Test files
  - `*-test.sls` - Unit tests for each feature
  - `*-standalone.scm` - Standalone script tests (catch keyword bugs)
- `doc/loop.md` - User documentation with examples

## Code Style

- Use evidence-based approach - verify everything
- Ask for approval before applying fixes
- Keep changes minimal and focused
- Document WHY, not just WHAT
- Include real examples with verified output
- Always reproduce bugs before fixing them
