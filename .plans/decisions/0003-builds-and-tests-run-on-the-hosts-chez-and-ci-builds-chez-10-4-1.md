# ADR-0003: Builds and tests run on the host's Chez, and CI builds Chez 10.4.1

- **Status:** Accepted
- **Date:** 2026-10-31
- **Scope:** development tooling and CI. No library change.
- **Related:** circuit ADR-0002 and chez-http-server ADR-0029, which run in a pinned
  Guix container; circuit's `scripts/ci/build-chez.sh`, which this copies

## Context

The siblings build and test in a pinned Guix container because they need Chez 10.4.1,
threaded, and libuv at chez-libuv's floor, which the host lacks. This library needs
neither: plain R6RS macros run on the host's Chez 10.4.0 as they do on any later Chez.
The owner chose the host's Chez, with no container.

Ubuntu 24.04's `chezscheme` package is 9.5.8, for amd64 and armhf alone: there is no
arm64 build, so CI cannot install Chez from apt on both architectures.

## Decision

1. **`make` runs the host's Chez**: `CHEZ` as given, else the first of `scheme` and
   `chez` on `PATH` that answers as Chez Scheme (`scripts/require-chez --find`).
   **`make check-chez` refuses a binary that is not Chez**, naming what it answered, and
   every target that runs Chez checks it first. No version floor is enforced.
2. **CI runs on Linux, amd64 and arm64**, on pinned Ubuntu 24.04 images, and **builds
   Chez 10.4.1 from its sha256-pinned release tarball** (`scripts/ci/build-chez.sh`),
   cached per OS release, arch and script. The job asserts the version and the machine
   type it ends up with.
3. **There is no development container**: no `channels.scm`, `manifest.scm` or
   `scripts/guix-env`.

## Consequences

- **Two Chez releases run the suites**: the host's, 10.4.0 today, and CI's 10.4.1.
  README.org names both rather than a floor.
- **A build is only as reproducible as the host's Chez**, which suits a library with no
  native code. A floor that matters, or a second implementation, would take a decision
  record of its own, and could bring a container with it.
