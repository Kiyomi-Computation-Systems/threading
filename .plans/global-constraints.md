# Global constraints

These rules bind every task brief. Each one cites the decision record in
[decisions/](decisions/) it comes from. If a rule here and its record disagree, the record
wins and this file gets fixed. Rules from a record that is still Proposed are marked
provisional. They bind until that record is accepted or amended.

## Platforms

- **The library runs wherever an R6RS Scheme does.** The build and the tests need a POSIX
  shell and GNU make: Linux and macOS, on amd64 and arm64. CI runs on Linux alone
  (AGENTS.md), on amd64 and arm64 (ADR-0003).

## The library

- **Every file under `src/` is a plain R6RS library**: `STEM.sls` with no other dot, at
  the path its name gives; first line exactly `#!r6rs`, no `#!` after it; one
  `(library NAME (export ...) (import ...) ...)` form with no version on its name;
  importing, through any wrapper, only `(rnrs ...)` but `(rnrs eval)`, and `(threading
  ...)` libraries that are themselves under `src/`. Nothing else lives under `src/` but
  an OS's or an editor's litter. `make check-imports` holds it, and `make test` runs it
  once `src/` exists (ADR-0001).
- **The library has no dependencies** (ADR-0001, ADR-0002).

## Tests and tooling

- **The suites run on Chez alone**; test-only code under `tests/` may use `(chezscheme)`
  (ADR-0001).
- **SRFI-64 comes from chez-srfi at `vendor/chez-srfi`, pinned at `SRFI_PIN`,
  `7879b527f267f067416552fb989135ad1b4ea436`.** Move the gitlink and `SRFI_PIN` on one
  commit; `make check-pins` holds them. `make deps` never fetches (ADR-0002).
- **`make` runs the host's Chez**, `CHEZ` or the first of `scheme` and `chez` that answers
  as Chez Scheme, and `make check-chez` refuses any other. No development container
  (ADR-0003).
- **CI builds Chez 10.4.1 from its sha256-pinned tarball** (`scripts/ci/build-chez.sh`),
  and asserts the version and machine type it ends up with (ADR-0003).
