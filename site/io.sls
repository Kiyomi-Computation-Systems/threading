#!r6rs
;; NOT pure: this library owns the generator's filesystem access.
(library (site io)
  (export read-site-inputs write-site)
  (import (rnrs) (site pages) (site render) (site serializer))

  (define (slurp path)
    (call-with-input-file path
      (lambda (p)
        (let loop ((cs '()) (c (get-char p)))
          (if (eof-object? c)
              (list->string (reverse cs))
              (loop (cons c cs) (get-char p)))))))
  (define (source-path name) (string-append "docs/" name))

  ;; read-site-inputs : -> (Listof (Pairof String String))
  ;; Read every source in (site pages)'s declared order.
  (define (read-site-inputs)
    (map (lambda (entry)
           (let ((name (car entry))) (cons name (slurp (source-path name)))))
         pages))

  ;; write-site : SiteResult String -> Unspecified
  ;; Write each fully rendered page in UTF-8, replacing a previous output.
  (define (write-site result out-dir)
    (for-each
     (lambda (pg)
       (let ((p (open-file-output-port
                 (string-append out-dir "/" (page-file-name (car pg)))
                 (file-options no-fail))))
         (put-bytevector p
                         (string->utf8
                          (string-append "<!doctype html>\n" (sxml->html (cdr pg)))))
         (close-port p)))
     (site-result-pages result))))
