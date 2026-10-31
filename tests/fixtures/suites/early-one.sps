#!r6rs
(import (rnrs))
(define failed #f)
(when failed (exit 1))
(exit (suite-exit-status runner))
