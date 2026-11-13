// The docs must not name an API that CREST has removed (`register_binding`) or the old
// hyphenated Scheme names (`mlir-value-get-type`): a reader would copy them and fail.
//
// RUN: python3 %S/check-stale-names.py %S/../.. %S/../../scheme %S/../../samples

module {}
