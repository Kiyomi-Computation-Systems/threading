# Progress ledger

Where threading stands. Read it with [global-constraints.md](global-constraints.md)
before starting slice work. When a slice merges, update **Now** and add a close-out under
**Close-outs**, newest first.

## Now

- **The scaffold is merged**, squashed from
  [PR #1](https://github.com/Kiyomi-Computation-Systems/threading/pull/1) on 2026-10-31;
  its close-out is below.
- **Slice 1 is merged**, squashed from
  [PR #2](https://github.com/Kiyomi-Computation-Systems/threading/pull/2) on 2026-10-31;
  its close-out is below.
- **The design** is [2026-10-31-threading-design.md](2026-10-31-threading-design.md).
  The owner answered its six open questions on 2026-10-31, each the recommended option;
  design §7 records the answers.
- **Next: slice 2**, `when~>`, `unless~>`, `cond~>` and `tee~>` (design §6).

## Open

- **`Akku.manifest` has not been read by `akku`**, which is not installed on the
  development host. Slice 3 checks it.
- **Two `run-check` behaviours are untested**: that it runs `$CHEZ` rather than whatever
  `scheme` is on `PATH`, and that the child's stdin is `/dev/null`. No suite can tell
  these apart from the inside without setting its own environment and stdin.
- **The mutant recipe's `ulimit -v` is unverified on macOS**, where it is said to be
  refused; with `&&` the recipe then runs nothing rather than running uncapped.
- **Nothing has run on macOS**, which the Makefile and `scripts/require-chez` aim to
  support.

## Close-outs

### Slice 1: PR #2, 2026-10-31

- **What merged:** `(threading)` with `~>`, `~>>`, `and~>`, `and~>>`, `_`, the eight
  `lambda` forms and their `λ` aliases; the base suite; concise guide and reference;
  and an Unreleased changelog entry.
- **Verified:** `make test` passed all four suites locally, including 36 assertions in
  `tests/test-threading.sps`; `make check-pins check-help` and `git diff --check` passed.
- **The review:** a read-only review found no actionable issue.
- **Also learned:** `begin-for-syntax` is not available in this R6RS environment, and
  Chez's R6RS `datum->syntax` requires an identifier template. The implementation uses
  one private `syntax-case` dispatcher and `with-syntax` splicing instead.
- **Still open:** the required capped mutant run did not start on macOS because
  `ulimit -v` was refused; its `&&` guard correctly prevented an uncapped run.

### The scaffold: PR #1, 2026-10-31

- **What merged:**
  - **Build and pin:** the Makefile, with `help`, `check-help`, `submodules`,
    `check-pins`, `check-chez`, `deps`, `dev`, `run`, `test`, `check-suites`,
    `check-imports` and `clean`. `scripts/require-chez`. chez-srfi pinned at `7879b52`.
  - **Test harness:** `(threading-testing)` and `(threading-checks)`, the two audit
    programs, three suites and their fixtures.
  - **CI and docs:** CI, AGENTS.md, README.org crediting Alexis King, NOTICE with her ISC
    license, CHANGELOG.md, Akku.manifest.
  - **Plans:** ADR-0001 to ADR-0003, the global constraints and the design.
- **The owner's choices:** the suites run on Chez alone, take SRFI-64 from a pinned
  chez-srfi, and run on the host's Chez with no container (ADR-0001 to ADR-0003). The
  answers to the design's six questions are in design §7.
- **Verified:**
  - `make test` passes on Chez 10.4.0 locally.
  - CI's first run built Chez 10.4.1 on both images (`ta6le` and `tarm64le`) and passed
    3 of 3 suites on each.
  - 37 mutants of the harness are all killed.
- **The review:** a read-only adversarial review, on Opus, found 11 defects, each
  reproduced and fixed before merge.
  - Two were ways past the import audit: a `(threading ...)` library outside `src/` on
    the test path, and Chez reached through `(rnrs eval)`'s `environment`.
  - One was an exit inside a quasiquoted vector, which `make check-suites` could not see.
  - Five were wrong versions of the checks that every suite still passed.
  - The rest were editor litter failing the audit, CI using its tools before installing
    them, the mutant recipe's memory cap, and a design contract its own expansion table
    broke.
- **Traps recorded in AGENTS.md:**
  - A quoted exit form in a suite counts as an early exit: build such a list with `list`.
  - In Chez, `(rnrs)`'s `current-error-port` takes no argument; `parameterize` Chez's own.
- **Also learned:**
  - Ubuntu 24.04's apt Chez is 9.5.8, with no arm64 build, so CI builds its own Chez.
  - A global gitignore can silently drop fixtures named like litter; `.gitignore`
    negates it for `tests/fixtures/imports/litter/`.
