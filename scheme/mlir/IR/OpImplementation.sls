#!r6rs
;; Mirrors mlir/IR/OpImplementation.h
(library (mlir IR OpImplementation)
  (export mlir::OpAsmPrinter::printString
          mlir::OpAsmPrinter::printOperands
          mlir::OpAsmPrinter::printOperand
          mlir::OpAsmPrinter::printAttribute
          mlir::OpAsmPrinter::printAttributeWithoutType
          mlir::OpAsmPrinter::printType
          mlir::OpAsmPrinter::printOptionalAttrDict
          mlir::OpAsmPrinter::printOptionalAttrDictExcept
          mlir::OpAsmPrinter::printOptionalAttrDict<ArrayRef<StringRef>>
          mlir::OpAsmPrinter::printFunctionalType
          mlir::OpAsmPrinter::printResultTypes
          mlir::OpAsmPrinter::printSymbolName
          mlir::OpAsmPrinter::printRegion
          mlir::StringAttr::getValue
          ;; Parser
          mlir::OpAsmParser::parseOperandList
          mlir::OpAsmParser::parseOperand
          mlir::OpAsmParser::parseOptionalOperand
          mlir::OpAsmParser::resolveOperands
          mlir::OpAsmParser::resolveOperandsFunctional
          mlir::OpAsmParser::parseColonType
          mlir::OpAsmParser::parseType
          mlir::OpAsmParser::parseFunctionalType
          mlir::OpAsmParser::parseOptionalAttrDict
          mlir::OpAsmParser::parseAttribute
          mlir::OpAsmParser::parseAttribute<Type>
          mlir::AsmParser::getContext
          mlir::OpAsmParser::parseKeyword
          mlir::OpAsmParser::parseLParen
          mlir::OpAsmParser::parseRParen
          mlir::OpAsmParser::parseColon
          mlir::OpAsmParser::parseComma
          mlir::OpAsmParser::parseOptionalComma
          mlir::OpAsmParser::parseArrow
          mlir::OpAsmParser::parseLess
          mlir::OpAsmParser::parseGreater
          mlir::OpAsmParser::parseLSquare
          mlir::OpAsmParser::parseRSquare
          mlir::OpAsmParser::parseSymbolName
          mlir::OpAsmParser::emitError
          mlir::isa<FunctionType>
          mlir::OperationState::addType
          mlir::FunctionType::getNumInputs
          mlir::FunctionType::getInput
          mlir::FunctionType::getNumResults
          mlir::FunctionType::getResult)
  (import (rnrs)
          (mlir IR OpImplementation ffi))

  (define mlir::OpAsmPrinter::printString
    %mlir::OpAsmPrinter::printString)

  (define mlir::OpAsmPrinter::printOperands
    %mlir::OpAsmPrinter::printOperands)

  (define mlir::OpAsmPrinter::printOperand
    %mlir::OpAsmPrinter::printOperand)

  (define mlir::OpAsmPrinter::printAttribute
    %mlir::OpAsmPrinter::printAttribute)

  (define mlir::OpAsmPrinter::printAttributeWithoutType
    %mlir::OpAsmPrinter::printAttributeWithoutType)

  (define mlir::OpAsmPrinter::printType
    %mlir::OpAsmPrinter::printType)

  (define mlir::OpAsmPrinter::printOptionalAttrDict
    %mlir::OpAsmPrinter::printOptionalAttrDict)

  (define mlir::OpAsmPrinter::printOptionalAttrDictExcept
    %mlir::OpAsmPrinter::printOptionalAttrDictExcept)

  (define mlir::OpAsmPrinter::printOptionalAttrDict<ArrayRef<StringRef>>
    %mlir::OpAsmPrinter::printOptionalAttrDict<ArrayRef<StringRef>>)

  (define mlir::OpAsmPrinter::printFunctionalType
    %mlir::OpAsmPrinter::printFunctionalType)

  (define mlir::OpAsmPrinter::printResultTypes
    %mlir::OpAsmPrinter::printResultTypes)

  (define mlir::OpAsmPrinter::printSymbolName
    %mlir::OpAsmPrinter::printSymbolName)

  (define mlir::StringAttr::getValue
    %mlir::StringAttr::getValue)

  (define mlir::FunctionType::getNumInputs
    %mlir::FunctionType::getNumInputs)

  (define mlir::FunctionType::getInput
    %mlir::FunctionType::getInput)

  (define mlir::FunctionType::getNumResults
    %mlir::FunctionType::getNumResults)

  (define mlir::FunctionType::getResult
    %mlir::FunctionType::getResult)

  (define mlir::OpAsmPrinter::printRegion
    %mlir::OpAsmPrinter::printRegion)

  ;; ── Parser ─────────────────────────────────────────────────────────────────

  (define mlir::OpAsmParser::parseOperandList    %mlir::OpAsmParser::parseOperandList)
  (define mlir::OpAsmParser::parseOperand         %mlir::OpAsmParser::parseOperand)
  (define mlir::OpAsmParser::parseOptionalOperand %mlir::OpAsmParser::parseOptionalOperand)
  (define mlir::OpAsmParser::resolveOperands     %mlir::OpAsmParser::resolveOperands)
  (define mlir::OpAsmParser::resolveOperandsFunctional %mlir::OpAsmParser::resolveOperandsFunctional)
  (define mlir::OpAsmParser::parseColonType      %mlir::OpAsmParser::parseColonType)
  (define mlir::OpAsmParser::parseType           %mlir::OpAsmParser::parseType)
  (define mlir::OpAsmParser::parseFunctionalType %mlir::OpAsmParser::parseFunctionalType)
  (define mlir::OpAsmParser::parseOptionalAttrDict %mlir::OpAsmParser::parseOptionalAttrDict)
  (define mlir::OpAsmParser::parseAttribute      %mlir::OpAsmParser::parseAttribute)
  (define mlir::OpAsmParser::parseAttribute<Type> %mlir::OpAsmParser::parseAttribute<Type>)
  (define mlir::AsmParser::getContext            %mlir::AsmParser::getContext)
  (define mlir::OpAsmParser::parseKeyword        %mlir::OpAsmParser::parseKeyword)
  (define mlir::OpAsmParser::parseLParen         %mlir::OpAsmParser::parseLParen)
  (define mlir::OpAsmParser::parseRParen         %mlir::OpAsmParser::parseRParen)
  (define mlir::OpAsmParser::parseColon          %mlir::OpAsmParser::parseColon)
  (define mlir::OpAsmParser::parseComma          %mlir::OpAsmParser::parseComma)
  (define mlir::OpAsmParser::parseOptionalComma %mlir::OpAsmParser::parseOptionalComma)
  (define mlir::OpAsmParser::parseArrow          %mlir::OpAsmParser::parseArrow)
  (define mlir::OpAsmParser::parseLess           %mlir::OpAsmParser::parseLess)
  (define mlir::OpAsmParser::parseGreater        %mlir::OpAsmParser::parseGreater)
  (define mlir::OpAsmParser::parseLSquare        %mlir::OpAsmParser::parseLSquare)
  (define mlir::OpAsmParser::parseRSquare        %mlir::OpAsmParser::parseRSquare)
  (define mlir::OpAsmParser::emitError %mlir::OpAsmParser::emitError)
  (define mlir::OpAsmParser::parseSymbolName     %mlir::OpAsmParser::parseSymbolName)
  (define mlir::isa<FunctionType>                %mlir::isa<FunctionType>)
  (define mlir::OperationState::addType          %mlir::OperationState::addType)

  ) ;; end library (mlir IR OpImplementation)
