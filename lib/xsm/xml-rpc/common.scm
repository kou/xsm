(define-module xsm.xml-rpc.common
  (extend xsm.xml-rpc)
  (use rfc.base64)
  (export make-base64-encoded-string encoded-string-of))
(select-module xsm.xml-rpc.common)

(define-class <base64> ()
  ((string :accessor string-of :init-keyword :string)
   (encoded-string :accessor encoded-string-of)))

(define-method initialize ((self <base64>) args)
  (next-method)
  (set! (encoded-string-of self)
        (base64-encode-string (string-of self))))

(define (make-base64-encoded-string str)
  (make <base64> :string str))

(provide "xsm/xml-rpc/common")
