#!r6rs
;;; Pure contracts for the documentation-site generator.  This runs without
;;; chez-cmark-gfm, so it keeps page naming and anchor generation portable.
(import (rnrs) (srfi :64) (threading-testing) (site pages) (site slug))

(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "site-unit")

(test-equal "README.md writes as the home page" "index.html"
  (page-file-name "README.md"))
(test-equal "other Markdown files write beside it as HTML" "reference.html"
  (page-file-name "reference.md"))
(test-equal "the nav names every documentation source in order"
  '("README.md" "reference.md")
  (map car pages))
(test-equal "heading anchors follow GitHub's lower-case spelling"
  "lambda-forms" (slugify "Lambda forms"))

(test-end "site-unit")

(exit (suite-exit-status runner))
