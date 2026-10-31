#!r6rs
(import (rnrs))
(define v `#(,(exit 0)))
(define w `(a . #(,(exit 2))))
(exit (suite-exit-status runner))
