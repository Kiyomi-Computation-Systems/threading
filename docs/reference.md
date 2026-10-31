# Reference

Import the library with:

```scheme
(import (rnrs) (threading))
```

## Clauses

A clause is one of:

- An identifier, such as `reverse`.
- A quoted datum, such as `'name`. It expands as a procedure call and therefore
  raises the usual run-time error if the datum is not a procedure.
- A non-empty proper list, such as `(append '(0))`.

Normally `~>` inserts the current value after the list's first item, and `~>>`
appends it. A list with exactly one top-level `_` uses that position instead.
Nested `_` values are not holes. Two top-level holes, an empty or improper
list, and every other datum are syntax errors.

## Threading forms

`(~> value clause ...)`

: Thread `value` through each `clause` as its first argument. With no clauses,
  it expands to `value`.

`(~>> value clause ...)`

: Thread `value` through each `clause` as its last argument. With no clauses,
  it expands to `value`.

`(and~> value clause ...)` and `(and~>> value clause ...)`

: Like the matching threading form, but evaluate each result once and stop at
  the first `#f`. With no clauses, each expands to `value`.

`(when~> value test clause ...)`

: Evaluate `value`, then `test`. When `test` is true, thread the value through
  the clauses as `~>` does; otherwise answer the original value.

`(unless~> value test clause ...)`

: Evaluate `value`, then `test`. When `test` is false, thread the value through
  the clauses as `~>` does; otherwise answer the original value.

`(cond~> value (test clause ...) ... (else clause ...))`

: Evaluate `value` once, then tests from left to right. Thread its value through
  the first matching clause body. An `else` clause is optional; without one,
  no matching test answers the original value. `else` must be last and uses the
  ordinary R6RS `else` binding, so a locally bound variable named `else` is a
  normal test.

`(tee~> value clause ...)`

: Evaluate `value` once, thread it through the clauses for their effects, then
  answer the original value. With no clauses, it answers that value unchanged.

## Procedure forms

`(lambda~> clause ...)`, `(lambda~>> clause ...)`,
`(lambda-and~> clause ...)`, `(lambda-and~>> clause ...)`

: Expand to a one-argument procedure that threads its argument with `~>`,
  `~>>`, `and~>`, or `and~>>`, respectively.

`(lambda~>* clause ...)`, `(lambda~>>* clause ...)`,
`(lambda-and~>* clause ...)`, `(lambda-and~>>* clause ...)`

: Expand to a rest-argument procedure. Its received arguments are one list,
  then threaded with the matching form.

`λ~>`, `λ~>>`, `λ-and~>`, `λ-and~>>`, `λ~>*`, `λ~>>*`,
`λ-and~>*`, and `λ-and~>>*`

: Aliases for the matching `lambda` forms. They are the same bindings.

`_`

: Re-export of `(rnrs base)`'s `_`. A top-level use of that binding inside a
  clause marks the insertion point.
