#!r6rs
(import (rnrs))
(define forms '((exit 0) (quit exit)))
(exit (suite-exit-status runner))
