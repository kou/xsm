#!/usr/local/bin/gosh

(add-load-path "/home/kou/local/share/gauche/site/lib/")
(use xsm.xml-rpc.server.cgi)

(define (main args)
  (xml-rpc-server-cgi-main
   `(("calc.add" ,(lambda (x y) (+ x y)))
     ("calc.sub" ,(lambda (x y) (- x y)))
     ("calc.multi" ,(lambda (x y) (* x y)))
     ("calc.div" ,(lambda (x y) (/ x y))))))
