#!r6rs
;; PURE. Imports no library that loads a shared object.
(library (site transform)
  (export transform-body)
  (import (rnrs) (site slug))

  (define heading-tags '(h1 h2 h3 h4 h5 h6))

  (define (heading-tag? tag) (and (memq tag heading-tags) #t))
  (define (level tag)
    (- (char->integer (string-ref (symbol->string tag) 1))
       (char->integer #\0)))

  ;; transform-body : SXML -> (Values SXML (Listof (List Integer String String)))
  ;; Add an id to every heading and return the body with its table of contents.
  (define (transform-body top)
    (let ((slug (make-slugger)) (toc '()))
      (define (walk node)
        (cond
          ((string? node) node)
          ((and (pair? node) (heading-tag? (car node)))
           (let* ((text (heading-text node)) (id (slug text)))
             (set! toc (cons (list (level (car node)) text id) toc))
             (cons (car node) (cons (list '^ (list 'id id)) (cdr node)))))
          ((pair? node) (cons (car node) (walk-children (cdr node))))
          (else node)))
      ;; R6RS leaves map order unspecified.  Sequencing explicitly keeps
      ;; duplicate heading ids and TOC entries in document order.
      (define (walk-children nodes)
        (if (null? nodes)
            '()
            (let ((head (walk (car nodes))))
              (cons head (walk-children (cdr nodes))))))
      (let ((body (walk top)))
        (values body (reverse toc))))))
