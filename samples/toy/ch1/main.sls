#!/usr/bin/env bash
# Toy Ch1 compiler entry point — delegates to tools/toyc.
# Usage: main.sls <input.toy> [--emit=ast]
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && git -C . rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "${BASH_SOURCE[0]}")/../..")/tools/toyc-ch1" "$@"
