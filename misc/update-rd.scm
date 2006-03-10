#!/usr/bin/env gosh

(use rfc.uri)
(use file.util)
(use gauche.charconv)
(use xsm.xml-rpc.client)

(define host "www.cozmixng.org")
(define port 80)
(define path "/~rwiki/wikirpc.cgi")

(define (name->wiki-name name)
  (if name
    (ces-convert #`"xsm::,|name|" "*JP" "UTF-8")
    "xsm"))

(define (read-source server name)
  (let* ((wiki-name (name->wiki-name name))
         (prev-handler (current-exception-handler))
         (source
          (let/cc return
            (with-exception-handler
                (lambda (e)
                  (if (#/string=No such page was found./ (ref e 'message))
                    (begin
                      (print #`",wiki-name was not found.")
                      (return ""))
                    (prev-handler e)))
              (lambda ()
                (xml-rpc-client-call server "wiki.getPage"
                                     :encoding "UTF-8" wiki-name))))))
    (ces-convert source "UTF-8" (gauche-character-encoding))))

(define (update-source server name new)
  (let ((wiki-name (name->wiki-name name)))
    (print #`"updating ,wiki-name")
    (xml-rpc-client-call server "wiki.putPage" :encoding "UTF-8"
                         wiki-name new (make-hash-table))))

(define (update-rd server name)
  (let ((old (read-source server name))
        (new (port->string (open-input-file name :encoding "*JP"))))
    (unless (string=? old new)
      (update-source server name new))))

(define (update-index server old-version new-version)
  (let* ((name #f)
         (old (read-source server name))
         (new (regexp-replace-all (string->regexp old-version)
                                  old new-version)))
    (unless (string=? old new)
      (update-source server name new))))

(define (main args)
  (let ((server (make-xml-rpc-client (uri-compose :scheme "http" :host host
						  :port port :path path)))
        (prev-handler (current-exception-handler)))
    (with-exception-handler
        (lambda (e)
          (use gauche.interactive)
          (d e)
          (prev-handler e))
      (lambda ()
        (update-index server (cadr args) (caddr args))
        (update-rd server "README.ja")
        (update-rd server "README.en")
        0))))
