#!r6rs
;;; R6RS threading macros.
;;;
;;; A clause is an identifier, a quoted datum, or a non-empty proper list.
;;; A top-level _ from (rnrs base) marks one insertion point; a locally bound
;;; _ is an ordinary identifier.  The validator runs before any expansion is
;;; built so an invalid clause is reported against the user's whole form.
(library (threading)
  (export ~> ~>> and~> and~>>
          lambda~> lambda~>> lambda~>* lambda~>>*
          lambda-and~> lambda-and~>> lambda-and~>* lambda-and~>>*
          (rename (lambda~> λ~>)
                  (lambda~>> λ~>>)
                  (lambda~>* λ~>*)
                  (lambda~>>* λ~>>*)
                  (lambda-and~> λ-and~>)
                  (lambda-and~>> λ-and~>>)
                  (lambda-and~>* λ-and~>*)
                  (lambda-and~>>* λ-and~>>*))
          _)
  (import (rnrs)
          (rename (only (rnrs) _) (_ base:_)))

  ;; threading-core is private.  It owns the common R6RS syntax-case
  ;; transformer so its helpers need no non-standard phase declarations.
  (define-syntax threading-core
    (let ()
      ;; proper-list-elements : Syntax -> (U (Listof Syntax) #f)
      ;; The top-level elements of STX when it is a proper list, else #f.
      (define (proper-list-elements stx)
        (syntax-case stx ()
          (() '())
          ((head . tail)
           (let ((tail-elements (proper-list-elements #'tail)))
             (and tail-elements (cons #'head tail-elements))))
          (_ #f)))

      ;; quoted-clause? : Syntax -> Boolean
      ;; A quote from (rnrs base) with exactly one datum is a quoted clause.
      (define (quoted-clause? stx)
        (syntax-case stx (quote)
          ((quote datum) #t)
          (_ #f)))

      ;; base-hole? : Syntax -> Boolean
      ;; R6RS guarantees that free-identifier=? compares bindings.  In
      ;; particular, a use-site binding of _ is not (rnrs base)'s _.
      (define (base-hole? stx)
        (and (identifier? stx) (free-identifier=? stx #'base:_)))

      ;; count-holes : (Listof Syntax) -> Integer
      (define (count-holes elements)
        (let loop ((rest elements) (count 0))
          (if (null? rest)
              count
              (loop (cdr rest)
                    (if (base-hole? (car rest)) (+ count 1) count)))))

      ;; split-at-hole : (Listof Syntax) -> (Values (Listof Syntax) (Listof Syntax))
      ;; Called only after count-holes found exactly one hole.
      (define (split-at-hole elements)
        (let loop ((before '()) (rest elements))
          (if (base-hole? (car rest))
              (values (reverse before) (cdr rest))
              (loop (cons (car rest) before) (cdr rest)))))

      ;; make-application : (Listof Syntax) -> Syntax
      ;; Splicing syntax objects preserves each element's lexical binding.
      (define (make-application elements)
        (with-syntax (((element ...) elements))
          #'(element ...)))

      ;; validate-clause : Symbol Syntax Syntax -> Unspecified
      ;; Raises a syntax-violation whose form is WHOLE and whose subform is
      ;; CLAUSE.  A list with more than one base _ is refused deliberately.
      (define (validate-clause who whole clause)
        (cond
          ((identifier? clause) #t)
          ((quoted-clause? clause) #t)
          (else
           (let ((elements (proper-list-elements clause)))
             (cond
               ((or (not elements) (null? elements))
                (syntax-violation who "expected an identifier, quoted datum, or non-empty proper list"
                                  whole clause))
               ((> (count-holes elements) 1)
                (syntax-violation who "a clause has more than one _ hole" whole clause))
               (else #t))))))

      ;; validate-clauses : Symbol Syntax (Listof Syntax) -> Unspecified
      ;; Checks every clause before the outer macro constructs its expansion.
      (define (validate-clauses who whole clauses)
        (for-each (lambda (clause) (validate-clause who whole clause)) clauses))

      ;; insert : Symbol Syntax Syntax -> Syntax
      ;; Inserts VALUE into the already validated CLAUSE under MODE, first or
      ;; last.  An explicit top-level hole overrides MODE.
      (define (insert mode clause value)
        (cond
          ((or (identifier? clause) (quoted-clause? clause))
           (make-application (list clause value)))
          (else
           (let* ((elements (proper-list-elements clause))
                  (holes (count-holes elements)))
             (if (= holes 1)
                 (call-with-values
                     (lambda () (split-at-hole elements))
                   (lambda (before after)
                     (make-application (append before (list value) after))))
                 (if (eq? mode 'first)
                     (make-application (cons (car elements) (cons value (cdr elements))))
                     (make-application (append elements (list value)))))))))

      ;; thread-expression : Symbol Syntax (Listof Syntax) -> Syntax
      ;; The nested applications for ~> or ~>>, after validation.
      (define (thread-expression mode value clauses)
        (let loop ((result value) (rest clauses))
          (if (null? rest)
              result
              (loop (insert mode (car rest) result) (cdr rest)))))

      ;; and-thread-expression : Symbol Syntax (Listof Syntax) -> Syntax
      ;; A fresh temporary holds each result before and can decide whether the
      ;; following clause runs.  Thus each result is evaluated once.
      (define (and-thread-expression mode value clauses)
        (if (null? clauses)
            value
            (let ((temporary (car (generate-temporaries (list value)))))
              (with-syntax ((t temporary)
                            (e value))
                (let ((next (and-thread-expression
                             mode
                             (insert mode (car clauses) temporary)
                             (cdr clauses))))
                  (with-syntax ((next next))
                    #'(let ((t e))
                        (and t next))))))))

      ;; form-components : Symbol Syntax -> (Listof Syntax)
      ;; The arguments after the user's macro name.  WHOLE comes from the
      ;; wrapper before the private dispatcher expands it, so failures retain
      ;; the public macro's full spelling.
      (define (form-components who whole)
        (let ((elements (proper-list-elements whole)))
          (if (and elements (pair? elements))
              (cdr elements)
              (syntax-violation who "expected a proper macro form" whole #f))))

      ;; form-name : Syntax -> Symbol
      ;; The public wrapper passes its received syntax object unchanged, so an
      ;; exported rename (such as λ~>) still reports the name the user wrote.
      (define (form-name whole)
        (syntax-case whole ()
          ((name . rest) (syntax->datum #'name))
          (_ 'threading-core)))

      ;; The wrappers pass their complete unexpanded form, then kind, mode,
      ;; short-circuit flag and arity flag as identifiers.  Those tags never
      ;; reach the result; symbols suffice to select the expansion.
      (lambda (stx)
        (syntax-case stx ()
          ((_ whole kind mode short arity)
           (let* ((who (form-name #'whole))
                  (kind-symbol (syntax->datum #'kind))
                  (mode-symbol (syntax->datum #'mode))
                  (short-symbol (syntax->datum #'short))
                  (arity-symbol (syntax->datum #'arity))
                  (parts (form-components who #'whole)))
             (cond
               ((eq? kind-symbol 'thread)
                (if (null? parts)
                    (syntax-violation who "expected a value followed by zero or more clauses"
                                      #'whole #f)
                    (let ((value (car parts))
                          (clauses (cdr parts)))
                      (validate-clauses who #'whole clauses)
                      (if (eq? short-symbol 'short)
                          (and-thread-expression mode-symbol value clauses)
                          (thread-expression mode-symbol value clauses)))))
               ((eq? kind-symbol 'lambda)
                (let ((argument (car (generate-temporaries (list #'whole)))))
                  (validate-clauses who #'whole parts)
                  (let ((body (if (eq? short-symbol 'short)
                                  (and-thread-expression mode-symbol argument parts)
                                  (thread-expression mode-symbol argument parts))))
                    (with-syntax ((arg argument)
                                  (body body))
                      (if (eq? arity-symbol 'variadic)
                          #'(lambda arg body)
                          #'(lambda (arg) body))))))
               (else
                (syntax-violation who "internal threading macro kind" #'whole #f)))))
          (_
           (syntax-violation 'threading-core "invalid private macro invocation" stx #f))))))

  ;; (~> value clause ...) -> VALUE threaded as each clause's first argument.
  (define-syntax ~>
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole thread first plain one))))

  ;; (~>> value clause ...) -> VALUE threaded as each clause's last argument.
  (define-syntax ~>>
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole thread last plain one))))

  ;; (and~> value clause ...) -> like ~>, stopping at and answering #f.
  (define-syntax and~>
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole thread first short one))))

  ;; (and~>> value clause ...) -> like ~>>, stopping at and answering #f.
  (define-syntax and~>>
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole thread last short one))))

  ;; (lambda~> clause ...) -> a one-argument procedure using ~>.
  (define-syntax lambda~>
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole lambda first plain one))))

  ;; (lambda~>> clause ...) -> a one-argument procedure using ~>>.
  (define-syntax lambda~>>
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole lambda last plain one))))

  ;; (lambda-and~> clause ...) -> a one-argument procedure using and~>.
  (define-syntax lambda-and~>
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole lambda first short one))))

  ;; (lambda-and~>> clause ...) -> a one-argument procedure using and~>>.
  (define-syntax lambda-and~>>
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole lambda last short one))))

  ;; (lambda~>* clause ...) -> a rest-argument procedure using ~>.
  (define-syntax lambda~>*
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole lambda first plain variadic))))

  ;; (lambda~>>* clause ...) -> a rest-argument procedure using ~>>.
  (define-syntax lambda~>>*
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole lambda last plain variadic))))

  ;; (lambda-and~>* clause ...) -> a rest-argument procedure using and~>.
  (define-syntax lambda-and~>*
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole lambda first short variadic))))

  ;; (lambda-and~>>* clause ...) -> a rest-argument procedure using and~>>.
  (define-syntax lambda-and~>>*
    (lambda (stx)
      (with-syntax ((whole stx))
        #'(threading-core whole lambda last short variadic))))
  )
