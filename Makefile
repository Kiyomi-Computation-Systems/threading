# threading
#
# Racket's threading macros, ported to R6RS. The library under src/ is plain
# R6RS and depends on nothing. The suites under tests/ run on Chez Scheme and
# use SRFI-64 from chez-srfi, a submodule pinned under vendor/. `make
# submodules` clones it, once, where the network is; `make check-pins` holds
# it at SRFI_PIN; `make deps` links it into build/ and never fetches.

# The Chez binary. A CHEZ given on the command line or in the environment
# stays as given. Otherwise scripts/require-chez --find asks `scheme` and
# `chez` (Homebrew's name for it) what each is, and takes the first on PATH
# that is Chez Scheme, else the first on PATH, else `scheme`, which
# check-chez then refuses: on a Mac, another Scheme may own `scheme`. Asked
# once, when make reads this file, and exported, so the suites that run a
# check program as a child start this same Chez.
ifeq ($(strip $(CHEZ)),)
CHEZ := $(shell scripts/require-chez --find scheme chez)
endif
export CHEZ

# --- the pin ------------------------------------------------------------------
# chez-srfi tags no releases. This is the commit chez-http-server and circuit
# pin, so the three run the same SRFI-64.
SRFI_DIR := vendor/chez-srfi
SRFI_PIN := 7879b527f267f067416552fb989135ad1b4ea436

# --- the library paths --------------------------------------------------------
# LIBDIRS is src/ alone: the library needs nothing else. TEST_LIBDIRS adds
# tests/, which holds (threading-testing) and (threading-checks), and
# build/scheme-libs, which carries (srfi :64). Exported, so a suite can run a
# check program on the path it runs on itself.
BUILD_DIR := build
SRFI_LIBS := $(BUILD_DIR)/scheme-libs
LIBDIRS := src
TEST_LIBDIRS := src:tests:$(SRFI_LIBS)
export TEST_LIBDIRS

# Every suite, in one order everywhere: make 3.82 to 4.2 leave $(wildcard)
# unsorted.
SUITES := $(sort $(wildcard tests/test-*.sps))

# Seconds a suite may run before timeout kills it and make test names it HUNG.
TEST_TIMEOUT ?= 120

# GNU timeout. Homebrew's coreutils installs it as gtimeout on macOS.
TIMEOUT ?= $(or $(shell command -v timeout 2>/dev/null),$(shell command -v gtimeout 2>/dev/null),timeout)

# One physical line: check-help reads it with awk, and fails if it ends in a
# backslash.
.PHONY: help check-help submodules check-pins check-chez deps dev run test check-suites check-imports site-deps site check-site clean

.DEFAULT_GOAL := help

# The name column is as wide as the longest target's name.
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_.-]+:.*?## / \
	  { n++; name[n] = $$1; text[n] = $$2; if (length($$1) > width) width = length($$1) } \
	  END { format = "  \033[36m%-" width "s\033[0m %s\n"; \
	        for (i = 1; i <= n; i++) printf format, name[i], text[i] }' $(MAKEFILE_LIST)

# Reads what `make help` prints, colour codes stripped, so it checks the
# listing itself. Both directions: every .PHONY target is listed, and every
# listed target is in .PHONY. A listed target left out of .PHONY silently
# stops running once a file of its name exists.
check-help: ## Fail unless `make help` lists exactly the .PHONY targets
	@status=0; \
	if grep -qE '^\.PHONY:.*\\$$' Makefile; then \
	  echo "check-help: the .PHONY line ends in a backslash; keep it on one line" >&2; \
	  status=1; \
	fi; \
	help=$$($(MAKE) --no-print-directory help) || { \
	  echo "check-help: make help failed" >&2; \
	  exit 1; \
	}; \
	esc=$$(printf '\033'); \
	listed=$$(printf '%s\n' "$$help" | sed "s/$$esc\[[0-9;]*m//g" | awk '{ print $$1 }'); \
	phony=$$(awk '/^\.PHONY:/ { $$1 = ""; print }' Makefile); \
	for t in $$phony; do \
	  printf '%s\n' $$listed | grep -qxF "$$t" || { \
	    echo "check-help: make help does not list .PHONY target '$$t'; give it a '## ' description on its target line" >&2; \
	    status=1; \
	  }; \
	done; \
	for t in $$listed; do \
	  printf '%s\n' $$phony | grep -qxF "$$t" || { \
	    echo "check-help: make help lists '$$t', which is not in .PHONY" >&2; \
	    status=1; \
	  }; \
	done; \
	exit $$status

