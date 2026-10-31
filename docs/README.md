# threading

`(threading)` lets you write nested calls in the order they happen.

```scheme
(import (rnrs) (threading))

(~> 1 (+ 2) (* 10))             ; => 30
(~>> '(1 2 3) (append '(0)))    ; => (0 1 2 3)
(~> 1 (+ 2) (list "answer:" _)); => ("answer:" 3)
```

`~>` inserts the previous value first; `~>>` inserts it last.  In either
form, one top-level `_` puts it at that exact spot.  `_` is the ordinary R6RS
binding re-exported from `(rnrs base)`, so a locally bound `_` is just a
variable, not a hole.

`and~>` and `and~>>` work the same way but stop at the first `#f` and answer
that `#f` without running later clauses.

```scheme
(and~> "42" string->number (+ 1)) ; => 43
(and~> #f string->number)          ; => #f
```

`when~>` and `unless~>` choose whether to run a first-threading chain.
`cond~>` chooses its first matching chain, and `tee~>` runs a chain for its
effects while returning the original value.

```scheme
(when~> 1 #t (+ 2))              ; => 3
(unless~> 1 #t (+ 2))            ; => 1
(cond~> 1 (#f (+ 2)) (else (* 3))); => 3
```

The `lambda` forms turn a chain into a procedure.  The `*` variants collect
all arguments into one list.  Every `lambda` name also has a `λ` alias.

```scheme
((lambda~> (+ 2) (* 3)) 2) ; => 12
((λ~>* reverse) 1 2 3)     ; => (3 2 1)
```

See [the reference](reference.md) for the full grammar and every exported
name.
