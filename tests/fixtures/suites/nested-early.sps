#!r6rs
(import (rnrs))
(define (f x) (if x (begin (display x) (exit)) 1))
(exit (suite-exit-status runner))
