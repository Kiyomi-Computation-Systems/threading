#!r6rs
;; NOT pure: (cmark gfm) loads the native cmark-gfm parser.
(library (site render)
  (export render-site site-result? site-result-pages
          site-result-registry site-result-leaked)
  (import (rnrs) (cmark gfm) (site transform) (site links)
          (site template) (site pages))

  ;; A result carries whole page trees, each page's generated heading ids, and
  ;; internal links whose target page or anchor was absent.
  (define-record-type site-result
    (fields pages registry leaked))

  (define (label-for name)
    (cond ((assoc name pages) => cdr) (else name)))
  (define (rail-toc toc) (filter (lambda (entry) (= (car entry) 2)) toc))
  ;; The wordmark reaches Home; the sidebar lists the remaining pages.
  (define nav (filter (lambda (entry) (not (string=? (car entry) "README.md"))) pages))

  (define (neighbors name)
    (let loop ((ps nav) (prev #f))
      (cond ((null? ps) (values #f #f))
            ((string=? (caar ps) name)
             (values prev (if (null? (cdr ps)) #f (cadr ps))))
            (else (loop (cdr ps) (car ps))))))

  ;; render-site : (Listof (Pairof String String)) String -> SiteResult
  ;; Parse and slug every input first, then resolve all intra-site links
  ;; against the complete registry before applying the document template.
  (define (render-site inputs ref)
    (let* ((parsed
            (map (lambda (in)
                   (let-values (((body toc)
                                 (transform-body (markdown->sxml (cdr in)
                                                                  (default-cmark-options)))))
                     (list (car in) body toc (map caddr toc))))
                 inputs))
           (registry (map (lambda (pg) (cons (car pg) (cadddr pg))) parsed)))
      (let loop ((remaining parsed) (out '()) (leaked '()))
        (if (null? remaining)
            (make-site-result (reverse out) registry (reverse leaked))
            (let* ((pg (car remaining)) (name (car pg))
                   (body (cadr pg)) (toc (caddr pg)))
              (let-values (((body* dangling) (rewrite-links body registry name ref))
                           ((prev next) (neighbors name)))
                (loop (cdr remaining)
                      (cons (cons name
                                  (page->document nav name (label-for name)
                                                  body* (rail-toc toc) prev next))
                            out)
                      (append (reverse dangling) leaked)))))))))
