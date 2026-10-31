#!r6rs
;;; A child for (threading-testing)'s run-check: it writes each argument to
;;; stdout, a line to stderr, and exits 3.
(import (rnrs))
(for-each (lambda (a) (put-string (current-output-port) (string-append "[" a "]"))) (cdr (command-line)))
(put-string (current-error-port) "to stderr\n")
(exit 3)
