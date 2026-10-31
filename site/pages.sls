#!r6rs
;; PURE. Imports no library that loads a shared object.
(library (site pages)
  (export pages page-file-name)
  (import (rnrs))

  ;; pages : (Listof (Pairof String String))
  ;; The navigation's single source of order and labels.  The site check
  ;; holds this file set against docs/*.md.
  (define pages
    '(("README.md"    . "Home")
      ("reference.md" . "Reference")))

  ;; page-file-name : String -> String
  ;; README.md is the site's home page; every other Markdown source becomes
  ;; an adjacent HTML file.
  (define (page-file-name name)
    (if (string=? name "README.md")
        "index.html"
        (string-append (substring name 0 (- (string-length name) 3)) ".html"))))
