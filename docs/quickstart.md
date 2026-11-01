# Quickstart

Each expression below works after this import:

```scheme
(import (rnrs) (threading))
```

## 1. Thread into the first argument

Use `~>` when the value naturally comes first.

```scheme
(~> 3 (+ 1) (- 2))
;; => 2
```

It reads from left to right, but runs as ordinary nested calls:

```scheme
(- (+ 3 1) 2)
;; => 2
```

An identifier is a short clause, so `string->number` means
`(string->number value)`. A list is a call with the value inserted after its
first item: `(+ 1)` means `(+ value 1)`.

## 2. Thread into the last argument

Use `~>>` when the collection or accumulated value belongs at the end.

```scheme
(~>> '(1 2) (append '(0)) reverse)
;; => (2 1 0)
```

That is `(reverse (append '(0) '(1 2)))`.

## 3. Put the value exactly where it belongs

One top-level `_` overrides both defaults.

```scheme
(~> 3 (+ 1) (- 2 _))
;; => -2
```

The last clause becomes `(- 2 4)`. A nested `_` is ordinary data, and so is a
locally bound `_`; only the `_` imported from `(rnrs base)` at a clause's top
level is a hole.

## 4. Stop when a step fails

`and~>` and `and~>>` are for a pipeline where `#f` means “no result.” They
return that `#f` and skip the remaining clauses.

```scheme
(and~> "42" string->number (+ 1))
;; => 43

(and~> "not a number" string->number (+ 1))
;; => #f
```

`(+ 1)` does not run in the second expression.

## 5. Choose a chain

`when~>` threads only when its test is true; `unless~>` does the opposite.
When a test says not to run, each returns the original value.

```scheme
(when~> 1 #t (+ 2))
;; => 3

(unless~> 1 #t (+ 2))
;; => 1
```

`cond~>` chooses the first matching chain. With no match and no `else`, it
also returns the original value.

```scheme
(cond~> 1
  (#f (+ 2))
  (else (* 3)))
;; => 3
```

## 6. Take a side trip

`tee~>` runs a first-threading chain for its effects, then returns the value
it started with.

```scheme
(let ((seen #f))
  (list (tee~> 3 (set! seen _)) seen))
;; => (3 3)
```

This is useful for logging, storing a value, or checking it without changing
the rest of a pipeline.

## 7. Make a reusable chain

The `lambda` forms turn clauses into a procedure. The `*` forms collect all
their arguments into one list before threading.

```scheme
((lambda~> (+ 2) (* 3)) 2)
;; => 12

((lambda~>* reverse) 1 2 3)
;; => (3 2 1)
```

Each `lambda` form also has a `λ` alias, such as `λ~>`.

See the [API reference](reference.md) for every form, its grammar, and the
syntax errors malformed clauses raise.
