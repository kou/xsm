(define-module xsm.xml-rpc.client
  (extend xsm.xml-rpc.common)
  (use srfi-1)
  (use srfi-11)
  (use srfi-13)
  (use rfc.uri)
  (use text.tree)
  (use sxml.tools)
  (use sxml.tree-trans)
  (use gauche.net)
  (use xsm.xml-rpc.marshal)
  (use xsm.xml-rpc.http)
  (export make-xml-rpc-client
          xml-rpc-client-call call))
(select-module xsm.xml-rpc.client)

(define (uri-parse uri)
  (define (filter-non-empty-string str)
    (and (string? str)
         (not (string-null? str))
         str))

  (define (convert-if-not-false obj converter)
    (and obj (converter obj)))
  
  (receive (scheme specific)
      (uri-scheme&specific uri)
    (receive (authority path query fragment)
        (uri-decompose-hierarchical specific)
      (receive (user-info host port)
          (uri-decompose-authority authority)
        (values (convert-if-not-false scheme string->symbol)
                user-info
                (filter-non-empty-string host)
                (convert-if-not-false port string->number)
                (filter-non-empty-string path)
                query
                fragment)))))

(define-class <xml-rpc-client> ()
  ((host :accessor host-of :init-keyword :host)
   (port :accessor port-of :init-keyword :port)
   (path :accessor path-of :init-keyword :path)
   (timeout :accessor timeout-of :init-keyword :timeout)))

(define (make-xml-rpc-client uri . keywords)
  (receive (scheme user-info host port path query fragment)
      (uri-parse uri)
    (unless (eq? 'http scheme)
      (errorf "not supported scheme: <~a>" scheme))
    (unless host
      (errorf "host does not specified"))
    (unless path
      (errorf "path does not specified"))
    (make <xml-rpc-client>
      :host host
      :port (or port 80)
      :path path
      :timeout (get-keyword :timeout keywords '(0 500000)))))

(define (sxml->xml local-rules sxml output)
  (define this-ss
    (append local-rules
            `((*TOP* . ,(lambda (trigger . value) value))
              (*PI* . ,(lambda (trigger pi-target . elems)
                         (list "<?" pi-target " "
                               (string-join
                                (map (lambda (elem)
                                       (string-join
                                        (list (x->string (car elem))
                                              #`"\",(sxml:string->xml (cadr elem))\"")
                                        "="))
                                     elems)
                                " ")
                               "?>"
                               #\newline)))
              (*default* *preorder* .
                         ,(lambda (tag . elems) 
                            (let*-values
                                (((attrs content)
                                  (if (and (pair? elems) (pair? (car elems))
                                           (eq? '@ (caar elems)))
                                    (values (car elems) (cdr elems))
                                    (values '() elems)))) ; no attributes
                              (entag tag
                                     (if (null? attrs)
                                       attrs
                                       (cdr (pre-post-order attrs this-ss)))
                                     (pre-post-order content this-ss)))))
              (*text* . ,(lambda (trigger str)
                           (if (string? str) (sxml:string->xml str) str))))))
  (with-output-to-port output
    (lambda ()
      (SRV:send-reply (pre-post-order sxml this-ss)))))

(define (entag tag attrs content)
  (if (null? content)
    (list #\< tag attrs "/>")
    (list (if (eq? tag 'methodName) ;; bug for PHP
            " "
            "")
          #\< tag attrs #\> content "</" tag #\>)))

(define (make-request name . args)
  (call-with-output-string
    (lambda (output)
      (sxml->xml
       '()
       `(*TOP*
         (*PI* xml
               ("version" "1.0")
               ("encoding" ,(symbol->string (gauche-character-encoding))))
         (methodCall
          (methodName ,(x->string name))
          (params ,@(map (lambda (arg)
                           `(param ,(marshal-value arg)))
                         args))))
       output))))

(define (xml-rpc-client-call client name . args)
  (let* ((socket (make-client-socket 'inet (host-of client) (port-of client)))
         (in (socket-input-port socket))
         (out (socket-output-port socket))
         (body (apply make-request name args))
         (headers `(("Host" ,(host-of client))
                    ("User-Agent" ,#`"xsm.xml-rpc.client/,|*xml-rpc-version*|")
                    ("Content-Type" "text/xml")
                    ("Content-Length" ,(number->string (string-size body))))))
    (dynamic-wind
        (lambda () #f)
        (lambda ()
          (http-request (path-of client) headers body out)
          (http-response-parse in))
        (lambda ()
          (unless (eq? 'shutdown (socket-status socket))
            (socket-shutdown socket 2))))))

(define-method call ((self <xml-rpc-client>) name . args)
  (apply xml-rpc-client-call self name args))

(provide "xsm/xml-rpc/client")
