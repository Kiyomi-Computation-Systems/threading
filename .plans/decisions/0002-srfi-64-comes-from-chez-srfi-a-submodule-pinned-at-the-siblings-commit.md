# ADR-0002: SRFI-64 comes from chez-srfi, a submodule pinned at the siblings' commit

- **Status:** Accepted
- **Date:** 2026-10-31
- **Scope:** the suites' dependency. No library change.
- **Related:** chez-http-server, which pins chez-srfi at the same commit; circuit, which
  takes it through the server

## Context

The suites need a test framework, and the sibling repositories' testing rules
(AGENTS.md) are written around SRFI-64's behaviour: what it does with a raise in the
actual and the expected expressions, and that it sets no exit status. chez-srfi
(https://github.com/arcfide/chez-srfi) carries SRFI-64 as portable R6RS. It tags no
releases. Its files use Akku's percent-encoded names (`%3a64.sls`), which Chez does not
decode.

The owner chose SRFI-64 from chez-srfi over a harness of the project's own.

## Decision

1. **chez-srfi is a submodule at `vendor/chez-srfi`, pinned at
   `7879b527f267f067416552fb989135ad1b4ea436`** (`SRFI_PIN` in the Makefile), the commit
   chez-http-server pins, so the three repositories run the same SRFI-64.
2. **`make submodules` clones it, where the network is. `make deps` links every entry
   into `build/scheme-libs/srfi` under its own name and its decoded one, and never
   fetches.** The submodule's tree is left alone.
3. **`make check-pins` holds the gitlink and the checkout at `SRFI_PIN`**, and refuses a
   checkout with local edits. Move the gitlink and `SRFI_PIN` on one commit.
4. **It is test-only.** Nothing under `src/` imports `(srfi ...)` (ADR-0001), and the
   Akku package names no dependency on it.

## Consequences

- **A fresh clone needs `make submodules` once** before `make test`; `make deps` says so
  when the submodule is empty.
- **chez-srfi's newer commits are not taken** until there is a reason to: the pin is
  from 2020, and what has landed since does not touch SRFI-64.
