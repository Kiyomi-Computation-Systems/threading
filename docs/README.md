# threading

Clojure-style threading macros for R6RS Scheme. They let you write nested
calls in the order the value moves through them.

💡 Threading here is about expressions, not operating-system threads.

## A taste

```scheme
(import (rnrs) (threading))

(~> 1 (+ 2) (* 10))
;; => 30

(~>> '(1 2 3) (append '(0)))
;; => (0 1 2 3)

(~> 30 number->string (string-append "answer: " _))
;; => "answer: 30"
```

The first expression reads as “start with 1, add 2, then multiply by 10.” It
means the same thing as `(* (+ 1 2) 10)`.

## Five ideas to keep in mind

- **`~>` threads first.** `(~> value (f a))` becomes `(f value a)`.
- **`~>>` threads last.** Use it when the value belongs at the end, as it
  often does with `append`, `apply`, and other collection functions.
- **`_` marks the exact slot.** One top-level `_` in a clause wins over first
  or last threading.
- **`and~>` and `and~>>` stop at `#f`.** Later clauses do not run.
- **The other forms are small control-flow tools.** `when~>`, `unless~>`,
  `cond~>`, and `tee~>` decide which work runs while keeping the value easy to
  see.

## What is in it

| Form | Use it when you want to… |
|:--|:--|
| `~>`, `~>>` | thread a value first or last through calls |
| `and~>`, `and~>>` | thread until a clause answers `#f` |
| `when~>`, `unless~>`, `cond~>` | choose whether or where to thread |
| `tee~>` | do a side effect and keep the original value |
| `lambda~>` family | turn a chain into a reusable procedure |
| `_` | put the threaded value at one exact top-level position |

## What it is not

- **Not a runtime pipeline.** These are macros; they build ordinary nested
  Scheme calls before your program runs.
- **Not SRFI 197's `chain`.** `~>` inserts its value automatically. SRFI 197
  uses an explicit `_` in every threaded clause.
- **Not a replacement for ordinary control flow.** Use a normal `let`, `if`,
  or `cond` when that makes the code clearer.

## Works beyond Chez

The library is one plain R6RS `.sls` file. It imports only `(rnrs)` and uses
no Chez procedures or reader extensions, so an implementation with R6RS
libraries should load it. Put this checkout's `src/` directory on that
implementation's library path, then import `(threading)`.

Guile users start it in R6RS mode. From the checkout:

```sh
guile --r6rs -L "$PWD/src" --no-auto-compile -s your-program.sps
```

The repository's `make` targets, test harness, and CI use Chez Scheme. That
is how this project is continuously tested; it is not a dependency of the
library. Run a small program on another R6RS implementation before relying on
it in production.

## Status

v0.1.0 is the latest release. The library is used from a checkout while Akku
publishing is still pending.

## Read next

- [Getting started](getting-started.md): clone it, test it, and run a file.
- [Quickstart](quickstart.md): choose a threading form with small examples.
- [API reference](reference.md): every exported name and its grammar.
