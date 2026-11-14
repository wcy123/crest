;; scheme-mlir driver: the bindings that make LLVM dialect ops (a global string, its address, a GEP to its first
;; character, a constant, a function declaration) and look a symbol up in the module. Each of them was named by no other
;; test; the Toy lowering writes the same ops with begin-mlir-code. The module is printed.
(import (rnrs)
        (mlir IR DialectRegistry) (mlir IR MLIRContext) (mlir IR OwningOpRef) (mlir IR Operation)
        (mlir IR Builders) (mlir IR BuiltinOps) (mlir IR Location) (mlir IR BuiltinTypes) (mlir IR BuiltinAttributes)
        (mlir Dialect LLVMIR IR LLVMDialect) (mlir Dialect LLVMIR IR LLVMOps))

(with-DialectRegistry reg ()
  (mlir::DialectRegistry::insert<mlir::LLVM::LLVMDialect> reg)
  (with-MLIRContext ctx (reg)
    (with-current-MLIRContext ctx
      (mlir::MLIRContext::getOrLoadDialect ctx "llvm")
      (let* ([loc (mlir::UnknownLoc::get ctx)]
             [i8 (mlir::IntegerType::get<i8>)]
             [i32 (mlir::IntegerType::get<i32>)]
             [pointer (mlir::LLVM::LLVMPointerType::get ctx)]
             [text-type (mlir::LLVM::LLVMArrayType::get i8 6)])
        (with-mlir::OwningOpRef module (mlir::ModuleOp::create loc)
          (with-OpBuilder builder (mlir::OpBuilder::atBlockEnd (mlir::ModuleOp::getBody module))
            (let* ([printf-type (mlir::LLVM::LLVMFunctionType::get ctx i32 pointer 1)]
                   [printf (mlir::LLVM::LLVMFuncOp::create builder loc "printf" printf-type)]
                   [global (mlir::LLVM::GlobalOp::create builder loc text-type 1 8 "greeting"
                                                         (mlir::StringAttr::get ctx "hello\x0;"))]
                   [address (mlir::LLVM::AddressOfOp::create builder loc global)]
                   [zero (mlir::LLVM::ConstantOp::create<i64> builder loc 0)]
                   [first (mlir::LLVM::GEPOp::create builder loc pointer text-type address zero zero)])
              (display "found the global by name: ")
              (display (if (= global (mlir::ModuleOp::lookupSymbol module "greeting")) "yes" "no"))
              (newline)
              (display "found the function by name: ")
              (display (if (= printf (mlir::ModuleOp::lookupSymbol module "printf")) "yes" "no"))
              (newline)
              (display "type of the global is the array: ")
              (display (if (= text-type (mlir::LLVM::GlobalOp::getType global)) "yes" "no"))
              (newline)))
          (display (mlir::Operation::print module)))))))
