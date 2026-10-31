#!r6rs
;;; The base threading forms: threading position, holes, short-circuiting,
;;; procedures made from chains, their aliases, and macro hygiene.
(import (rnrs)
        (rnrs conditions)
        (rnrs eval)
        (srfi :64)
        (threading)
        (threading-testing)
        (only (chezscheme) expand gensym?))

(define runner (test-runner-simple))
(test-runner-current runner)

;; syntax-failure : Datum -> (List Symbol Symbol Datum Datum)
;; Expand FORM in the same R6RS environment a library client uses.  A syntax
;; condition reports its who, whole form and bad subform as ordinary data;
;; no-raise and another condition have distinct sentinels.
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

;; normalize-expansion : Datum -> Datum
;; Chez's expand gives generated identifiers unique names and may use a
;; ($primitive N NAME) reference.  Their stable meaning is the pretty name,
;; and NAME, respectively.
(define (normalize-expansion datum)
  (cond
    ((gensym? datum) (string->symbol (symbol->string datum)))
    ((and (list? datum)
          (= (length datum) 3)
          (eq? (car datum) '$primitive)
          (integer? (cadr datum)))
     (normalize-expansion (caddr datum)))
    ((pair? datum) (map normalize-expansion datum))
    ((vector? datum) (list->vector (map normalize-expansion (vector->list datum))))
    (else datum)))

(test-begin "threading")

;; --- ~> and ~>> -----------------------------------------------------------

(test-equal "~> with no clause answers its value"
  4
  (~> 4))

(test-equal "~>> with no clause answers its value"
  4
  (~>> 4))

(test-equal "~> inserts at the first argument"
  2
  (~> 3 (+ 1) (- 2)))

(test-equal "~>> inserts at the last argument"
  -2
  (~>> 3 (+ 1) (- 2)))

(test-equal "~> puts a top-level hole at its exact position"
  -2
  (~> 3 (+ 1) (- 2 _)))

(test-equal "~>> puts a top-level hole at its exact position"
  2
  (~>> 3 (+ 1) (- _ 2)))

(test-equal "~> accepts a one-element list holding its hole"
  2
  (~> (lambda (x) (+ x 1)) (_ 1)))

(test-equal "a locally bound _ is an argument, not a hole"
  '(value local after)
  (let ((_ 'local))
    (~> 'value (list _ 'after))))

(test-equal "a nested _ is an argument, not a hole"
  '(value (nested))
  (let ((_ 'nested))
    (~> 'value (list (list _)))))

(test-equal "a quoted clause expands as an application, not an inserted quote"
  '(lambda (b) ((quote a) b))
  (normalize-expansion
   (expand '(lambda (b) (~> b 'a)) expansion-environment)))

;; --- and~> and and~>> -----------------------------------------------------

(test-equal "and~> with no clause answers its value"
  'value
  (and~> 'value))

(test-equal "and~>> with no clause answers its value"
  'value
  (and~>> 'value))

(test-equal "and~> evaluates its value once and stops after #f"
  '(#f 1 0)
  (let ((value-count 0)
        (later-count 0))
    (let ((stop (lambda (ignored) #f))
          (later (lambda (value)
                   (set! later-count (+ later-count 1))
                   value)))
      (list (and~> (begin (set! value-count (+ value-count 1)) 1) stop later)
            value-count
            later-count))))

(test-equal "and~>> threads at the last argument while its answers are true"
  '(2 1 0)
  (and~>> '(1 2) (append '(0)) reverse))

;; --- chains as procedures -------------------------------------------------

(test-equal "lambda~> makes a one-argument first-threading procedure"
  12
  ((lambda~> (+ 2) (* 3)) 2))

(test-equal "lambda~>> makes a one-argument last-threading procedure"
  '(2 1 0)
  ((lambda~>> (append '(0)) reverse) '(1 2)))

(test-equal "lambda-and~> preserves short-circuiting"
  '(#f 0)
  (let ((ran 0))
    (let ((stop (lambda (ignored) #f))
          (later (lambda (value)
                   (set! ran (+ ran 1))
                   value)))
      (list ((lambda-and~> stop later) 1) ran))))

(test-equal "lambda-and~>> threads at the last argument"
  '(2 1 0)
  ((lambda-and~>> (append '(0)) reverse) '(1 2)))

(test-equal "lambda~>* passes all arguments as one list"
  '(3 2 1)
  ((lambda~>* reverse) 1 2 3))

(test-equal "lambda~>>* passes all arguments as one list"
  '(2 1 0)
  ((lambda~>>* (append '(0)) reverse) 1 2))

(test-equal "lambda-and~>* preserves short-circuiting"
  '(#f 0)
  (let ((ran 0))
    (let ((stop (lambda (ignored) #f))
          (later (lambda (value)
                   (set! ran (+ ran 1))
                   value)))
      (list ((lambda-and~>* stop later) 1 2) ran))))

(test-equal "lambda-and~>>* threads all arguments at the last argument"
  '(2 1 0)
  ((lambda-and~>>* (append '(0)) reverse) 1 2))

(test-equal "lambda forms with no clauses are identity procedures"
  '(value value (1 2) (1 2))
  (list ((lambda~>) 'value)
        ((lambda-and~>>) 'value)
        ((lambda~>*) 1 2)
        ((lambda-and~>>*) 1 2)))

;; The lambda macros introduce x and args.  The clauses' surrounding
;; bindings must stay visible instead.
(test-equal "lambda~> does not capture x from its clause"
  11
  (let ((x 10))
    ((lambda~> (+ x)) 1)))

(test-equal "lambda~>* does not capture args from its clause"
  '((1 2) outer)
  (let ((args 'outer))
    ((lambda~>* (list args)) 1 2)))

;; and~> introduces a temporary while it short-circuits.  This is the same
;; hygiene check for that binding.
(test-equal "and~> does not capture t from its clause"
  11
  (let ((t 10))
    (and~> 1 (+ t))))

;; Each Unicode name is an alias for the corresponding ASCII binding.
(test-equal "lambda aliases have the first-threading behaviours"
  '(12 12 #f #f)
  (list ((lambda~> (+ 2) (* 3)) 2)
        ((λ~> (+ 2) (* 3)) 2)
        ((lambda-and~> ((lambda (ignored) #f))) 2)
        ((λ-and~> ((lambda (ignored) #f))) 2)))

(test-equal "lambda aliases have the last-threading behaviours"
  '((2 1 0) (2 1 0) (2 1 0) (2 1 0))
  (list ((lambda~>> (append '(0)) reverse) '(1 2))
        ((λ~>> (append '(0)) reverse) '(1 2))
        ((lambda-and~>> (append '(0)) reverse) '(1 2))
        ((λ-and~>> (append '(0)) reverse) '(1 2))))

(test-equal "starred lambda aliases pass all arguments as one list"
  '((3 2 1) (3 2 1) (3 2 1) (3 2 1))
  (list ((lambda~>* reverse) 1 2 3)
        ((λ~>* reverse) 1 2 3)
        ((lambda-and~>* reverse) 1 2 3)
        ((λ-and~>* reverse) 1 2 3)))

(test-equal "starred last-threading lambda aliases behave alike"
  '((2 1 0) (2 1 0) (2 1 0) (2 1 0))
  (list ((lambda~>>* (append '(0)) reverse) 1 2)
        ((λ~>>* (append '(0)) reverse) 1 2)
        ((lambda-and~>>* (append '(0)) reverse) 1 2)
        ((λ-and~>>* (append '(0)) reverse) 1 2)))

;; --- grammar refusals ------------------------------------------------------

(test-equal "~> names its whole form and each non-clause datum"
  '((syntax-violation ~> (~> 1 2) 2)
    (syntax-violation ~> (~> 1 "no") "no")
    (syntax-violation ~> (~> 1 #f) #f)
    (syntax-violation ~> (~> 1 #\a) #\a)
    (syntax-violation ~> (~> 1 #(a)) #(a))
    (syntax-violation ~> (~> 1 #vu8(1 2)) #vu8(1 2))
    (syntax-violation ~> (~> 1 ()) ())
    (syntax-violation ~> (~> 1 (f . tail)) (f . tail)))
  (list (syntax-failure '(~> 1 2))
        (syntax-failure '(~> 1 "no"))
        (syntax-failure '(~> 1 #f))
        (syntax-failure '(~> 1 #\a))
        (syntax-failure '(~> 1 #(a)))
        (syntax-failure '(~> 1 #vu8(1 2)))
        (syntax-failure '(~> 1 ()))
        (syntax-failure '(~> 1 (f . tail)))))

(test-equal "refuses two top-level holes with the clause as subform"
  '(syntax-violation ~>> (~>> 1 (list _ _)) (list _ _))
  (syntax-failure '(~>> 1 (list _ _))))

(test-equal "a thread form without its value names the whole form"
  '(syntax-violation ~> (~>) #f)
  (syntax-failure '(~>)))

(test-equal "a bad later clause is not attributed to a rewritten ~> form"
  '(syntax-violation ~>> (~>> 1 (+ 2) 3) 3)
  (syntax-failure '(~>> 1 (+ 2) 3)))

(test-equal "every base form reports its own public name"
  '((syntax-violation ~> (~> 1 2) 2)
    (syntax-violation ~>> (~>> 1 2) 2)
    (syntax-violation and~> (and~> 1 2) 2)
    (syntax-violation and~>> (and~>> 1 2) 2))
  (list (syntax-failure '(~> 1 2))
        (syntax-failure '(~>> 1 2))
        (syntax-failure '(and~> 1 2))
        (syntax-failure '(and~>> 1 2))))

(test-equal "lambda forms and their aliases report the form the user wrote"
  '((syntax-violation lambda~> (lambda~> 2) 2)
    (syntax-violation lambda~>> (lambda~>> 2) 2)
    (syntax-violation lambda-and~> (lambda-and~> 2) 2)
    (syntax-violation lambda-and~>> (lambda-and~>> 2) 2)
    (syntax-violation lambda~>* (lambda~>* 2) 2)
    (syntax-violation lambda~>>* (lambda~>>* 2) 2)
    (syntax-violation lambda-and~>* (lambda-and~>* 2) 2)
    (syntax-violation lambda-and~>>* (lambda-and~>>* 2) 2)
    (syntax-violation λ~> (λ~> 2) 2)
    (syntax-violation λ-and~>>* (λ-and~>>* 2) 2))
  (list (syntax-failure '(lambda~> 2))
        (syntax-failure '(lambda~>> 2))
        (syntax-failure '(lambda-and~> 2))
        (syntax-failure '(lambda-and~>> 2))
        (syntax-failure '(lambda~>* 2))
        (syntax-failure '(lambda~>>* 2))
        (syntax-failure '(lambda-and~>* 2))
        (syntax-failure '(lambda-and~>>* 2))
        (syntax-failure '(λ~> 2))
        (syntax-failure '(λ-and~>>* 2))))

(test-end "threading")

(exit (suite-exit-status runner))
