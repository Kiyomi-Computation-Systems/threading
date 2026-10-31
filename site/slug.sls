#!r6rs
;; PURE. Imports no library that loads a shared object.
(library (site slug)
  (export slugify heading-text make-slugger)
  (import (rnrs))

  ;; slugify : String -> String
  ;; GitHub-style heading anchors: lower case, word characters, hyphens and
  ;; spaces retained, then spaces become hyphens.
  (define (slugify str)
    (list->string
     (map (lambda (c) (if (char=? c #\space) #\- c))
          (filter kept? (string->list (string-downcase str))))))

  ;; Chez's char-numeric? includes circled digits, which GitHub drops.
  (define (kept? c)
    (or (char-alphabetic? c)
        (memq (char-general-category c) '(Mn Mc Me Nd Pc))
        (char=? c #\space)
        (char=? c #\-)))

  ;; heading-text : SXML -> String
  ;; Concatenate text descendants, skipping an SXML attribute node and tags.
  (define (heading-text node)
    (call-with-string-output-port
     (lambda (p)
       (let walk ((n node))
         (cond
           ((string? n) (put-string p n))
           ((pair? n)
            (cond ((eq? (car n) '^) #f)
                  ((symbol? (car n)) (for-each walk (cdr n)))
                  (else (for-each walk n))))
           (else #f))))))

  ;; make-slugger : -> (String -> String)
  ;; Number duplicate headings as GitHub does: -1, -2 and so on.
  (define (make-slugger)
    (let ((seen '()))
      (lambda (str)
        (let ((base (slugify str)))
          (let loop ((s base))
            (if (assoc s seen)
                (let ((n (+ 1 (cdr (assoc base seen)))))
                  (set! seen (cons (cons base n) seen))
                  (loop (string-append base "-" (number->string n))))
                (begin (set! seen (cons (cons s 0) seen)) s))))))))
