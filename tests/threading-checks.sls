#!r6rs
;;; (threading-checks): the rules make check-suites and make check-imports
;;; hold, as procedures that answer complaints.
;;;
;;; A complaint is (list PATH RULE DETAIL): the file it is about, a symbol
;;; naming the rule it breaks, and a sentence for a person. The programs
;;; tests/check-suites.sps and tests/check-imports.sps print the details and
;;; set the exit status; the suites assert the paths and the rules.
;;;
;;; Test-only, like (threading-testing). Its suites are
;;; tests/test-check-suites.sps and tests/test-check-imports.sps.
(library (threading-checks)
  (export suite-complaints import-complaints library-files written)
  (import (rnrs)
          (threading-testing)
          (only (chezscheme) directory-list file-directory? file-regular? sort))

  (define (written datum)
    (call-with-string-output-port (lambda (p) (write datum p))))

  ;; --- check-suites --------------------------------------------------------

  ;; suite-complaints : String -> (Listof Complaint)
  ;; What is wrong with the suite at PATH, read as data with Chez's reader:
  ;;
  ;;   no-datum    it holds no datum at all
  ;;   last-datum  its last datum is not exactly suite-exit-form
  ;;   early-exit  a datum before the last holds an exit form other than
  ;;               (exit 1), however deeply nested: it would end the suite
  ;;               before its verdict
  ;;   unreadable  the reader raised
  ;;
  ;; The last datum's complaint comes first, then each early exit in order.
  ;; Reading data, not text, is the point: an exit form in a comment or a
  ;; string is no datum. Data is all it sees, so a quoted '(exit 0) is an
  ;; early exit too: build such a list another way.
  (define (suite-complaints path)
    (let ((found (read-file-data path))
          (form (written suite-exit-form)))
      (case (car found)
        ((data)
         (let ((data (cadr found)))
           (if (null? data)
               (list (list path 'no-datum
                           (string-append "it holds no datum, so it cannot end with " form)))
               (append
                (let ((last (car (reverse data))))
                  (if (equal? last suite-exit-form)
                      '()
                      (list (list path 'last-datum
                                  (string-append "its last datum is " (written last)
                                                 ", not " form)))))
                (map (lambda (exit-form)
                       (list path 'early-exit
                             (string-append (written exit-form)
                                            " before the last datum would end the suite"
                                            " before its verdict; only (exit 1) may exit early")))
                     (apply append (map early-exits (all-but-last data))))))))
        (else
         (list (list path 'unreadable
                     (string-append "it cannot be read as data: " (cadr found))))))))

  ;; early-exits : Any -> (Listof Pair)
  ;; Every list in DATUM, DATUM itself and each list nested in it, in a list
  ;; or a vector, whose car is the symbol exit and which is not exactly
  ;; (exit 1), in the order they appear. It visits a list's elements, never
  ;; its tails: in '(quit exit) the tail (exit) is no exit form. It visits a
  ;; vector's elements because quasiquote runs code inside one: `#(,(exit 0)).
  (define (early-exits datum)
    (cond
      ((pair? datum)
       (append (if (and (eq? (car datum) 'exit) (not (equal? datum '(exit 1))))
                   (list datum)
                   '())
               (let walk ((rest datum))
                 (cond ((pair? rest) (append (early-exits (car rest)) (walk (cdr rest))))
                       ((vector? rest) (early-exits rest))
                       (else '())))))
      ((vector? datum) (apply append (map early-exits (vector->list datum))))
      (else '())))

  (define (all-but-last xs)
    (reverse (cdr (reverse xs))))

  ;; --- check-imports -------------------------------------------------------

  ;; import-complaints : String -> (Listof Complaint)
  ;; What keeps the tree at ROOT from being plain R6RS libraries that import
  ;; only (rnrs ...) and (threading ...). Each complaint's path is relative to
  ;; ROOT; "." is ROOT itself. The rules, for each file in path order:
  ;;
  ;;   not-regular   a link or anything else that is not a regular file or a
  ;;                 directory
  ;;   file-name     not named STEM.sls with no other dot: Chez prefers
  ;;                 STEM.chezscheme.sls and STEM.ss to STEM.sls, so either
  ;;                 would shadow the portable file, and anything else is no
  ;;                 library
  ;;   unreadable    not UTF-8, or the reader raised
  ;;   header        its first line is not exactly #!r6rs
  ;;   hash-bang     #! appears after the first line: #!chezscheme there
  ;;                 would switch the reader to Chez's syntax
  ;;   library-form  it is not exactly one (library NAME (export ...)
  ;;                 (import ...) ...) form
  ;;   name          NAME is not the one its path gives, or carries a version
  ;;   import        an import names a library outside (rnrs ...) and
  ;;                 (threading ...), however it is wrapped; names (rnrs
  ;;                 eval), whose environment reaches any library at run
  ;;                 time; names a (threading ...) library no file under ROOT
  ;;                 holds, which would load from elsewhere on the path; or
  ;;                 cannot be read
  ;;
  ;; and then, for ROOT itself, not-a-directory, or no-library when no file
  ;; is named as a library. Litter an OS or an editor leaves is passed over
  ;; (litter?).
  (define (import-complaints root)
    (if (not (directory? root))
        (list (list "." 'not-a-directory (string-append root " is not a directory")))
        (let* ((entries (walk root ""))
               (names (map (lambda (e) (path->library-name (car e)))
                           (library-entries entries)))
               (complaints
                (apply append
                       (map (lambda (entry)
                              (let ((rel (car entry)) (kind (cdr entry)))
                                (cond
                                  ((not (eq? kind 'file))
                                   (list (list rel 'not-regular
                                               "it is neither a regular file nor a directory")))
                                  ((not (library-file-name? rel))
                                   (list (list rel 'file-name
                                               "a file under src/ is named STEM.sls, with no other dot")))
                                  (else (library-complaints root rel names)))))
                            entries))))
          (if (null? (library-entries entries))
              (append complaints
                      (list (list "." 'no-library "it holds no file named as a library")))
              complaints))))

  ;; library-files : String -> (Listof String)
  ;; The paths, relative to ROOT, of the files under it named as libraries.
  (define (library-files root)
    (if (directory? root)
        (map car (library-entries (walk root "")))
        '()))

  (define (library-entries entries)
    (filter (lambda (e) (and (eq? (cdr e) 'file) (library-file-name? (car e))))
            entries))

  ;; A link to a directory is no directory here: links are not followed.
  (define (directory? path)
    (file-directory? path #f))

  ;; walk : String String -> (Listof (Pair String (U 'file 'other)))
  ;; Every entry under ROOT/REL that is neither a directory nor litter, with
  ;; its path relative to ROOT, sorted by that path: threading.sls comes
  ;; before threading/private.sls. Links are not followed: a link is 'other.
  (define (walk root rel)
    (sort (lambda (a b) (string<? (car a) (car b)))
          (walk-unsorted root rel)))

  (define (walk-unsorted root rel)
    (let ((dir (if (string=? rel "") root (string-append root "/" rel))))
      (apply append
             (map (lambda (name)
                    (let ((child-rel (if (string=? rel "") name (string-append rel "/" name)))
                          (full (string-append dir "/" name)))
                      (cond
                        ((file-directory? full #f) (walk-unsorted root child-rel))
                        ((litter? name) '())
                        ((file-regular? full #f) (list (cons child-rel 'file)))
                        (else (list (cons child-rel 'other))))))
                  (directory-list dir)))))

  ;; litter? : String -> Boolean
  ;; A file name an OS or an editor leaves beside the sources: a dot file,
  ;; such as .DS_Store or Emacs's .#NAME lock link; an #autosave#; a backup~.
  ;; No library name maps to such a file under any of Chez's library
  ;; extensions, so nothing can load it. Directories are walked whatever
  ;; their names.
  (define (litter? name)
    (let ((n (string-length name)))
      (and (> n 0)
           (or (char=? (string-ref name 0) #\.)
               (char=? (string-ref name 0) #\#)
               (char=? (string-ref name (- n 1)) #\~)))))

  (define (library-file-name? rel)
    (let* ((base (last-component rel))
           (n (string-length base)))
      (and (> n 4)
           (string=? (substring base (- n 4) n) ".sls")
           (not (memv #\. (string->list (substring base 0 (- n 4))))))))

  (define (last-component rel)
    (let loop ((i (- (string-length rel) 1)))
      (cond ((< i 0) rel)
            ((char=? (string-ref rel i) #\/) (substring rel (+ i 1) (string-length rel)))
            (else (loop (- i 1))))))

  ;; split : String Char -> (Listof String)
  (define (split s c)
    (let loop ((i 0) (start 0) (parts '()))
      (cond ((= i (string-length s))
             (reverse (cons (substring s start i) parts)))
            ((char=? (string-ref s i) c)
             (loop (+ i 1) (+ i 1) (cons (substring s start i) parts)))
            (else (loop (+ i 1) start parts)))))

  ;; The library name REL's path gives: "threading/private.sls" is
  ;; (threading private).
  (define (path->library-name rel)
    (let* ((parts (split rel #\/))
           (base (car (reverse parts)))
           (stem (substring base 0 (- (string-length base) 4))))
      (map string->symbol (append (all-but-last parts) (list stem)))))

  (define (library-complaints root rel names)
    (let ((text (read-file-text (string-append root "/" rel))))
      (if (not (string? text))
          (list (list rel 'unreadable (string-append "it cannot be read as UTF-8: " (cadr text))))
          (let* ((newline-at (string-index text #\newline))
                 (first-line (if newline-at (substring text 0 newline-at) text))
                 (rest (if newline-at
                           (substring text (+ newline-at 1) (string-length text))
                           "")))
            (append
             (if (string=? first-line "#!r6rs")
                 '()
                 (list (list rel 'header
                             (string-append "its first line is " (written first-line)
                                            ", not \"#!r6rs\""))))
             (if (string-contains? rest "#!")
                 (list (list rel 'hash-bang
                             "#! appears after the first line; only the #!r6rs header may use it"))
                 '())
             (let ((found (read-string-data text)))
               (if (eq? (car found) 'unreadable)
                   (list (list rel 'unreadable
                               (string-append "it cannot be read as data: " (cadr found))))
                   (form-complaints rel (cadr found) names))))))))

  (define (form-complaints rel data names)
    (let ((form (and (= (length data) 1) (car data))))
      (if (not (library-form? form))
          (list (list rel 'library-form
                      (string-append "it holds " (number->string (length data))
                                     " data; a file under src/ holds one"
                                     " (library NAME (export ...) (import ...) ...) form")))
          (append (name-complaints rel (cadr form))
                  (apply append (map (lambda (spec) (import-spec-complaints rel spec names))
                                     (cdr (cadddr form))))))))

  (define (library-form? form)
    (and (list? form)
         (>= (length form) 4)
         (eq? (car form) 'library)
         (list? (caddr form)) (pair? (caddr form)) (eq? (car (caddr form)) 'export)
         (list? (cadddr form)) (pair? (cadddr form)) (eq? (car (cadddr form)) 'import)))

  (define (name-complaints rel name)
    (let ((expected (path->library-name rel)))
      (cond
        ((not (and (list? name) (pair? name)))
         (list (list rel 'name (string-append "its name " (written name) " is not a list"))))
        ((not (for-all symbol? name))
         (list (list rel 'name (string-append "its name " (written name)
                                              " carries a version; name it "
                                              (written expected)))))
        ((not (equal? name expected))
         (list (list rel 'name (string-append "it declares " (written name)
                                              ", but its path makes it " (written expected)))))
        (else '()))))

  ;; NAMES are the library names the files under ROOT give, by their paths.
  (define (import-spec-complaints rel spec names)
    (let ((ref (import-reference spec)))
      (cond
        ((not ref)
         (list (list rel 'import (string-append "it cannot read the import spec " (written spec)))))
        ((and (eq? (car ref) 'rnrs) (pair? (cdr ref)) (eq? (cadr ref) 'eval))
         (list (list rel 'import
                     (string-append "it imports " (written ref)
                                    ", whose environment reaches any library at run time"))))
        ((eq? (car ref) 'rnrs) '())
        ((eq? (car ref) 'threading)
         (if (member ref names)
             '()
             (list (list rel 'import
                         (string-append "it imports " (written ref)
                                        ", which no file under src/ holds")))))
        (else
         (list (list rel 'import
                     (string-append "it imports " (written ref)
                                    "; a library under src/ imports only (rnrs ...)"
                                    " and (threading ...)")))))))

  ;; import-reference : Any -> (U (Listof Any) #f)
  ;; The library reference an import spec names, through for, library, only,
  ;; except, prefix and rename however deeply, or #f when SPEC has no such
  ;; shape. A reference is a list whose first element is a symbol.
  (define (import-reference spec)
    (define (reference r)
      (and (list? r) (pair? r) (symbol? (car r)) r))
    (define (from-set s)
      (and (list? s) (pair? s)
           (case (car s)
             ((library) (and (= (length s) 2) (reference (cadr s))))
             ((only except prefix rename) (and (>= (length s) 2) (from-set (cadr s))))
             (else (reference s)))))
    (if (and (list? spec) (pair? spec) (eq? (car spec) 'for))
        (and (>= (length spec) 2) (from-set (cadr spec)))
        (from-set spec)))

  ;; --- reading -------------------------------------------------------------

  (define (strict-utf-8)
    (make-transcoder (utf-8-codec) (eol-style none) (error-handling-mode raise)))

  ;; read-file-text : String -> (U String (List 'unreadable String))
  (define (read-file-text path)
    (guard (e (#t (list 'unreadable (describe e))))
      (call-with-port (open-file-input-port path (file-options) (buffer-mode block)
                                            (strict-utf-8))
        (lambda (port)
          (let ((s (get-string-all port)))
            (if (eof-object? s) "" s))))))

  ;; read-file-data : String -> (U (List 'data (Listof Any)) (List 'unreadable String))
  (define (read-file-data path)
    (let ((text (read-file-text path)))
      (if (string? text)
          (read-string-data text)
          text)))

  (define (read-string-data text)
    (guard (e (#t (list 'unreadable (describe e))))
      (let ((port (open-string-input-port text)))
        (let loop ((found '()))
          (let ((datum (read port)))
            (if (eof-object? datum)
                (list 'data (reverse found))
                (loop (cons datum found))))))))

  (define (string-index s c)
    (let loop ((i 0))
      (cond ((= i (string-length s)) #f)
            ((char=? (string-ref s i) c) i)
            (else (loop (+ i 1))))))

  (define (string-contains? s needle)
    (let ((n (string-length s)) (m (string-length needle)))
      (let loop ((i 0))
        (cond ((> (+ i m) n) #f)
              ((string=? (substring s i (+ i m)) needle) #t)
              (else (loop (+ i 1))))))))
