#!/usr/bin/env gosh

(define-module xml-rpc-server-test
  (use test.unit)
  (use sxml.ssax)
  (extend xsm.xml-rpc.server))
(select-module xml-rpc-server-test)

'(define-test-case "XML-RPC client test"
  ("make-request test"
   (assert-equal `(*TOP*
                   (*PI* xml ,#`"version=\"1.0\" encoding=\",(gauche-character-encoding)\"")
                   (methodCall
                    (methodName "examples.getStateName")
                    (params
                     (param (value (int "41")))
                     (param (value (double "-41.41"))))))
                 (ssax:xml->sxml
                  (open-input-string
                   (make-request "examples.getStateName" 41 -41.41))
                  '()))))
