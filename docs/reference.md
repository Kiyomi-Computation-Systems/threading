# API reference

Everything `(threading)` exports, one entry each. Import it with:

```scheme
(import (rnrs) (threading))
```

The forms below are syntax. `value` and `test` stand for expressions;
`clause ...` means zero or more clauses. The expansion sketches describe the
resulting call shape, not a second syntax you need to write.

The library itself imports only `(rnrs)`. Its public syntax has no Chez
extension, so an implementation with standard R6RS libraries should load
`src/threading.sls` as `(threading)`. The repository's development suite is
run on Chez alone.

## Clauses

A clause takes the value from the step before it.

| You write | `~>` makes | `~>>` makes |
|:--|:--|:--|
| `f` | `(f value)` | `(f value)` |
| `(f a ...)` | `(f value a ...)` | `(f a ... value)` |
| `(f a ... _ b ...)` | `(f a ... value b ...)` | the same |

A quoted datum, such as `'name`, is also accepted and becomes an application
of that datum. In ordinary R6RS that raises the usual run-time error because a
quoted datum is not a procedure.

`_` is a hole only when it is the re-exported `(rnrs base)` binding at the
clause's top level. A nested or locally bound `_` is an ordinary value. A
clause may have at most one top-level hole. A number, string, boolean,
character, vector, bytevector, empty list, or improper list is a
`syntax-violation`.

## Direct chains

### `~>`

```text
(~> value clause ...) -> Any
```

Threads `value` through the clauses as their first argument. With no clauses,
answers `value`.

### `~>>`

```text
(~>> value clause ...) -> Any
```

Threads `value` through the clauses as their last argument. With no clauses,
answers `value`.

### `and~>`

```text
(and~> value clause ...) -> Any
```

Like `~>`, but stops at the first result that is `#f`. It evaluates each result
once and does not run later clauses after that `#f`.

### `and~>>`

```text
(and~>> value clause ...) -> Any
```

Like `~>>`, with the same `#f` short-circuiting as `and~>`.

## Conditional chains

### `when~>`

```text
(when~> value test clause ...) -> Any
```

Evaluates `value`, then `test`. When `test` is true, threads the value as
`~>` does; otherwise answers the original value.

### `unless~>`

```text
(unless~> value test clause ...) -> Any
```

Evaluates `value`, then `test`. When `test` is false, threads the value as
`~>` does; otherwise answers the original value.

### `cond~>`

```text
(cond~> value (test clause ...) ... (else clause ...)) -> Any
```

Evaluates `value` once, then tries tests from left to right. It threads that
value through the first matching body. `else` is optional and must be last;
with no match and no `else`, the original value is returned. Only the ordinary
R6RS `else` binding marks the final clause, so a locally bound variable named
`else` remains a normal test.

### `tee~>`

```text
(tee~> value clause ...) -> Any
```

Evaluates `value` once, runs a first-threading chain for its effects, then
answers the original value. With no clauses, it simply answers that value.

## Procedures made from chains

### `lambda~>`

```text
(lambda~> clause ...) -> (Any -> Any)
```

Makes a one-argument procedure that uses `~>` on its argument.

### `lambda~>>`

```text
(lambda~>> clause ...) -> (Any -> Any)
```

Makes a one-argument procedure that uses `~>>` on its argument.

### `lambda-and~>`

```text
(lambda-and~> clause ...) -> (Any -> Any)
```

Makes a one-argument procedure that uses `and~>` on its argument.

### `lambda-and~>>`

```text
(lambda-and~>> clause ...) -> (Any -> Any)
```

Makes a one-argument procedure that uses `and~>>` on its argument.

### `lambda~>*`

```text
(lambda~>* clause ...) -> (Any ... -> Any)
```

Makes a rest-argument procedure. It collects all of its arguments into one
list, then threads that list with `~>`.

### `lambda~>>*`

```text
(lambda~>>* clause ...) -> (Any ... -> Any)
```

Like `lambda~>*`, but threads the collected list with `~>>`.

### `lambda-and~>*`

```text
(lambda-and~>* clause ...) -> (Any ... -> Any)
```

Like `lambda~>*`, but uses `and~>` on the collected list.

### `lambda-and~>>*`

```text
(lambda-and~>>* clause ...) -> (Any ... -> Any)
```

Like `lambda~>*`, but uses `and~>>` on the collected list.

## Unicode aliases

Each name below is the same binding as its `lambda` spelling. Choose the form
your editor and team read best.

| Alias | Same binding as |
|:--|:--|
| `λ~>` | `lambda~>` |
| `λ~>>` | `lambda~>>` |
| `λ-and~>` | `lambda-and~>` |
| `λ-and~>>` | `lambda-and~>>` |
| `λ~>*` | `lambda~>*` |
| `λ~>>*` | `lambda~>>*` |
| `λ-and~>*` | `lambda-and~>*` |
| `λ-and~>>*` | `lambda-and~>>*` |

## `_`

`_` is re-exported from `(rnrs base)`. At a clause's top level it chooses the
threaded value's exact position. It is otherwise the ordinary R6RS `_`
binding, so importing both `(rnrs)` and `(threading)` causes no conflict.
