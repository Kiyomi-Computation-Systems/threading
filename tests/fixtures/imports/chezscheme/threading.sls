#!r6rs
(library (threading)
  (export f)
  (import (rnrs) (chezscheme))
  (define (f x) x))
