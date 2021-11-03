(define-library (c-format)
  (export c-format
          c-format-fold)
  (import (scheme base))
  (begin

    (define (c-format-fold merge state s)
      (define (ascii-alphabetic? char)
        (or (char<=? #\a char #\z) (char<=? #\A char #\Z)))
      (define (ascii-non-control? char)
        (<= #x20 (char->integer char) #x7E))
      (let outer ((a 0) (b 0) (state state))
        (cond ((= a b (string-length s))
               state)
              ((= b (string-length s))
               (outer b b (merge #f (substring s a b) state)))
              ((not (char=? #\% (string-ref s b)))
               (outer a (+ b 1) state))
              ((< a b)
               (outer b b (merge #f (substring s a b) state)))
              (else
               (let inner ((a (+ b 1)) (b (+ b 1)))
                 (if (= b (string-length s))
                     (error "Truncated format string" s)
                     (let ((char (string-ref s b)))
                       (cond ((or (ascii-alphabetic? char) (char=? #\% char))
                              (outer (+ b 1) (+ b 1)
                                     (merge char (substring s a b) state)))
                             ((ascii-non-control? char)
                              (inner a (+ b 1)))
                             (else
                              (error "Bad format directive" s))))))))))

    (define (c-format format-string . args)
      (call-with-port
       (open-output-string)
       (lambda (out)
         (define (merge directive specific args)
           (define (handle valid? stringify)
             (cond ((pair? args)
                    (write-string (stringify (car args)) out)
                    (cdr args))
                   (else
                    (error "Not valid"))))
           (case directive
             ((#f)
              (write-string specific out)
              args)
             ((#\%)
              (write-char #\% out)
              args)
             ((#\d)
              (handle exact-integer? (lambda (val) (number->string val))))
             ((#\s)
              (handle string? (lambda (val) val)))
             ((#\f)
              (handle real? (lambda (val) (number->string (inexact val)))))
             ((#\x)
              (handle exact-integer?
                      (lambda (val)
                        (string-downcase (number->string val 16)))))
             ((#\X)
              (handle exact-integer?
                      (lambda (val)
                        (string-upcase (number->string val 16)))))
             (else
              (error "Unknown c-format directive"))))
         (let ((args (c-format-fold merge args format-string)))
           (if (null? args)
               (get-output-string out)
               (error "Format string did not consume all args"))))))))
