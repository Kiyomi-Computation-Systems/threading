#!r6rs
(library (threading bar)
  (export f)
  (import (rnrs))
  (define (f x) x))
