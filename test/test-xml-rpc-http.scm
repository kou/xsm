#!/usr/bin/env gosh

(define-module xml-rpc-http-test
  (use test.unit)
  (extend xsm.xml-rpc.http))
(select-module xml-rpc-http-test)

(define (%http-header-read str)
  (http-header-read (open-input-string str)))

(define (%http-header-parse str)
  (http-header-parse (open-input-string str)))

(define-assertion (assert-http-error code phrase str)
  (define (%http-header-read str)
    ((with-module xsm.xml-rpc.http http-header-read)
     (open-input-string str)))
  
  (assert-raise (with-module xsm.xml-rpc.http <http-error>)
                (lambda ()
                  (%http-header-read str)))

  (with-exception-handler
      (lambda (e)
        (and (equal? code (ref e 'code))
             (equal? phrase (ref e 'phrase))))
    (lambda ()
      (%http-header-read "HTTP/1.1 500 Internal Server Error"))))

(define-test-case "xml-rpc.http test"
  ("http-header-read test"
   (assert-equal '()
                 (%http-header-read "HTTP/1.1 200 OK"))
   (assert-raise <not-supported-http-version>
                 (lambda () (%http-header-read "HTTP/0.1 200 OK")))
   (assert-http-error 500 "Internal Server Eror"
                      "HTTP/1.1 500 Internal Server Error")

   (assert-lset-equal
    '(("CONNECTION" . "close")
      ("CONTENT_LENGTH" . "158")
      ("CONTENT_TYPE" . "text/xml")
      ("DATE" . "Fri, 17 Jul 1998 19:55:08 GMT")
      ("SERVER" . "UserLand Frontier/5.1.2-WinNT"))
    (%http-header-read
     (string-join (list "HTTP/1.1 200 OK"
                        "Connection: close"
                        "Content-Length: 158"
                        "Content-Type: text/xml"
                        "Date: Fri, 17 Jul 1998 19:55:08 GMT"
                        "Server: UserLand Frontier/5.1.2-WinNT")
                  "\n"))))
  
  ("http-header-parse test"
   (assert-equal 159
                 (%http-header-parse
                  (string-join (list "HTTP/1.1 200 OK"
                                     "Connection: close"
                                     "Content-Length: 159"
                                     "Content-Type: text/xml"
                                     "Date: Fri, 17 Jul 1998 19:55:08 GMT"
                                     "Server: UserLand Frontier/5.1.2-WinNT")
                               "\n")))
   (assert-raise
    <invalid-content-type>
    (lambda ()
      (%http-header-parse
       (string-join (list "HTTP/1.1 200 OK"
                        "Connection: close"
                        "Content-Length: 158"
                        "Content-Type: text/xml; charset=UTF-8"
                        "Date: Fri, 17 Jul 1998 19:55:08 GMT"
                        "Server: UserLand Frontier/5.1.2-WinNT")
                    "\n"))))
   (assert-raise
    <invalid-content-length>
    (lambda ()
      (%http-header-parse
       (string-join (list "HTTP/1.1 200 OK"
                        "Connection: close"
                        "Content-Length: aaa"
                        "Content-Type: text/xml"
                        "Date: Fri, 17 Jul 1998 19:55:08 GMT"
                        "Server: UserLand Frontier/5.1.2-WinNT")
                    "\n"))))))
