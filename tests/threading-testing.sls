#!r6rs
;;; (threading-testing): what every suite shares.
;;;
;;;   suite-exit-form    the last datum of every tests/test-*.sps
;;;   suite-exit-status  the verdict that form exits with
;;;   describe           a raised object as text, for evidence
;;;   run-check          run a program under tests/ as a child Chez; its exit
;;;                      status, stdout and stderr
;;;
;;; Test-only: it lives in tests/, which make test puts on Chez's library
;;; path, not in src/. Its own suite is tests/test-threading-testing.sps.
(library (threading-testing)
  (export suite-exit-form suite-exit-status describe run-check)
  (import (rnrs)
          (srfi :64)
          (only (chezscheme) display-condition get-process-id getenv mkdir system))

  ;; suite-exit-form : Sexp
  ;; The last datum of every tests/test-*.sps, exactly: make check-suites
  ;; reads each suite as data and compares its last datum with this one.
  ;; `runner` is the suite's own binding for the runner it makes current.
  (define suite-exit-form '(exit (suite-exit-status runner)))

  ;; suite-exit-status : Test-Runner -> (U 0 1)
  ;; 0 when RUNNER saw a pass, and no failure and no unexpected pass.
  ;; Otherwise 1, after a line on the error port with the runner's counts.
  ;; Expected failures and skips count neither way. SRFI-64 sets no exit
  ;; status of its own. The answer is 0 or 1, never a count: exit statuses
  ;; wrap at 256, so 256 failures would exit 0.
  (define (suite-exit-status runner)
    (unless (test-runner? runner)
      (assertion-violation 'suite-exit-status "not a SRFI-64 test runner" runner))
    (let ((pass (test-runner-pass-count runner))
          (fail (test-runner-fail-count runner))
          (xpass (test-runner-xpass-count runner)))
      (if (and (> pass 0) (= fail 0) (= xpass 0))
          0
          (let ((err (current-error-port)))
            ;; The runner's own summary, on stdout, comes first.
            (flush-output-port (current-output-port))
            (put-string err
              (string-append "suite-exit-status: exit 1 (pass " (number->string pass)
                             ", fail " (number->string fail)
                             ", xpass " (number->string xpass)
                             "): a suite needs a pass, and no fail or xpass\n"))
            (flush-output-port err)
            1))))

  ;; describe : Any -> String
  ;; A condition as Chez displays it, anything else as `write` writes it.
  ;; Evidence for a test's expected value, never raising itself.
  (define (describe obj)
    (guard (e (#t "<the raised object could not be printed>"))
      (call-with-string-output-port
       (lambda (p)
         (if (condition? obj) (display-condition obj p) (write obj p))))))

  ;; --- run-check -----------------------------------------------------------

  ;; run-check : String (Listof String) -> (List Integer String String)
  ;; Runs PROGRAM with ARGS as `$CHEZ --libdirs $TEST_LIBDIRS --program`,
  ;; from the current directory, with stdin from /dev/null. The answer is the
  ;; exit status, then all it wrote to stdout and to stderr, as UTF-8. A
  ;; non-zero exit is an answer, not a raise, so a test compares the whole
  ;; list with what it expects.
  ;;
  ;; CHEZ and TEST_LIBDIRS come from the environment, which the Makefile
  ;; exports; it raises when either is missing. Each word reaches the shell
  ;; single-quoted, so it arrives as one argument, unchanged. The two streams
  ;; go through files under build/run-check/, named for this process and a
  ;; count, and removed once read.
  (define (run-check program args)
    (let ((chez (required-env "CHEZ"))
          (libdirs (required-env "TEST_LIBDIRS")))
      (let* ((stem (next-capture-stem))
             (out (string-append stem ".out"))
             (err (string-append stem ".err"))
             (words (append (list chez "--libdirs" libdirs "--program" program) args))
             (command (string-append (join (map shell-quote words) " ")
                                     " </dev/null >" (shell-quote out)
                                     " 2>" (shell-quote err)))
             (status (system command))
             (stdout (slurp out))
             (stderr (slurp err)))
        (for-each delete-file (list out err))
        (list status stdout stderr))))

  (define (required-env name)
    (let ((value (getenv name)))
      (unless (and value (positive? (string-length value)))
        (assertion-violation 'run-check
          (string-append name " is not set: run the suites through make test")
          name))
      value))

  (define capture-dir "build/run-check")

  ;; The count makes each name this process asks for its own; the process id
  ;; keeps two suites at once apart.
  (define next-capture-stem
    (let ((count 0))
      (lambda ()
        (unless (file-exists? "build") (mkdir "build"))
        (unless (file-exists? capture-dir) (mkdir capture-dir))
        (set! count (+ count 1))
        (string-append capture-dir "/" (number->string (get-process-id))
                       "-" (number->string count)))))

  (define (shell-quote word)
    (string-append
     "'"
     (apply string-append
            (map (lambda (c) (if (char=? c #\') "'\\''" (string c)))
                 (string->list word)))
     "'"))

  (define (join words sep)
    (if (null? words)
        ""
        (fold-left (lambda (acc w) (string-append acc sep w)) (car words) (cdr words))))

  (define (slurp path)
    (call-with-port (open-file-input-port path (file-options) (buffer-mode block)
                                          (make-transcoder (utf-8-codec)))
      get-string-all-or-empty))

  (define (get-string-all-or-empty port)
    (let ((s (get-string-all port)))
      (if (eof-object? s) "" s))))
