(define-module xsm.xml-rpc.server
  (extend xsm.xml-rpc.common)
  (use srfi-1)
  (use srfi-11)
  (use srfi-13)
  (use rfc.uri)
  (use util.list)
  (use text.tree)
  (use gauche.net)
  (use xsm.xml-rpc.marshal)
  (use xsm.xml-rpc.http)
  (export make-xml-rpc-server
          xml-rpc-server-call call))
(select-module xsm.xml-rpc.server)

(define-class <xml-rpc-server-mount-table> ()
  ((table :accessor table-of :init-form (make-hash-table 'string=?))))

(define (mount mount-table name value)
  (hash-table-put! (table-of mount-table) name value))

(define (handle-request mount-table name . args)
  (with-error-handler
      (lambda (e)
        (make-fault-response 444 ;;; Uhmm...
                             (ref e 'message)))
    (lambda ()
      (make-success-response
       (apply (hash-table-get (table-of mount-table) name)
              args)))))

(define-class <xml-rpc-server> ()
  ((host :accessor host-of :init-keyword :host)
   (port :accessor port-of :init-keyword :port)
   (path :accessor path-of :init-keyword :path)
   (timeout :accessor timeout-of :init-keyword :timeout)))

(define (make-xml-rpc-server uri . keywords)
  (receive (scheme user-info host port path query fragment)
      (uri-parse uri)
    (unless (eq? 'http scheme)
      (errorf "not supported scheme: <~a>" scheme))
    (unless host
      (errorf "host does not specified"))
    (unless path
      (errorf "path does not specified"))
    (make <xml-rpc-server>
      :host host
      :port (or port 80)
      :path path
      :timeout (get-keyword :timeout keywords '(0 500000)))))

(define (make-response content)
  (call-with-output-string
    (lambda (output)
      (sxml->xml
       '()
       `(*TOP*
         (*PI* xml
               ("version" "1.0")
               ("encoding" ,(symbol->string (gauche-character-encoding))))
         (methodResponse ,content))
       output))))

(define (make-success-response result)
  (make-response 
   `(params
     (param ,(marshal-value result)))))

(define (make-fault-response code phrase)
  (make-response 
   `(fault
     ,(marshal-value (alist->hash-table `((faultCode . ,code)
                                          (faultString . phrase)))))))

(provide "xsm/xml-rpc/server")
