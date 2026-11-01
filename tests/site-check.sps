#!r6rs
;;; Gate the real documentation sources before a Pages artifact is published.
(import (rnrs) (only (chezscheme) directory-list getenv)
        (site io) (site pages) (site render) (site serializer))

(define (die . parts)
  (for-each (lambda (part) (display part (current-error-port))) parts)
  (newline (current-error-port))
  (exit 1))

(define (ends-with? suffix text)
  (let ((suffix-length (string-length suffix)) (text-length (string-length text)))
    (and (>= text-length suffix-length)
         (string=? suffix (substring text (- text-length suffix-length) text-length)))))
(define (starts-with? prefix text)
  (and (>= (string-length text) (string-length prefix))
       (string=? prefix (substring text 0 (string-length prefix)))))
(define (string-search text needle start)
  (let ((text-length (string-length text)) (needle-length (string-length needle)))
    (let loop ((at start))
      (cond ((> (+ at needle-length) text-length) #f)
            ((string=? needle (substring text at (+ at needle-length))) at)
            (else (loop (+ at 1)))))))
(define (list-minus left right)
  (filter (lambda (item) (not (member item right))) left))
(define (markdown-file? name)
  (and (ends-with? ".md" name) (> (string-length name) 3)))

;; site/pages.sls declares the complete source set and navigation order.
(define nav-docs (list-sort string<? (map car pages)))
(define disk-docs (list-sort string<? (filter markdown-file? (directory-list "docs"))))
(define missing (list-minus disk-docs nav-docs))
(define extra (list-minus nav-docs disk-docs))
(unless (and (null? missing) (null? extra))
  (die "check-site: pages and docs disagree; missing=" missing " extra=" extra))

(define ref (or (getenv "SITE_REF") "main"))
(define result (render-site (read-site-inputs) ref))
(unless (null? (site-result-leaked result))
  (die "check-site: unresolved documentation links: " (site-result-leaked result)))

;; Extract href/src values from markup only.  A literal source snippet is
;; escaped as &lt;, so it cannot introduce a false tag here.
(define (attr-values html marker)
  (let ((html-length (string-length html)) (marker-length (string-length marker)))
    (let loop ((at 0) (out '()) (in-tag #f))
      (cond ((> (+ at marker-length) html-length) (reverse out))
            ((char=? (string-ref html at) #\<) (loop (+ at 1) out #t))
            ((char=? (string-ref html at) #\>) (loop (+ at 1) out #f))
            ((and in-tag (string=? marker (substring html at (+ at marker-length))) )
             (let* ((start (+ at marker-length))
                    (end (or (string-search html "\"" start) html-length)))
               (loop (+ end 1) (cons (substring html start end) out) #t)))
            (else (loop (+ at 1) out in-tag))))))

(define (links html)
  (append (attr-values html "href=\"") (attr-values html "src=\"")))
(define (relative-markdown-link? value)
  (and (not (starts-with? "http" value))
       (or (ends-with? ".md" value)
           (string-search value ".md#" 0))))
(define (link-path value)
  (let ((anchor (string-search value "#" 0)))
    (if anchor (substring value 0 anchor) value)))

;; Every internal Markdown link must be rewritten, and every remaining
;; relative resource must name something `make site` writes.
(define written (cons "style.css" (map (lambda (page) (page-file-name (car page))) pages)))
(for-each
 (lambda (page)
   (let ((html (sxml->html (cdr page))))
     (let ((markdown-leaks (filter relative-markdown-link? (links html)))
           (unwritten
            (filter (lambda (value)
                      (let ((path (link-path value)))
                        (and (not (starts-with? "http" value))
                             (not (string=? path ""))
                             (not (member path written)))))
                    (links html))))
       (unless (null? markdown-leaks)
         (die "check-site: a Markdown link leaked into " (car page) ": " markdown-leaks))
       (unless (null? unwritten)
         (die "check-site: a link names no generated file in " (car page) ": " unwritten)))))
 (site-result-pages result))

;; The generated file set follows the registry exactly.
(unless (= (length pages) (length (site-result-pages result)))
  (die "check-site: rendered page count differs from pages registry"))

(display "check-site: page registry, anchors, Markdown links, and output count -- all green\n")
(exit 0)
