# Getting started

Use `threading` from a checkout today. It is one plain R6RS library with no
runtime dependencies: put `src/` on an R6RS implementation's library path and
import `(threading)`. The development commands below use Chez because this
repository's test suite does; Chez is not a dependency of the library itself.

## Get the checkout

```sh
git clone https://github.com/Kiyomi-Computation-Systems/threading.git
cd threading
```

You need Chez Scheme, GNU make, and git. Homebrew calls Chez `chez`; the
Makefile finds it. To run the test suite on macOS, install GNU coreutils too,
because the suite uses `gtimeout`.

```sh
make submodules
make test
```

`make submodules` gets the test-only SRFI-64 dependency. `make test` checks
the library and runs every suite. Your own program does not import that test
dependency.

## Try one expression

Save this as `try.sps` in the checkout:

```scheme
#!r6rs
(import (rnrs) (threading))

(display (~> 1 (+ 2) (* 10)))
(newline)
```

Run it:

```sh
make run PROGRAM=try.sps
```

It prints `30`. `make run` gives Chez the `src/` directory where it finds the
`(threading)` library.

## Use Guile

Guile supports an R6RS mode. From this checkout, run the file above with:

```sh
guile --r6rs -L "$PWD/src" --no-auto-compile -s try.sps
```

`--r6rs` selects Guile's R6RS environment, and `-L` makes `(threading)`
available from this checkout's `src/` directory.

## Use another R6RS implementation

Find its R6RS library-path option and point it at this checkout's `src/`
directory. The file `src/threading.sls` declares the library as `(threading)`:

```scheme
(import (rnrs) (threading))
```

The source uses only R6RS facilities, so an implementation with R6RS
libraries should load it. This repository continuously tests Chez alone;
always run your own small program on another implementation before depending
on it.

## Use Chez from another directory

Give Chez this checkout's `src/` directory as a library path:

```sh
chez --libdirs /path/to/threading/src --program /path/to/your-program.sps
```

Use the name of your Chez executable if it is not `chez`.

Next, [write a few pipelines](quickstart.md).
