#!/usr/bin/env gosh

(define-module xml-rpc-parser-test
  (use srfi-1)
  (use srfi-19)
  (use rfc.base64)
  (use test.unit)
  (use sxml.tools)
  (use text.tree)
  (extend xsm.xml-rpc.parser))
(select-module xml-rpc-parser-test)

(define-method object-equal? ((self <date>) (other <date>))
  (every (lambda (accessor)
           (= (accessor self) (accessor other)))
         (list date-nanosecond
               date-second
               date-minute
               date-hour
               date-day
               date-month
               date-year
               date-zone-offset)))

(define-assertion (assert-struct field-infos struct)
  (every (lambda (field-info)
           (receive (name value)
               (apply values field-info)
             (assert-equal value (hash-table-get struct name))))
         field-infos))

(define-assertion (assert-error-message expected thunk)
  (let ((result (with-error-handler
                    (lambda (e)
                      (if (equal? expected (ref e 'message))
                        #t
                        (make-assertion-failure
                         ((make-message-handler expected)
                          (ref e 'message)))))
                  (lambda ()
                    (thunk)
                    (fail "error wasn't occurred")))))
    result))

(define-test-case "XML-RPC parser test"
  ("parse-value test"
   (assert-equal 1 (parse-value '(value (i4 "1"))))
   (assert-equal 3 (parse-value '(value (int "3"))))
   (assert-equal -5 (parse-value '(value (int "-5"))))
   
   (assert-false (parse-value '(value (boolean "0"))))
   (assert-true (parse-value '(value (boolean "1"))))
   (assert-error (lambda () (parse-value '(value (boolean "2")))))

   (assert-equal "abc" (parse-value '(value (string "abc"))))
   (assert-equal "abc" (parse-value '(value "abc")))

   (assert-equal 1.0 (parse-value '(value (double "1"))))
   (assert-equal -3.14 (parse-value '(value (double "-3.14"))))
   
   (assert-equal (make-date 0 55 8 14 17 7 1998 0)
                 (parse-value '(value (dateTime.iso8601 "19980717T14:08:55"))))

   (assert-equal "abcde"
                 (parse-value `(value (base64
                                       ,(base64-encode-string "abcde")))))

   (assert-struct '((a 1) (b "abc") (c 1.0))
                  (parse-value '(value (struct (member (name "a")
                                                       (value (int "1")))
                                               (member (name "b")
                                                       (value (string "abc")))
                                               (member (name "c")
                                                       (value (double "1.0")))))))
   (assert-equal '#(1 "abc" -1.0)
                 (parse-value '(value (array (data (value (int "1"))
                                                   (value (string "abc"))
                                                   (value (double "-1.0")))))))
   (assert-equal '#(1 #("abc" -1.0))
                 (parse-value
                  '(value
                    (array
                     (data (value (int "1"))
                           (value (array
                                   (data (value (string "abc"))
                                         (value (double "-1.0")))))))))))
  ("parse-member test"
   (assert-equal '(x 1)
                 (parse-member '(member (name "x") (value (int "1"))))))
  ("parse-members test"
   (assert-equal '((x 1))
                 (parse-members '((member (name "x") (value (int "1"))))))
   (assert-equal '((x 1) (y "abc") (z "xyz"))
                 (parse-members '((member (name "x")
                                          (value (int "1")))
                                  (member (name "y")
                                          (value "abc"))
                                  (member (name "z")
                                          (value (string "xyz")))))))
  ("parse-param test"
   (assert-equal "South Dakota"
                 (parse-param '(param (value (string "South Dakota"))))))
  ("parse-params test"
   (assert-equal '("South Dakota" -3.14)
                 (parse-params '(params (param (value (string "South Dakota")))
                                        (param (value (double "-3.14")))))))
  ("parse-fault test"
   (assert-error-message
    "XML-RPC FAULT: code=4; string=Too many parameters."
    (lambda ()
      (parse-fault '(fault
                     (value
                      (struct
                       (member (name "faultCode")
                               (value (int "4")))
                       (member (name "faultString")
                               (value (string "Too many parameters."))))))))))
  ("parse-response test"
   (assert-values-equal
    '("South Dakota")
    (lambda ()
      (parse-response '(methodResponse
                        (params
                         (param
                          (value (string "South Dakota"))))))))
   (assert-error-message
    "XML-RPC FAULT: code=4; string=Too many parameters."
    (lambda ()
      (parse-response
       '(methodResponse
         (fault
          (value
           (struct
            (member (name "faultCode")
                    (value (int "4")))
            (member (name "faultString")
                    (value (string "Too many parameters.")))))))))))
  ("parse-method-response test"
   (assert-values-equal
    '("South Dakota")
    (lambda ()
      (parse-method-response
       '(*TOP*
         (methodResponse
          (params
           (param
            (value (string "South Dakota")))))))))
   (assert-error-message
    "XML-RPC FAULT: code=4; string=Too many parameters."
    (lambda ()
      (parse-method-response
       '(*TOP*
         (methodResponse
          (fault
           (value
            (struct
             (member (name "faultCode")
                     (value (int "4")))
             (member (name "faultString")
                     (value (string "Too many parameters.")))))))))))))
