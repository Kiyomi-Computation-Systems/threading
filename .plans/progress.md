# Progress ledger

Where threading stands. Read it with [global-constraints.md](global-constraints.md)
before starting slice work. When a slice merges, update **Now** and add a close-out under
**Close-outs**, newest first.

## Now

- **The scaffold is written**, not yet committed or merged: the Makefile, the test
  harness (`(threading-testing)`, `(threading-checks)`, `make check-suites` and
  `make check-imports` with their suites and fixtures), chez-srfi pinned under `vendor/`,
  CI, AGENTS.md, README.org, NOTICE, and ADR-0001 to ADR-0003.
- **The scaffold had a read-only adversarial review** on 2026-10-31. All 11 findings
  were reproduced and fixed. The import audit now refuses `(rnrs eval)` and a
  `(threading ...)` import that no file under `src/` holds, and passes over editor and OS
  litter. `make check-suites` looks inside vectors. The fixtures pin exact headers,
  mid-line `#!`, exits other than `(exit 1)`, and look-alike library names. CI installs
  its tools before it uses them. 37 mutants of the harness, the reviewer's five among
  them, are all killed.
- **The design is drafted** in [2026-10-31-threading-design.md](2026-10-31-threading-design.md).
  The owner answered its six open questions on 2026-10-31, each the recommended option;
  design §7 records the answers.
- **Next: slice 1**, `~>`, `~>>`, `and~>`, `and~>>`, `_` and the `lambda` forms with
  their `λ` aliases (design §6).

## Open

- **CI has not run.** The workflow is written but the repository has not been pushed; the
  first run builds Chez 10.4.1 on both architectures and fills the cache.
- **`Akku.manifest` has not been read by `akku`**, which is not installed on the
  development host. Slice 3 checks it.
- **Two `run-check` behaviours are untested**: that it runs `$CHEZ` rather than whatever
  `scheme` is on `PATH`, and that the child's stdin is `/dev/null`. No suite can tell
  these apart from the inside without setting its own environment and stdin.
- **The mutant recipe's `ulimit -v` is unverified on macOS**, where it is said to be
  refused; with `&&` the recipe then runs nothing rather than running uncapped.

## Close-outs

None yet.
