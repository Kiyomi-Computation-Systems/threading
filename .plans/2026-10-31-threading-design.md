# threading: the design of the port

- **Status:** Draft. The owner answered its six open questions on 2026-10-31 (§7)
- **Date:** 2026-10-31
- **Upstream:** [lexi-lambda/threading](https://github.com/lexi-lambda/threading),
  release 2.0, commit `e79cfe5` ("Fix implies specification in threading/info.rkt"),
  ISC license. Its code is `threading-lib/threading/private/{base,cond,extra}.rkt`, its
  tests `threading-test/tests/threading/{main,cond,extra}.rkt`.
- **Binds:** [global-constraints.md](global-constraints.md); the decision records in
  [decisions/](decisions/)

## 1. Goal

One R6RS library, `(threading)`, with every form upstream 2.0 exports, behaving as
upstream does wherever R6RS lets it, and refusing at expansion, with a
`syntax-violation`, every form upstream's grammar refuses.

## 2. The forms

| Form | Expands to |
|---|---|
| `(~> e)` | `e` |
| `(~> e c rest ...)` | `(~> c[e] rest ...)`, `e` inserted into clause `c` as its first argument |
| `(~>> e c rest ...)` | the same, `e` inserted as the last argument |
| `(and~> e)` | `e` |
| `(and~> e c rest ...)` | `(let ((t e)) (and t (and~> c[t] rest ...)))`, and `and~>>` likewise |
| `(lambda~> c ...)` | `(lambda (x) (~> x c ...))`; `lambda~>>`, `lambda-and~>` and `lambda-and~>>` over `~>>`, `and~>` and `and~>>` |
| `(lambda~>* c ...)` | `(lambda args (~> args c ...))`, and the other three `*` forms likewise |
| `λ~>` and seven more | the eight `lambda` forms under their `λ` names: one binding exported twice |
| `(when~> e test c ...)` | `(let ((t e)) (if test (~> t c ...) t))`: `e` first, then `test` |
| `(unless~> e test c ...)` | `(let ((t e)) (if test t (~> t c ...)))` |
| `(cond~> e (test c ...) ... (else c ...))` | `(let ((t e)) (cond (test (~> t c ...)) ... (else (~> t c ...))))`; with no `else` clause, `(else t)` |
| `(tee~> e c ...)` | `(let ((t e)) (~> t c ...) t)` |
| `_` | `(rnrs base)`'s `_`, re-exported, as upstream re-exports Racket's |

`t`, `x` and `args` are fresh identifiers: a clause cannot see them, and a clause's own
`t` is never captured. The tests of `cond~>`, `when~>` and `unless~>` cannot see the
value either, as upstream.

### The clause grammar

A clause `c`, given a value `v` to insert:

1. **An identifier `f`, or a quoted datum `'d`** becomes `(f v)`, or `('d v)`. Upstream
   keeps a quoted clause out of the threading so that Racket's `#%app` can give it a
   meaning; see §3.2.
2. **A list holding `_` at its top level**, `(p ... _ q ...)`, becomes `(p ... v q ...)`,
   in `~>` and `~>>` alike. `_` is a hole when it is `free-identifier=?` to `(rnrs base)`'s
   `_`: a `_` the user has bound locally is a variable, not a hole. A `_` nested deeper,
   `(f (g _))`, is no hole.
3. **Any other non-empty list** `(f a ...)` becomes `(f v a ...)` under `~>`, and
   `(f a ... v)` under `~>>`.
4. **Anything else is refused**: a number, string, boolean, character, vector,
   bytevector, `()`, or an improper list.

Every refusal is a `syntax-violation` whose `who` is the name of the form the user
wrote (`~>`, `cond~>`, ...), whose form is that whole form as written, and whose subform
is the clause at fault. So each form checks all its clauses before it expands, and `~>`
and `~>>` thread all their clauses in one step of their transformer rather than
expanding to `(~> c[e] rest ...)`: by the time a recursive `~>` met a bad second clause,
its form would be one the user never wrote, and inside `cond~>` its `who` would be `~>`.
The table above gives each form's meaning, not the steps of its expansion.

## 3. Where the port differs from upstream

1. **No `#%app`.** R6RS has no application hook, so upstream's "use the `#%app` from the
   surrounding lexical context" tests have no counterpart, and are dropped.
2. **A quoted clause** `'d` still expands to `('d v)`, as upstream (§7.1). With
   no `#%app`, that application always fails at run time, as any call of a non-procedure
   does.
3. **Two holes in one clause are refused** (§7.2). Upstream's
   `(pre ... _ post ...)` takes the last `_` as the hole and leaves the first, which then
   fails as `_` used as an expression; the port says so at once, naming the clause.
4. **Error messages** are R6RS `syntax-violation`s, not syntax/parse's.
5. **A refusal names the form the user wrote** (§2). Upstream's `~>` rebuilds its form
   at each step, `(~> c[e] rest ...)`, and `cond~>`, `when~>`, `unless~>`, `tee~>` and the
   `lambda` forms hand their clauses to `~>`, so upstream reports a bad clause against a
   form the user never wrote, or under `~>`'s name.

## 4. Layout

- `src/threading.sls`: `(threading)`, the whole library. Upstream's split into `base`,
  `cond` and `extra` is private to it, and the port is small enough to need none.
- `tests/test-threading.sps`: `~>`, `~>>`, `and~>`, `and~>>`, the clause grammar, the
  `lambda` forms and their aliases.
- `tests/test-threading-cond.sps`: `when~>`, `unless~>`, `cond~>` and `tee~>`.
- `docs/README.md`, the guide, and `docs/reference.md`, every export with its grammar.

## 5. Testing

- **Upstream's tests, ported**, all but the `#%app` ones, each as a `test-equal` with the
  value upstream asserts.
- **Evaluation counts and order**, held with effects: `and~>` evaluates its value once and
  stops at the first `#f` without running a later clause; `when~>`, `unless~>` and
  `cond~>` evaluate the value before any test, and the tests in order, stopping at the
  first true one; `tee~>` runs its clauses once, and answers the value it was given, not
  their result.
- **Hygiene**: a clause using its own `t`, `x` or `args`; a locally bound `_`, which is no
  hole; a locally bound `else`, which is no `else` clause in `cond~>`.
- **Shape**, where it matters, through Chez's `expand`, normalized: each gensym to its
  name and each `($primitive n f)` to `f`. `(lambda (b) (~> b 'a))` expands to
  `(lambda (b) ('a b))`.
- **Refusals**, each form evaluated with `eval` in `(environment '(rnrs) '(threading))`
  under a `guard`, asserting the `syntax-violation`'s who, form and subform as data, with a
  sentinel for no raise: every case of §2's rule 4, two holes, `(~>)` with no value, a
  `cond~>` clause that is not a list, and an `else` clause that is not last. A bad clause
  after a good one, and one inside each form that hands its clauses on, holds §2's
  promise that the refusal names the form the user wrote.

## 6. Slices

1. **`(threading)` with `~>`, `~>>`, `and~>`, `and~>>`, `_`, and the eight `lambda`
   forms with their `λ` aliases**: upstream's `base.rkt`. Its suite, its pages of
   `docs/`, and a CHANGELOG entry under Unreleased.
2. **`when~>`, `unless~>`, `cond~>` and `tee~>`**: upstream's `cond.rkt` and
   `extra.rkt`, with their suite, docs and CHANGELOG entry.
3. **Release v0.1.0**: the CHANGELOG's release section, `Akku.manifest` checked with
   `akku` (not installed on the development host today), the tag, and publishing to the
   Akku index, which is the owner's to do.

## 7. The owner's answers

The six questions this draft raised, each answered by the owner on 2026-10-31, each the
recommended option.

1. **A quoted clause** keeps upstream's expansion: `(~> v 'd)` is `('d v)`, which fails
   at run time in R6RS as any call of a non-procedure does. It is not refused at
   expansion.
2. **Two or more `_` in one clause are refused at expansion**, with a `syntax-violation`
   naming the clause, rather than following upstream into an expansion that fails on the
   leftover `_`.
3. **`_` is re-exported**, as upstream: it is `(rnrs base)`'s own binding, so importing
   both `(rnrs)` and `(threading)` is no conflict.
4. **The `λ` aliases are exported**, as upstream: each of the eight `lambda` forms under
   both names, one binding each.
5. **The library is `(threading)` and the Akku package `threading`.**
6. **A refusal names the form the user wrote**, under its own name, its whole form as
   written, and the clause at fault (§2, §3.5), not the form upstream's expansion had
   reached.
