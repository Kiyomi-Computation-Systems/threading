#!r6rs
;;; Render docs/*.md into static HTML.  `make site` prepares its dependencies.
(import (rnrs) (only (chezscheme) getenv) (site io) (site render))

(define ref (or (getenv "SITE_REF") "main"))
(define out (or (getenv "SITE_OUT") "build/site"))

(let ((result (render-site (read-site-inputs) ref)))
  (write-site result out)
  (display "site: wrote ") (display (length (site-result-pages result)))
  (display " pages to ") (display out) (newline))
