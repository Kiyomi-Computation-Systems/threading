#!r6rs
;; PURE. Imports no library that loads a shared object.
(library (site links)
  (export rewrite-links repo-blob)
  (import (rnrs))

  ;; repo-blob : String
  ;; A ../ link in docs points to this repository at the rendered ref.
  (define repo-blob
    "https://github.com/Kiyomi-Computation-Systems/threading/blob/")

  (define (prefix? pre s)
    (and (>= (string-length s) (string-length pre))
         (string=? pre (substring s 0 (string-length pre)))))
  (define (suffix? suf s)
    (let ((ls (string-length s)) (lf (string-length suf)))
      (and (>= ls lf) (string=? suf (substring s (- ls lf) ls)))))
  (define (split-anchor target)
    (let loop ((i 0))
      (cond ((= i (string-length target)) (values target #f))
            ((char=? (string-ref target i) #\#)
             (values (substring target 0 i) (substring target i (string-length target))))
            (else (loop (+ i 1))))))
  (define (registry-has? registry page slug)
    (cond ((assoc page registry) => (lambda (kv) (and (member slug (cdr kv)) #t)))
          (else #f)))
  (define (strip-dot-slash path)
    (if (prefix? "./" path) (substring path 2 (string-length path)) path))

  ;; rewrite-target : String Registry String String -> (Values String Boolean)
  ;; Rewrite Markdown page links to generated HTML and report missing pages or
  ;; anchors.  Absolute URLs and unrecognised relative paths pass through.
  (define (rewrite-target target registry page ref)
    (cond
      ((prefix? "http://" target) (values target #f))
      ((prefix? "https://" target) (values target #f))
      ((prefix? "#" target)
       (values target
               (not (registry-has? registry page (substring target 1 (string-length target))))))
      ((prefix? "../" target)
       (values (string-append repo-blob ref "/" (substring target 3 (string-length target))) #f))
      (else
       (let-values (((path anchor) (split-anchor target)))
         (if (suffix? ".md" path)
             (let* ((norm (strip-dot-slash path))
                    (base (substring norm 0 (- (string-length norm) 3)))
                    (target-page (string-append base ".md"))
                    (slug (and anchor (substring anchor 1 (string-length anchor)))))
               (values (string-append (if (string=? base "README") "index" base)
                                      ".html" (or anchor ""))
                       (not (if slug
                                (registry-has? registry target-page slug)
                                (assoc target-page registry)))))
             (values target #f))))))

  ;; rewrite-links : SXML Registry String String
  ;;                 -> (Values SXML (Listof (Pairof String String)))
  ;; Rewrite href/src attributes on links and images.  Returned dangling links
  ;; identify their source page and original target in document order.
  (define (rewrite-links body registry page ref)
    (let ((danglers '()))
      (define (attr-map attr)
        (if (and (memq (car attr) '(href src)) (pair? (cdr attr)) (string? (cadr attr)))
            (let-values (((new dangling?) (rewrite-target (cadr attr) registry page ref)))
              (when dangling? (set! danglers (cons (cons page (cadr attr)) danglers)))
              (list (car attr) new))
            attr))
      ;; R6RS leaves map order unspecified, but recording dangling links must
      ;; retain document order.
      (define (walk-attrs attrs)
        (if (null? attrs)
            '()
            (let ((head (attr-map (car attrs))))
              (cons head (walk-attrs (cdr attrs))))))
      (define (walk-children nodes)
        (if (null? nodes)
            '()
            (let ((head (walk-node (car nodes))))
              (cons head (walk-children (cdr nodes))))))
      (define (walk-node node)
        (if (pair? node)
            (let ((tag (car node)) (rest (cdr node)))
              (if (and (pair? rest) (pair? (car rest)) (eq? (caar rest) '^))
                  (cons tag (cons (cons '^ (if (memq tag '(a img))
                                                (walk-attrs (cdar rest))
                                                (cdar rest)))
                                  (walk-children (cdr rest))))
                  (cons tag (walk-children rest))))
            node))
      (let ((out (walk-node body)))
        (values out (reverse danglers))))))
