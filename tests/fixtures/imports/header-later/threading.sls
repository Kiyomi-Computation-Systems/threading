;; the header is not on the first line
#!r6rs
(library (threading)
  (export f)
  (import (rnrs))
  (define (f x) x))
