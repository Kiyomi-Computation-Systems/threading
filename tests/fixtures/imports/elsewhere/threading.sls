#!r6rs
;; (threading chez) is no file here: on a path with another directory that
;; holds it, Chez would load that one.
(library (threading)
  (export f)
  (import (rnrs) (only (threading chez) helper))
  (define (f x) (helper x)))