submodules: ## (network) Clone chez-srfi at its pin into vendor/
	git submodule update --init $(SRFI_DIR)

# The checkout is asked for its own .git first: in a submodule that was never
# cloned, `git -C` would climb to this repository and answer its commit.
# Read-only.
check-pins: ## Fail unless chez-srfi's gitlink and checkout are both SRFI_PIN, with no local edits
	@fail=0; \
	rec=$$(git ls-files -s -- $(SRFI_DIR) | awk '$$1 == "160000" && $$3 == 0 { print $$2 }'); \
	if [ "$$rec" != "$(SRFI_PIN)" ]; then \
	  echo "PIN MISMATCH: the gitlink records $(SRFI_DIR) at $${rec:-<none>}, SRFI_PIN says $(SRFI_PIN)" >&2; fail=1; \
	fi; \
	got=; [ -e "$(SRFI_DIR)/.git" ] && got=$$(git -C $(SRFI_DIR) rev-parse HEAD 2>/dev/null); \
	if [ "$$got" != "$(SRFI_PIN)" ]; then \
	  echo "PIN MISMATCH: $(SRFI_DIR) is checked out at $${got:-<absent>}, SRFI_PIN says $(SRFI_PIN)" >&2; fail=1; \
	elif [ -n "$$(git -C $(SRFI_DIR) status --porcelain --untracked-files=no)" ]; then \
	  echo "PIN DIRTY: $(SRFI_DIR) has local edits to tracked files" >&2; fail=1; \
	else \
	  echo "pin ok: $(SRFI_DIR) $(SRFI_PIN)"; \
	fi; \
	exit $$fail

# Runs $(CHEZ) once, under a time limit, and refuses one that is not Chez
# Scheme, naming what it found. deps takes it first, so every target that
# runs Chez holds it before Chez runs.
check-chez: ## Fail unless CHEZ is Chez Scheme, naming what it found
	@scripts/require-chez "$(CHEZ)"

