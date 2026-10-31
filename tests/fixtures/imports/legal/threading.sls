#!r6rs
;; Every wrapper an import spec may use, around (rnrs ...) and (threading ...).
(library (threading)
  (export f)
  (import (rnrs)
          (rnrs base (6))
          (only (rnrs lists) filter)
          (except (rnrs) cdr)
          (prefix (threading private) p:)
          (rename (rnrs) (car first))
          (for (rnrs syntax-case) expand)
          (for (only (threading private) helper) run expand)
          (library (rnrs control)))
  (define (f x) (p:helper x)))
