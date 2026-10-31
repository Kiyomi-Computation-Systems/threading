#!r6rs
;;; make check-suites: (threading-checks)'s suite-complaints on each fixture
;;; under tests/fixtures/suites/, then tests/check-suites.sps run as a child,
;;; for its output and its exit status.
;;;
;;; Each fixture breaks one rule, or none, and the assertions name the whole
;;; list of rules broken, so a check that complained about the wrong thing,
;;; or about too much, fails as surely as one that said nothing.
(import (rnrs)
        (srfi :64)
        (threading-testing)
        (threading-checks))

(define runner (test-runner-simple))
(test-runner-current runner)

(define dir "tests/fixtures/suites/")

;; rules : String -> (U (Listof Symbol) (List 'raised String))
;; The rules the fixture NAME breaks, in the order complained, or what
;; checking it raised.
(define (rules name)
  (guard (e (#t (list 'raised (describe e))))
    (map cadr (suite-complaints (string-append dir name)))))

(test-begin "check-suites")

;; --- the rules --------------------------------------------------------------

(test-equal "good: ends with the shared form, nothing else exits" '() (rules "good.sps"))

(test-equal "early-one: (exit 1) before the last datum is allowed" '() (rules "early-one.sps"))

(test-equal "no-exit: a last datum that is no exit form"
  '(last-datum) (rules "no-exit.sps"))

(test-equal "other-form: (exit 0) last, the shared form only in a comment"
  '(last-datum) (rules "other-form.sps"))

(test-equal "early-zero: (exit 0) before the shared form"
  '(early-exit) (rules "early-zero.sps"))

(test-equal "early-256: an exit with any status but 1, here one that wraps to 0"
  '(early-exit) (rules "early-256.sps"))

(test-equal "early-vector: exits quasiquote would run inside a vector, and a vector tail"
  '(early-exit early-exit) (rules "early-vector.sps"))

(test-equal "nested-early: an (exit) nested in a definition"
  '(early-exit) (rules "nested-early.sps"))

(test-equal "after-form: a datum after the shared form, which is then an early exit"
  '(last-datum early-exit) (rules "after-form.sps"))

(test-equal "quoted: a quoted (exit 0) counts, a tail (exit) of '(quit exit) does not"
  '(early-exit) (rules "quoted.sps"))

(test-equal "empty: no datum at all" '(no-datum) (rules "empty.sps"))

(test-equal "unreadable: the reader raises" '(unreadable) (rules "unreadable.sps"))

(test-equal "a missing file is unreadable" '(unreadable) (rules "no-such-suite.sps"))

(test-equal "the details name the offending forms"
  '(("tests/fixtures/suites/after-form.sps" last-datum
     "its last datum is (display \"never runs\"), not (exit (suite-exit-status runner))")
    ("tests/fixtures/suites/after-form.sps" early-exit
     "(exit (suite-exit-status runner)) before the last datum would end the suite before its verdict; only (exit 1) may exit early"))
  (guard (e (#t (list 'raised (describe e))))
    (suite-complaints (string-append dir "after-form.sps"))))

;; --- the program ------------------------------------------------------------

(define (check . suites)
  (guard (e (#t (list 'raised (describe e))))
    (run-check "tests/check-suites.sps" suites)))

(test-equal "check-suites.sps: exit 0 and a count when every suite is right"
  '(0 "check-suites: every suite ends with (exit (suite-exit-status runner)) (2 checked)\n" "")
  (check (string-append dir "good.sps") (string-append dir "early-one.sps")))

(test-equal "check-suites.sps: exit 1 and one line per complaint on stderr"
  '(1 ""
    "check-suites: tests/fixtures/suites/early-zero.sps: (exit 0) before the last datum would end the suite before its verdict; only (exit 1) may exit early\ncheck-suites: tests/fixtures/suites/empty.sps: it holds no datum, so it cannot end with (exit (suite-exit-status runner))\n")
  (check (string-append dir "good.sps") (string-append dir "early-zero.sps")
         (string-append dir "empty.sps")))

(test-equal "check-suites.sps: no suite named passes, with a count of 0"
  '(0 "check-suites: every suite ends with (exit (suite-exit-status runner)) (0 checked)\n" "")
  (check))

(test-end "check-suites")

(exit (suite-exit-status runner))
