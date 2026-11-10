;; scheme-mlir driver: the TypeID that each interface of the :interfaces clause pairs with its
;; dispatcher is a non-zero address, the same on every call, and different from that of every other
;; interface (C++ finds how to install an interface by it, lib/Crest/Op.cpp).
(import (rnrs)
        (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface::getInterfaceID)
        (only (mlir Interfaces FunctionInterfaces) mlir::FunctionOpInterface::getInterfaceID)
        (only (mlir Interfaces CallInterfaces)
              mlir::CallableOpInterface::getInterfaceID
              mlir::CallOpInterface::getInterfaceID
              mlir::ArgAndResultAttrsOpInterface::getInterfaceID)
        (only (mlir IR SymbolInterfaces) mlir::SymbolOpInterface::getInterfaceID)
        (only (mlir Interfaces SideEffectInterfaces)
              mlir::MemoryEffectOpInterface::getInterfaceID
              mlir::ConditionallySpeculatable::getInterfaceID)
        (only (mlir Transforms InliningUtils) mlir::DialectInlinerInterface::getInterfaceID))

(define getters
  (list (cons 'InferTypeOpInterface mlir::InferTypeOpInterface::getInterfaceID)
        (cons 'FunctionOpInterface mlir::FunctionOpInterface::getInterfaceID)
        (cons 'CallableOpInterface mlir::CallableOpInterface::getInterfaceID)
        (cons 'CallOpInterface mlir::CallOpInterface::getInterfaceID)
        (cons 'ArgAndResultAttrsOpInterface mlir::ArgAndResultAttrsOpInterface::getInterfaceID)
        (cons 'SymbolOpInterface mlir::SymbolOpInterface::getInterfaceID)
        (cons 'MemoryEffectOpInterface mlir::MemoryEffectOpInterface::getInterfaceID)
        (cons 'ConditionallySpeculatable mlir::ConditionallySpeculatable::getInterfaceID)
        (cons 'DialectInlinerInterface mlir::DialectInlinerInterface::getInterfaceID)))

(for-each
 (lambda (entry)
   (let ([id ((cdr entry))])
     (display (list (car entry)
                    (if (and (> id 0) (= id ((cdr entry)))) 'stable 'unstable)))
     (newline)))
 getters)

(let ([ids (map (lambda (entry) ((cdr entry))) getters)])
  (display (if (= (length ids) (length (list-sort < ids)))
               (if (let loop ([l (list-sort < ids)])
                     (or (null? l) (null? (cdr l)) (and (not (= (car l) (cadr l))) (loop (cdr l)))))
                   "distinct"
                   "duplicates")
               "duplicates"))
  (newline))
