# AGENTS.md

## Project guidelines

### What this is

* A port of Racket's [threading](https://github.com/lexi-lambda/threading)
  macros, by Alexis King, to R6RS: `~>`, `~>>`, `and~>`, `and~>>`, the
  `lambda~>` family with its `λ` aliases, `when~>`, `unless~>`, `cond~>` and
  `tee~>`. The upstream release the port follows, and how it differs from it,
  are in the design, `.plans/2026-10-31-threading-design.md`.
* The upstream code is ISC-licensed. `NOTICE` carries its copyright and
  license; keep them there while any of it, or code derived from it, remains.

### Architecture & portability

* The library under `src/` is **plain R6RS**: every file is a `.sls` library
  whose first line is `#!r6rs`, with no `#!` after it, importing only
  `(rnrs ...)` but `(rnrs eval)`, and `(threading ...)` libraries that are
  themselves under `src/` (ADR-0001). `make check-imports` holds it, and
  `make test` runs it once `src/` exists. It passes over an OS's or an
  editor's litter: dot files, `#autosave#` and `backup~`.
* The suites run on Chez Scheme alone (ADR-0001). Chez is the development
  Scheme, but nothing in `src/` may depend on it: no Chez procedures, no
  Chez reader syntax, no file named `.chezscheme.sls` or `.ss`, both of which
  Chez would load in place of the `.sls`.
* R6RS leaves some macro behaviour to the implementation. Prefer the form
  every implementation agrees on, and when the code relies on an R6RS
  guarantee that is easy to get wrong (`free-identifier=?` against `_`,
  `else` or `quote`), say which in a comment.
* The library runs wherever an R6RS Scheme does. The build and the tests
  need a POSIX shell and GNU make: Linux and macOS, on amd64 and arm64.
* **DO NOT** set up macOS CI runners: Linux only!
* Each exported form should have a comment with its grammar and what it
  expands to; an exported procedure, a Typed Racket style signature.

### Dependencies

* The library has none.
* The suites use SRFI-64 from chez-srfi
  (https://github.com/arcfide/chez-srfi), a submodule under `vendor/`
  pinned at `SRFI_PIN`, the commit chez-http-server and circuit pin
  (ADR-0002). `make submodules` clones it, where the network is; `make deps`
  links it into `build/scheme-libs` and never fetches. `make check-pins`
  holds the gitlink and the checkout at `SRFI_PIN`: move both on one commit.
* Builds and tests run on the host's Chez, found as `scheme` or `chez` on
  `PATH`, or named by `CHEZ` (ADR-0003). There is no development container.

### Layout, process & libraries

* Plans live in `/.plans`, decision records in `/.plans/decisions`.
* The ledger is `/.plans/progress.md`: where the project stands, the next
  slice, and a close-out for each merged slice. `/.plans/global-constraints.md`
  holds the decision records' hard rules and binds every task brief. Read both
  before starting slice work. `/.superpowers/` is git-ignored plugin scratch,
  not the ledger.
* Code comments, `README.org` and `/docs` describe the code as it is: never
  cite a plan, slice, decision record, review, date, or PR or issue number.
  State the fact or the reason itself, in the present tense. History belongs
  in `/.plans`, the ledger, `CHANGELOG.md` and git.
* Add entries to `CHANGELOG.md` for each release.
* `/docs` is for user facing documentation only.
* Documentation should be very concise, focused, to the point, ELI5 style.
* `Makefile` should have a `help` command which lists all of its commands;
  `make check-help` holds it to `.PHONY`.
* Libraries are R6RS `.sls`; libraries and programs contain their own code —
  no shared include bodies. Test-only libraries live in `tests/`:
  `(threading-testing)` and `(threading-checks)`. They may use Chez's own
  procedures, through `(only (chezscheme) ...)`.

### Testing & mutation discipline

* Use TDD / test-driven development.
* A test that passes whether the code is right or wrong is worse than no test.
* A test is not finished when it passes. It is finished when you have watched
  it fail.
* Prefer a check to a comment.
* **Do not** write tests that rely on reading code comments: a test asserts
  what the code does, never what a comment says.
* Test a macro by what its expansion does, and where its shape matters, by
  what it expands to. Give a form each kind of clause the grammar takes: an
  identifier, a quoted datum, a list with a hole, a list without one, and
  the forms the grammar refuses. A refusal is asserted as the
  `syntax-violation` raised, by evaluating the form with `eval` under a
  `guard`.
* Hold evaluation order and counts with effects: a form that evaluates its
  value twice, or a clause it should have skipped, passes a test that only
  compares results.
* Run mutants on copies under `build/`, each suite under a timeout and a
  memory cap, as in
  `(ulimit -v 4194304 && timeout 60 "$CHEZ" --libdirs ... --program ...)`:
  with `&&`, a shell that refuses the cap runs nothing rather than running
  the suite uncapped.

**Tests**

* `guard` returns the body's value when nothing raises, and `0` is truthy.
  Assert *what was raised* against an expected value, with a distinct sentinel
  for the no-raise case.
* SRFI-64 turns an exception in the *actual* expression into `#f`. Never
  expect `#f` from something that can raise.
* SRFI-64 does not catch an exception in the *expected* expression, nor in a
  suite's top-level definitions: the suite dies and no test is named. Compute
  anything that can raise under a `guard`.
* Every `tests/test-*.sps` must end with `(exit (suite-exit-status runner))`:
  SRFI-64 sets no exit status. Anything after that line never runs, and
  `make check-suites` checks it is there. It reads suites as data, so a
  quoted exit form anywhere before the last line counts as an early exit:
  build such a list with `list`.
* An exit status is taken modulo 256, so `(exit 256)` exits 0. Exit with 0 or
  1, never a count.
* A suite cannot vouch for the verdict it exits through. A suite that tests
  `suite-exit-status` must also exit 1 on its own failures, before the
  shared form.
* Chez chooses the order of a call's arguments as it compiles each call, and
  `map` calls its procedure in no fixed order. A `let`'s inits are arguments
  too. No assertion may depend on any order: use `for-each` for effects, and
  `let*` when one init must follow another.
* An assertion passes whenever *another* rule can produce its expected value.
  Assert whole outputs, not substrings, and build a test's base from
  non-default values.
* SRFI-64 keeps one result per runner. Never run a test inside another test's
  actual expression: the outer verdict is reported under the inner test's
  name. To test the harness itself, run tests on a runner of their own, made
  with `test-runner-null` and `test-with-runner`.
* In Chez, `(rnrs)`'s `current-output-port` and `current-error-port` take no
  argument. To capture output, `parameterize` Chez's own, imported with
  `(prefix (only (chezscheme) current-error-port) chez:)`.

## Closing ritual

We run this when we're done and ready to merge the PR.

**Important**: ALWAYS ask before running this.

1. Squash merge the PR.
2. Catch up local `main`.
3. Clean up branches. Delete the merged branch locally and on the remote.
4. Reflect.