# chez-srfi ships Akku's percent-encoded file names (%3a64.sls), and Chez
# finds (srfi :64) only under the decoded spelling (:64.sls), so every entry
# is linked under both and the submodule's own tree is left alone. `ln -sfn`
# replaces a link in place; the -n stops it following an existing link to a
# directory into the submodule.
deps: check-chez ## Link SRFI-64 into build/scheme-libs; never fetches
	@if [ ! -e $(SRFI_DIR)/%3a64.sls ]; then \
	  echo "deps: $(SRFI_DIR)/%3a64.sls not found, so the submodule is empty. Run 'make submodules' where the network is: make deps never fetches." >&2; \
	  exit 1; \
	fi
	@mkdir -p $(SRFI_LIBS)/srfi
	@set -e; \
	src="$(abspath $(SRFI_DIR))"; dst="$(abspath $(SRFI_LIBS))/srfi"; \
	for f in "$$src"/*; do \
	  b=$$(basename "$$f"); \
	  ln -sfn "$$f" "$$dst/$$b"; \
	  d=$$(printf '%s' "$$b" | sed 's/%3a/:/g'); \
	  [ "$$d" = "$$b" ] || ln -sfn "$$f" "$$dst/$$d"; \
	done

dev: check-chez ## Start a Chez REPL with src/ on the library path
	$(CHEZ) --libdirs $(LIBDIRS)

run: check-chez ## Run a program with src/ on the library path: make run PROGRAM=file.sps
	@test -n "$(PROGRAM)" || { echo "run: set PROGRAM=path/to/program.sps" >&2; exit 2; }
	$(CHEZ) --libdirs $(LIBDIRS) --program $(PROGRAM)

# Runs each suite as its own process under GNU timeout and reports its exit
# status, or HUNG when timeout killed it (exit 124). It fails if any suite
# failed or hung, or if none matched. At a terminal, --foreground keeps a
# suite in make's process group, so Ctrl-C reaches it. The checks come
# first: check-chez (through deps), check-help, check-suites and, once src/
# exists, check-imports, so the first library under src/ is audited without
# anyone remembering to.
test: deps check-help check-suites $(if $(wildcard src),check-imports) ## Run every tests/test-*.sps under timeout; fail if one fails or hangs, or none exists
	@if [ -z "$(SUITES)" ]; then \
	  echo "test: no suites: nothing matches tests/test-*.sps" >&2; \
	  exit 1; \
	fi; \
	command -v $(TIMEOUT) >/dev/null 2>&1 || { \
	  echo "test: $(TIMEOUT) not found: install GNU coreutils (brew install coreutils on macOS)" >&2; \
	  exit 1; \
	}; \
	passed=0; failed=0; hung=0; fg=; \
	if [ -t 0 ]; then fg=--foreground; fi; \
	for t in $(SUITES); do \
	  echo "=== $$t"; \
	  $(TIMEOUT) $$fg $(TEST_TIMEOUT) $(CHEZ) --libdirs $(TEST_LIBDIRS) --program $$t; \
	  rc=$$?; \
	  if [ $$rc -eq 0 ]; then \
	    echo "test: pass $$t"; passed=$$((passed + 1)); \
	  elif [ $$rc -eq 124 ]; then \
	    echo "test: HUNG $$t (no exit within $(TEST_TIMEOUT)s)"; hung=$$((hung + 1)); \
	  else \
	    echo "test: FAIL $$t (exit $$rc)"; failed=$$((failed + 1)); \
	  fi; \
	done; \
	echo "test: ran $$((passed + failed + hung)), passed $$passed, failed $$failed, hung $$hung"; \
	[ $$failed -eq 0 ] && [ $$hung -eq 0 ]

# Reads every suite as data and fails unless each one's last datum is the
# shared exit form and no datum before it holds an exit form but (exit 1),
# naming each suite that breaks either rule (tests/check-suites.sps).
check-suites: deps ## Fail unless every tests/test-*.sps ends with the shared exit form
	@$(CHEZ) --libdirs $(TEST_LIBDIRS) --program tests/check-suites.sps $(SUITES)

# Reads every file under src/ and fails unless each is a plain R6RS library:
# named <name>.sls at its library name's path, first line #!r6rs and no #!
# after it, one library form, importing only (rnrs ...) but (rnrs eval), and
# (threading ...) libraries under src/ (tests/check-imports.sps). It passes
# over dot files, #autosave# and backup~. make test runs it once src/ exists.
check-imports: deps ## Fail unless every file under src/ is a plain R6RS library importing only (rnrs ...) and (threading ...)
	@$(CHEZ) --libdirs $(TEST_LIBDIRS) --program tests/check-imports.sps src

# --- the docs site ------------------------------------------------------------
# docs/*.md render into build/site/ through chez-cmark-gfm.  The dependency is
# development-only: src/ remains portable R6RS and `make test` needs no native
# Markdown parser.  An `akku install` tree wins when present; otherwise the
# pinned archive in Akku.lock is downloaded, verified, and unpacked under
# build/ by scripts/fetch-akku-lock.
SITE_CMARK   := $(if $(wildcard .akku/lib/cmark/gfm.sls),.akku/lib,$(BUILD_DIR)/akku/chez-cmark-gfm/src)
SITE_LIBDIRS := .:$(SITE_CMARK)
SITE_REF     ?= main

site-deps: ## (network, once) Get chez-cmark-gfm as Akku.lock pins it
	@if [ -f .akku/lib/cmark/gfm.sls ]; then \
	  echo "site-deps: using .akku/lib (akku install)"; \
	else \
	  AKKU_DEST=$(BUILD_DIR)/akku sh scripts/fetch-akku-lock chez-cmark-gfm; \
	fi

site: site-deps check-chez ## Render docs/ into build/site/; SITE_REF=<tag> pins repository links
	@mkdir -p $(BUILD_DIR)/site
	@SITE_REF="$(SITE_REF)" SITE_OUT=$(BUILD_DIR)/site \
	  $(CHEZ) --libdirs $(SITE_LIBDIRS) --program build-site.sps
	@cp site/style.css $(BUILD_DIR)/site/style.css
	@echo "site: $(BUILD_DIR)/site ready (open $(BUILD_DIR)/site/index.html)"

# The pure generator contracts run without chez-cmark-gfm on their library
# path.  The pipeline and the real docs then run with it, proving every page
# in the registry exists and no documentation link or anchor dangles.
check-site: site-deps deps ## Test the generator and validate every docs/ page, link, and anchor
	@$(CHEZ) --libdirs .:tests:$(SRFI_LIBS) --program tests/site-unit.sps
	@$(CHEZ) --libdirs $(SITE_LIBDIRS):tests:$(SRFI_LIBS) --program tests/site-render-unit.sps
	@SITE_REF="$(SITE_REF)" $(CHEZ) --libdirs $(SITE_LIBDIRS) --program tests/site-check.sps

clean: ## Remove build/
	rm -rf $(BUILD_DIR)
