;; with-LLVMTypeConverter makes the converter and frees it, also when its body ends normally.
(import (rnrs)
        (mlir IR DialectRegistry)
        (mlir IR MLIRContext)
        (mlir Conversion LLVMCommon TypeConverter))

(with-DialectRegistry registry ()
  (with-MLIRContext ctx (registry)
    (with-LLVMTypeConverter converter (ctx)
      (display "converter: ")
      (display (if (zero? converter) "null" "made"))
      (newline))))
