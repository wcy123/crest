;; Scheme half of the repro (see repro.c). A Scheme error escapes through a C function:
;;   try -> call-c -> (C) call_scheme -> raise-it -> error -> caught by the guard in try
(define raise-it (lambda () (error 'x "boom")))               ; Scheme code that raises
(define call-c (foreign-procedure "call_scheme" () void))     ; Scheme calls the C function below
(define try (lambda () (guard (c [#t #f]) (call-c))))        ; the guard is outside the C function
