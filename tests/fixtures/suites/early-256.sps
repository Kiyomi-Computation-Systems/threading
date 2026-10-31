#!r6rs
(import (rnrs))
(define failures 1)
(when (> failures 0) (exit 256))
(exit (suite-exit-status runner))
