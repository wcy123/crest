;; scheme-mlir driver: the TypeID of mlir::InferTypeOpInterface that :interface2 pairs with a dispatcher is
;; a stable, non-zero address: the same on every call, and the one C++ looks the attach function up by.
(import (rnrs)
        (only (mlir Interfaces InferTypeOpInterface) mlir::InferTypeOpInterface::getInterfaceID))

(define id (mlir::InferTypeOpInterface::getInterfaceID))
(display (if (and (> id 0) (= id (mlir::InferTypeOpInterface::getInterfaceID))) "stable" "unstable"))
(newline)
