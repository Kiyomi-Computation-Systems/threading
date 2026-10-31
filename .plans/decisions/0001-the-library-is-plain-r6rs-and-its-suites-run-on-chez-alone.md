# ADR-0001: The library is plain R6RS, and its suites run on Chez alone

- **Status:** Accepted
- **Date:** 2026-10-31
- **Scope:** `src/` and the test lanes
- **Related:** circuit ADR-0006, whose import audit this one's is cut down from

## Context

The project ports Racket's threading macros to R6RS, so that any R6RS Scheme can use
them. Chez is the development Scheme. Guile and Racket's `plt-r6rs` are on the
development host too, so the suites could run on three implementations, but each brings
its own SRFI-64, its own library path rules and its own reading of the edges R6RS leaves
open. The owner chose Chez alone for the suites, with portability held by a check.

Chez makes it easy to leave R6RS without noticing: `(chezscheme)` exports hundreds of
names, `#!chezscheme` switches the reader mid-file, and Chez loads `NAME.chezscheme.sls`
or `NAME.ss` in preference to `NAME.sls`, so either would shadow the portable file
unseen.

## Decision

1. **Every file under `src/` is a plain R6RS library**: named `STEM.sls` with no other
   dot, at the path its library name gives; first line exactly `#!r6rs`, and no `#!`
   after it; one `(library NAME (export ...) (import ...) ...)` form, its name carrying
   no version; importing, through any wrapper, only `(rnrs ...)` but `(rnrs eval)`, whose
   `environment` reaches any library at run time, and `(threading ...)` libraries that
   are themselves under `src/`, so none loads from another directory on the path.
   Nothing else lives under `src/`, no other file and no link, but the litter an OS or
   an editor leaves (dot files, `#autosave#`, `backup~`), which no library name maps
   to.
2. **`make check-imports` holds rule 1** (`tests/check-imports.sps`, through
   `(threading-checks)`), and **`make test` runs it once `src/` exists**.
3. **The suites run on Chez alone.** Test-only code under `tests/` may use Chez's own
   procedures.

## Consequences

- **A Chez-only behaviour can still reach `src/`** through what R6RS leaves to the
  implementation, such as the order a call's arguments are evaluated in, how
  `syntax-violation` reports, or Chez's `(rnrs)` `file-options` taking flags R6RS does
  not define (`append`, `compressed`), which `guile --r6rs` refuses. The import audit
  cannot see that. AGENTS.md asks for the
  form every implementation agrees on, with a comment where the code leans on a guarantee
  that is easy to get wrong.
- **Adding a second implementation is a lane, not a rewrite**: the library needs no
  change, and the suites need its SRFI-64 and library path. It takes its own decision
  record.
