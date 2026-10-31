#!r6rs
;; (rnrs eval)'s environment reaches (chezscheme) at run time, with no
;; (chezscheme) import.
(library (threading)
  (export f)
  (import (rnrs) (rnrs eval) (only (rnrs eval (6)) environment))
  (define (f x) ((eval 'printf (environment '(chezscheme))) "~s" x)))
