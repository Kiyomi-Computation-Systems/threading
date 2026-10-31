#!r6rs
;;; make check-suites: reads every suite named on the command line as data and
;;; names each one that breaks a rule of (threading-checks)'s
;;; suite-complaints, on stderr, then exits 1. Otherwise it says how many it
;;; checked and exits 0. With no suite named it passes: make test refuses that
;;; case itself.
(import (rnrs)
        (threading-testing)
        (threading-checks))

(define suites (cdr (command-line)))

(define complaints (apply append (map suite-complaints suites)))

(for-each (lambda (c)
            (put-string (current-error-port)
                        (string-append "check-suites: " (car c) ": " (caddr c) "\n")))
          complaints)

(when (null? complaints)
  (put-string (current-output-port)
              (string-append "check-suites: every suite ends with "
                             (written suite-exit-form) " ("
                             (number->string (length suites)) " checked)\n")))

(exit (if (null? complaints) 0 1))
