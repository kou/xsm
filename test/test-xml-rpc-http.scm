#!/usr/bin/env gosh

(define-module xml-rpc-http-test
  (use srfi-1)
  (use srfi-19)
  (use rfc.base64)
  (use test.unit)
  (use sxml.tools)
  (use text.tree)
  (extend xsm.xml-rpc.http))
(select-module xml-rpc-http-test)

(define-test-case "xml-rpc.http test"
  )
