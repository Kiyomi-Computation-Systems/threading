#!r6rs
;; Names that start like rnrs and threading, but are neither.
(library (threading)
  (export f)
  (import (rnrs) (only (threading-testing) describe) (rnrs-extra))
  (define (f x) (describe x)))
