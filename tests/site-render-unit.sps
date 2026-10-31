#!r6rs
;;; The Markdown-to-document pipeline.  It needs chez-cmark-gfm and is run by
;;; `make check-site`, separately from the library's portable macro suites.
(import (rnrs) (srfi :64) (threading-testing)
        (site render) (site serializer))

(define (page-html result name)
  (sxml->html
   (cond ((assoc name (site-result-pages result)) => cdr)
         (else (assertion-violation 'site-render-unit "missing page" name)))))

(define (contains? text needle)
  (let ((text-length (string-length text)) (needle-length (string-length needle)))
    (let loop ((at 0))
      (cond ((> (+ at needle-length) text-length) #f)
            ((string=? needle (substring text at (+ at needle-length))) #t)
            (else (loop (+ at 1)))))))

(define result
  (render-site
   '(("README.md" . "# Home\n\nSee [the reference](reference.md#threading-forms).\n")
     ("reference.md" . "# Reference\n\n## Threading forms\n\nText.\n"))
   "main"))

(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "site-render-unit")

(test-equal "one output page is produced for each input in order"
  '("README.md" "reference.md")
  (map car (site-result-pages result)))
(test-equal "every heading, including h1, enters the anchor registry"
  '("reference" "threading-forms")
  (cond ((assoc "reference.md" (site-result-registry result)) => cdr)
        (else 'missing)))
(test-equal "a valid cross-page Markdown anchor does not leak"
  '() (site-result-leaked result))
(test-eq "Markdown links become generated HTML links" 'rewritten
  (if (contains? (page-html result "README.md") "href=\"reference.html#threading-forms\"")
      'rewritten 'missing))
(test-eq "the home page does not appear in its own side navigation" 'absent
  (if (contains? (page-html result "README.md") ">Home</a>") 'present 'absent))

(test-end "site-render-unit")

(exit (suite-exit-status runner))
