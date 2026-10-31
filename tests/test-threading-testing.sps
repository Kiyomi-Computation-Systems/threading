#!r6rs
;;; (threading-testing): the shared exit form, the verdict it exits with,
;;; describe, and run-check.
;;;
;;; suite-exit-status is asked about runners of the suite's own making, each
;;; with known counts, under SRFI-64's null runner so nothing they run is
;;; reported. This suite cannot vouch for the verdict it exits through, so it
;;; exits 1 on its own failures first, before the shared form.
(import (rnrs)
        (srfi :64)
        (threading-testing)
        (only (chezscheme) directory-list parameterize)
        ;; (rnrs)'s current-error-port takes no argument; Chez's is the
        ;; parameter behind it, which parameterize can rebind.
        (prefix (only (chezscheme) current-error-port) chez:))

(define runner (test-runner-simple))
(test-runner-current runner)

;; counted : (-> Any) -> Test-Runner
;; A null runner after THUNK's tests ran on it.
(define (counted thunk)
  (let ((r (test-runner-null)))
    (test-with-runner r (thunk))
    r))

;; verdict : Test-Runner -> (U (List Integer String) (List 'raised String))
;; suite-exit-status's answer for R, and all it wrote to the error port.
(define (verdict r)
  (guard (e (#t (list 'raised (describe e))))
    (let-values (((port take) (open-string-output-port)))
      (let ((status (parameterize ((chez:current-error-port port))
                      (suite-exit-status r))))
        (list status (take))))))

(define (message pass fail xpass)
  (string-append "suite-exit-status: exit 1 (pass " (number->string pass)
                 ", fail " (number->string fail) ", xpass " (number->string xpass)
                 "): a suite needs a pass, and no fail or xpass\n"))

(test-begin "threading-testing")

;; --- suite-exit-form --------------------------------------------------------

;; Built with list: a quoted exit form here would be an early exit to
;; make check-suites, which reads data.
(test-equal "suite-exit-form is the datum every suite ends with"
  (list 'exit (list 'suite-exit-status 'runner))
  suite-exit-form)

;; --- suite-exit-status ------------------------------------------------------

(test-equal "a pass alone: 0, and nothing written"
  '(0 "")
  (verdict (counted (lambda () (test-assert #t)))))

(test-equal "no test at all: 1"
  (list 1 (message 0 0 0))
  (verdict (counted (lambda () #t))))

(test-equal "a pass and a fail: 1"
  (list 1 (message 1 1 0))
  (verdict (counted (lambda () (test-assert #t) (test-assert #f)))))

(test-equal "a pass and an unexpected pass: 1"
  (list 1 (message 1 0 1))
  (verdict (counted (lambda ()
                      (test-assert #t)
                      (test-expect-fail 1)
                      (test-assert #t)))))

(test-equal "a pass, an expected fail and a skip: 0"
  '(0 "")
  (verdict (counted (lambda ()
                      (test-assert #t)
                      (test-expect-fail 1)
                      (test-assert #f)
                      (test-skip 1)
                      (test-assert #f)))))

(test-equal "256 failures: 1, not a count that wraps to 0"
  (list 1 (message 1 256 0))
  (verdict (counted (lambda ()
                      (test-assert #t)
                      (let loop ((i 0))
                        (when (< i 256)
                          (test-assert #f)
                          (loop (+ i 1))))))))

(test-equal "not a runner: an assertion violation from suite-exit-status"
  '(assertion-violation suite-exit-status (not-a-runner))
  (guard (e ((and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'other-raise (describe e))))
    (suite-exit-status 'not-a-runner)
    'no-raise))

;; --- describe ---------------------------------------------------------------

(test-equal "describe: anything but a condition as write writes it"
  "(a \"b\" #\\c)"
  (describe '(a "b" #\c)))

(test-equal "describe: a condition as Chez displays it"
  "Exception in f: boom with irritant 42"
  (describe (condition (make-who-condition 'f)
                       (make-message-condition "boom")
                       (make-irritants-condition '(42)))))

;; --- run-check --------------------------------------------------------------

(test-equal "run-check: the exit status, stdout and stderr; each argument one word, unexpanded"
  '(3 "[a b][it's][][$HOME][\"q\"][back\\slash]" "to stderr\n")
  (guard (e (#t (list 'raised (describe e))))
    (run-check "tests/fixtures/programs/out-err-exit.sps"
               '("a b" "it's" "" "$HOME" "\"q\"" "back\\slash"))))

;; Whatever the capture files are named, the directory holds after a call
;; just what it held before.
(test-equal "run-check: leaves no capture file behind"
  '(same)
  (guard (e (#t (list 'raised (describe e))))
    (run-check "tests/fixtures/programs/out-err-exit.sps" '())
    (let* ((before (list-sort string<? (directory-list "build/run-check")))
           (ignored (run-check "tests/fixtures/programs/out-err-exit.sps" '()))
           (after (list-sort string<? (directory-list "build/run-check"))))
      (if (equal? before after) '(same) (list 'before before 'after after)))))

(test-end "threading-testing")

(when (or (= (test-runner-pass-count runner) 0)
          (> (test-runner-fail-count runner) 0)
          (> (test-runner-xpass-count runner) 0))
  (exit 1))

(exit (suite-exit-status runner))
