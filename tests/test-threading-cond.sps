#!r6rs
;;; Conditional and side-effect threading forms: behavior, evaluation order,
;;; hygiene, and syntax errors attributed to the public form.
(import (rnrs)
        (rnrs conditions)
        (rnrs eval)
        (srfi :64)
        (threading)
        (threading-testing))

(define runner (test-runner-simple))
(test-runner-current runner)

;; syntax-failure : Datum -> (List Symbol Symbol Datum Datum)
;; The condition reports the public macro name, whole form, and subform as
;; data.  The sentinels distinguish an unrelated raise from no raise.
(define expansion-environment (environment '(rnrs) '(threading)))

(define (syntax-datum obj)
  (if obj (syntax->datum obj) #f))

(define (syntax-failure form)
  (guard (e ((syntax-violation? e)
             (list 'syntax-violation
                   (condition-who e)
                   (syntax-datum (syntax-violation-form e))
                   (syntax-datum (syntax-violation-subform e))))
            (#t (list 'other-raise (describe e))))
    (eval form expansion-environment)
    '(no-raise)))

(test-begin "threading-cond")

;; --- when~> and unless~> --------------------------------------------------

(test-equal "when~> threads when its test is true"
  4
  (when~> 1 #t (+ 1) (* 2)))

(test-equal "when~> answers its value when its test is false"
  1
  (when~> 1 #f (+ 1) (* 2)))

(test-equal "unless~> answers its value when its test is true"
  1
  (unless~> 1 #t (+ 1) (* 2)))

(test-equal "unless~> threads when its test is false"
  4
  (unless~> 1 #f (+ 1) (* 2)))

(test-equal "when~> evaluates its value before its test and skips its clauses"
  '(1 (value test))
  (let ((trace '()))
    (let ((mark (lambda (name value)
                  (set! trace (append trace (list name)))
                  value)))
      (list (when~> (mark 'value 1)
                     (mark 'test #f)
                     (mark 'clause 2))
            trace))))

(test-equal "unless~> evaluates its value before its test and skips its clauses"
  '(1 (value test))
  (let ((trace '()))
    (let ((mark (lambda (name value)
                  (set! trace (append trace (list name)))
                  value)))
      (list (unless~> (mark 'value 1)
                       (mark 'test #t)
                       (mark 'clause 2))
            trace))))

;; The test is outside the generated binding: an outer t must remain visible.
(test-equal "when~> does not capture t from its test"
  1
  (let ((t #f))
    (when~> 1 t (+ 1))))

(test-equal "unless~> does not capture t from its test"
  1
  (let ((t #t))
    (unless~> 1 t (+ 1))))

;; --- cond~> ---------------------------------------------------------------

(test-equal "cond~> threads the first matching branch"
  '(24 5 -11)
  (list (cond~> 11
          ((= 1 1) (+ 1) (* 2))
          ((= 1 2) (- 1) (/ 2))
          (else -))
        (cond~> 11
          ((= 2 1) (+ 1) (* 2))
          ((= 2 2) (- 1) (/ 2))
          (else -))
        (cond~> 11
          ((= 3 1) (+ 1) (* 2))
          ((= 3 2) (- 1) (/ 2))
          (else -))))

(test-equal "cond~> with no matching branch answers its value"
  1
  (cond~> 1 (#f (+ 1))))

(test-equal "cond~> with no clause evaluates its value once"
  '(value 1)
  (let ((count 0))
    (list (cond~> (begin (set! count (+ count 1)) 'value)) count)))

(test-equal "cond~> evaluates tests in order, stops, and only runs the selected body"
  '(1 (value first second body))
  (let ((trace '()))
    (let ((mark (lambda (name value)
                  (set! trace (append trace (list name)))
                  value)))
      (list (cond~> (mark 'value 1)
              ((mark 'first #f) (mark 'first-body 2))
              ((mark 'second #t) (mark 'body _))
              (else (mark 'else-body 3)))
            trace))))

(test-equal "cond~> does not capture t from a test"
  3
  (let ((t #f))
    (cond~> 1
      (t (+ 1))
      (else (+ 2)))))

;; A locally bound else is a condition expression, not the cond~> marker.
(test-equal "cond~> treats a locally bound else as an ordinary test"
  2
  (let ((else #t))
    (cond~> 1
      (else (+ 1))
      (#t (+ 2)))))

;; --- tee~> ----------------------------------------------------------------

(test-equal "tee~> runs its clauses for their effects and answers its input"
  '(30 -15)
  (let ((seen 0))
    (let ((result (~> 10
                      (+ 5)
                      (tee~> - (set! seen _))
                      (* 2))))
      (list result seen))))

(test-equal "tee~> evaluates its value and clauses once"
  '(value (value clause))
  (let ((trace '()))
    (let ((mark (lambda (name value)
                  (set! trace (append trace (list name)))
                  value)))
      (list (tee~> (mark 'value 'value)
                    (mark 'clause _))
            trace))))

(test-equal "tee~> with no clauses is its value"
  '(value 1)
  (let ((count 0))
    (list (tee~> (begin (set! count (+ count 1)) 'value)) count)))

(test-equal "tee~> does not capture t from its clause"
  '(1 11)
  (let ((t 10)
        (seen #f))
    (list (tee~> 1
            ((lambda (value) (set! seen (+ t value))) _))
          seen)))

;; --- grammar refusals ------------------------------------------------------

(test-equal "when~>, unless~>, and tee~> report their own bad clauses"
  '((syntax-violation when~> (when~> 1 #t 2) 2)
    (syntax-violation unless~> (unless~> 1 #f 2) 2)
    (syntax-violation tee~> (tee~> 1 2) 2))
  (list (syntax-failure '(when~> 1 #t 2))
        (syntax-failure '(unless~> 1 #f 2))
        (syntax-failure '(tee~> 1 2))))

(test-equal "conditional forms without their required operands name the whole form"
  '((syntax-violation when~> (when~> 1) #f)
    (syntax-violation unless~> (unless~>) #f)
    (syntax-violation tee~> (tee~>) #f)
    (syntax-violation cond~> (cond~>) #f))
  (list (syntax-failure '(when~> 1))
        (syntax-failure '(unless~>))
        (syntax-failure '(tee~>))
        (syntax-failure '(cond~>))))

(test-equal "cond~> validates condition-clause structure and bodies itself"
  '((syntax-violation cond~> (cond~> 1 2) 2)
    (syntax-violation cond~> (cond~> 1 ()) ())
    (syntax-violation cond~> (cond~> 1 (#t 2)) 2)
    (syntax-violation cond~> (cond~> 1 (#t (+ 1) 2)) 2))
  (list (syntax-failure '(cond~> 1 2))
        (syntax-failure '(cond~> 1 ()))
        (syntax-failure '(cond~> 1 (#t 2)))
        (syntax-failure '(cond~> 1 (#t (+ 1) 2)))))

(test-equal "cond~> rejects an else clause before the last clause"
  '(syntax-violation cond~> (cond~> 1 (else) (#t)) (else))
  (syntax-failure '(cond~> 1 (else) (#t))))

(test-equal "a late bad clause still names the outer conditional form"
  '(syntax-violation when~> (when~> 1 #t (+ 1) 2) 2)
  (syntax-failure '(when~> 1 #t (+ 1) 2)))

(test-end "threading-cond")

(exit (suite-exit-status runner))
