(library (mlir codegen)
  (export
    define-dialect
    text
    main)
  (import
   (chezscheme)
   (mlir codegen dialect-dsl)
   (mlir codegen dialect-gen)
   (mlir codegen cpp-printer))

  ;; Join multiple strings with newlines — for multi-line dialect descriptions.
  (define (text . lines)
    (let loop ([lines lines])
      (if (null? (cdr lines))
          (car lines)
          (string-append (car lines) "\n" (loop (cdr lines))))))

  ;; Entry point for dialect code generation scripts.
  ;; dialects  — list of dialect records defined in the script
  ;; args      — (cdr (command-line)), expected to contain flags and a subcommand
  ;;
  ;; Subcommands:
  ;;   decl    — emit dialect declaration (.h.inc)
  ;;   def     — emit dialect definition (.cpp.inc)
  ;;
  ;; Future flags (not yet implemented):
  ;;   -I <path>          — include search path
  ;;   -o <dir>           — output directory
  (define (main dialects args)
    (define (usage)
      (error "mlir codegen" "Usage: <script> [decl|def]"))
    (cond
     [(or (null? args) (equal? (car args) "decl"))
      (for-each
       (lambda (d)
         (display (sexp->cpp (generate-dialect-decl d))))
       dialects)]
     [(equal? (car args) "def")
      (for-each
       (lambda (d)
         (display (sexp->cpp (generate-dialect-def d))))
       dialects)]
     [else (usage)])))
