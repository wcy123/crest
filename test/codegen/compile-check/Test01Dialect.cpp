#include "Test01Dialect.h"
#include "mlir/IR/DialectImplementation.h"

void mlir::test01::Test01Dialect::initialize() {}

#include "../reference/Test01Dialect.cpp.inc.expected"
