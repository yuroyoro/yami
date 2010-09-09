;2��ɾ�����ʤ�����
(define apply-in-underlying-scheme apply)
(define eval-in-underlying-scheme eval)
;;2��ɾ�����ʤ�����

(define (eval exp env)
  ((analyze exp) env))

(define (analyze exp)
  (cond ((self-evaluating? exp)
		 (analyze-self-evaluating exp))
		((quoted? exp) (analyze-quoted exp))
		((variable? exp) (analyze-variable exp))
		((assignment? exp) (analyze-assignment exp))
		((definition? exp) (analyze-definition exp))
		((if? exp) (analyze-if exp))
		((lambda? exp) (analyze-lambda exp))
		((begin? exp) (analyze-sequence (begin-actions exp)))
		((cond? exp) (analyze (cond->if exp)))
		((application? exp) (analyze-application exp))
		(else
		 (error "Unknown expression type -- ANALYZE" exp))))

(define (analyze-self-evaluating exp)
  (lambda (env) exp))

(define (analyze-quoted exp)
  (let ((qval (text-of-quoation exp)))
	(lambda (env) qval)))

(define (analyze-variable exp)
  (lambda (env) (lookup-variable-value exp env)))


(define (analyze-assignment exp)
  (let ((var (assignment-variable exp))
		(vproc (analyze (assignment-value exp))))
	(lambda (env)
	  (set-variable-value! var (vproc env) env)
	'ok)))


(define (analyze-definition exp)
  (let ((var (definition-variable exp))
		(vproc (analyze (definition-value exp))))
	(lambda (env)
	  (define-variable! var (vproc env) env)
	'ok)))


(define (analyze-if exp)
  (let ((pproc (analyze (if-predicate exp)))
		(cproc (analyze (if-consequent exp)))
		(aproc (analyze (if-alternative exp))))
	(lambda (env)
	  (if (true? (pproc env))
		  (cproc env)
		  (aproc env)))))

(define (analyze-lambda exp)
  (let ((vars (lambda-parameters exp))
		(bproc (analyze-sequence (lambda-body exp))))
	(lambda (env) (make-procedure vars bproc env))))

(define (analyze-sequence exps)
  (define (sequentially proc1 proc2)
	(lambda (env) (proc1 env) (proc2 env)))
  (define (loop first-proc rest-procs)
	(if (null? rest-procs)
		first-proc
		(loop (sequentially first-proc (car rest-procs))
			  (cdr rest-procs))))
  (let ((procs (map analyze exps)))
	(if (null? procs)
		(error "Empty sequence -- ANALYZE"))
	(loop (car procs) (cdr procs))))


(define (analyze-application exp)
  (let ((pproc (analyze (operator exp)))
		(aprocs (map analyze (operands exp))))

	(lambda (env)
	  (execute-application (pproc env)
						   (map (lambda (aproc) (aproc env))
								aprocs)))))

(define (execute-application proc args)
  (cond ((primitive-procedure? proc)
		 (apply-primitive-procedure proc args))
		(compound-procedure?
		 ((procedure-body proc)
		  (extend-environment (procedure-parameters proc)
							  args
							  (procedure-environment proc))))
		(else
		 (error 
		  "Unknown procedure type -- EXECUTE-APPLICATION"
		  proc))))


(define true #t)
(define false #f)

(define (self-evaluating? exp)
  (cond ((number? exp) true)
		((string? exp) true)
		(else false)))

(define (variable? exp) (symbol? exp))

(define (quoted? exp)
  (tagged-list? exp 'quote))

(define (text-of-quotation exp) (cadr exp))

(define (tagged-list? exp tag)
  (if (pair? exp)
	  (eq? (car exp) tag)
	  false))

(define (assignment? exp)
  (tagged-list? exp 'set!))

(define (assignment-variable exp) (cadr exp))
(define (assignment-value exp) (caddr exp))

(define (definition? exp)
  (tagged-list? exp 'define))

(define (definition-variable exp)
  (if (symbol? (cadr exp))
	  (cadr exp)
	  (caadr exp)))

(define (definition-value exp)
  (if (symbol? (cadr exp))
	  (caddr exp)
	  (make-lambda (cdadr exp)
				   (cddr exp))))

(define (lambda? exp) (tagged-list? exp 'lambda))

(define (lambda-parameters exp) (cadr exp))
(define (lambda-body exp) (cddr exp))

(define (make-lambda parameters body)
  (cons 'lambda (cons parameters body)))

(define (if? exp) (tagged-list? exp 'if))

(define (if-predicate exp) (cadr exp))

(define (if-consequent exp) (caddr exp))

(define (if-alternative exp)
  (if (not (null? (cdddr exp)))
	  (cadddr exp)
	  'false))

(define (make-if predicate consequent alternative)
  (list 'if predicate consequent alternative))

(define (begin? exp) (tagged-list? exp 'begin))

(define (begin-actions exp) (cdr exp))
(define (last-exp? seq) (null? (cdr seq)))
(define (first-exp seq) (car seq))
(define (rest-exps seq) (cdr seq))

(define (sequence->exp seq)
  (cond ((null? seq) seq)
		((last-exp? seq) (first-exp seq))
		(else (make-begin seq))))

(define (make-begin seq)
  (cons 'begin seq))

(define (application? exp) (pair? exp))

(define (operator exp) (car exp))

(define (operands exp) (cdr exp))

(define (no-operands? ops) (null? ops))

(define (first-operand ops) (car ops))

(define (rest-operands ops) (cdr ops))
  
(define (cond? exp) (tagged-list? exp 'cond))

(define (cond-clauses exp) (cdr exp))

(define (cond-else-clauses? clause)
  (eq? (cond-predicate clause) 'else))

(define (cond-predicate clause) (car clause))

(define (cond-actions clause) (cdr clause))

(define (cond->if exp)
  (expand-clauses (cond-clauses exp)))

(define (expand-clauses clauses)
  (if (null? clauses)
	  'false
	  (let ((first (car clauses))
			(rest (cdr clauses)))
		(if (cond-else-clauses? first)
			(if (null? rest)
				(sequence->exp (cond-actions first))
				(error "ELSE clause isn't last -- COND->IF"
					   clauses))
			(make-if (cond-predicate first)
					 (sequence->exp (cond-actions first))
					 (expand-clauses rest))))))

(define (true? x)
  (not (eq? x false)))

(define (false? x)
  (eq? x false))

(define (make-procedure parameters body env)
  (list 'procedure parameters body env))

(define (compound-procedure? p)
  (tagged-list? p 'procedure))

(define (procedure-parameters p) (cadr p))
(define (procedure-body p) (caddr p))
(define (procedure-environment p) (cadddr p))

(define (enclosing-environment env) (cdr env))
(define (first-frame env) (car env))
(define the-empty-environment '())

(define (make-frame variables values)
  (cons variables values))

(define (frame-variables frame) (car frame))
(define (frame-values frame) (cdr frame))

(define (add-binding-to-frame! var val frame)
  (set-car! frame (cons var (car frame)))
  (set-cdr! frame (cons val (cdr frame))))

(define (extend-environment vars vals base-env)
  (if (= (length vars) (length vals))
	  (cons (make-frame vars vals) base-env)
	  (if (< (length vars) (length vals))
		  (error "Too many arguments supplied" vars vals)
		  (error "Too few arguments supplied" vars vals))))

(define (lookup-variable-value var env)
  (define (env-loop env)
	(define (scan vars vals)
	  (cond ((null? vars)
			 (env-loop (enclosing-environment env)))
			((eq? var (car vars))
			 (car vals))
			(else (scan (cdr vars) (cdr vals)))))
	(if (eq? env the-empty-environment)
		(error "Unbound variable" var)
		(let ((frame (first-frame env)))
		  (scan (frame-variables frame)
				(frame-values frame)))))
  (env-loop env))

(define (set-variable-value! var val env)
  (define (env-loop env)
	(define (scan vars vals)
	  (cond ((null? vars)
			 (env-loop (enclosing-environment env)))
			((eq? var (car vars))
			 (set-car! vals val))
			(else (scan (cdr vars) (cdr vals)))))
	(if (eq? env the-empty-environment)
		(error "Unbound variable -- SET!" var)
		(let ((frame (first-frame env)))
		  (scan (frame-variables frame)
				(frame-values frame)))))
  (env-loop env))

(define (define-variable! var val env)
  (let ((frame (first-frame env)))
	(define (scan vars vals)
	  (cond ((null? vars)
			 (add-binding-to-frame! var val frame))
			((eq? var (car vars))
			 (set-car! vals val))
			(else (scan (cdr vars) (cdr vals)))))
	(scan (frame-variables frame)
		  (frame-values frame))))

(define (primitive-procedure? proc)
  (tagged-list? proc 'primitive))

(define (primitive-implementation proc) (cadr proc))

(define primitive-procedures
  (list (list 'car car)
		(list 'cdr cdr)
		(list 'cadr cadr)
		(list 'caddr caddr)
		(list 'cons cons)
		(list 'null? null?)
		(list '+ +)
		(list '- -)
		(list '* *)
		(list '/ /)
		(list '= =)
		(list '< <)
		(list '> >)
		(list 'display display)
		(list 'newline newline)
		(list 'assoc assoc)
		(list 'eq? eq?)
		(list 'equal? equal?)
		(list 'list list)
		(list 'map map)
		;...
		))

(define (primitive-procedure-names)
  (map car 
	   primitive-procedures))

(define (primitive-procedure-objects)
  (map (lambda (proc) (list 'primitive (cadr proc)))
	   primitive-procedures))

(define (apply-primitive-procedure proc args)
  (apply-in-underlying-scheme 
   (primitive-implementation proc) args))

(define (setup-environment)
  (let ((initial-env
		 (extend-environment (primitive-procedure-names)
							 (primitive-procedure-objects)
							 the-empty-environment)))
	(define-variable! 'true true initial-env)
	(define-variable! 'false false initial-env)
	initial-env))

(define the-global-environment (setup-environment))



(define input-prompt ";;; M-Eval input:")
(define output-prompt ";;; M-Eval output:")

(define (driver-loop)
  (prompt-for-input input-prompt)
  (let ((input (read)))
	(let ((output (eval input the-global-environment)))
	  (announce-output output-prompt)
	  (user-print output)))
  (driver-loop))

(define (prompt-for-input string)
  (newline) (newline) (display string) (newline))

(define (announce-output string)
  (newline) (display string) (newline))

(define (user-print object)
  (if (compound-procedure? object)
	  (display (list 'compound-procedure
					 (procedure-parameters object)
					 (procedure-body object)
					 '<procedure-env>))
	  (display object)))

(define the-global-environment (setup-environment))


(define (make-lambda parameters body)
  (cons 'lambda (cons parameters body)))


(define (let? exp) (tagged-list? exp 'let))

(define (let->combination exp)
  (cons (make-lambda
		 (map car (cadr exp)) (cddr exp))
		(map cadr (cadr exp))))


(define (analyze exp)
  (cond ((self-evaluating? exp)
		 (analyze-self-evaluating exp))
		((quoted? exp) (analyze-quoted exp))
		((variable? exp) (analyze-variable exp))
		((assignment? exp) (analyze-assignment exp))
		((definition? exp) (analyze-definition exp))
		((if? exp) (analyze-if exp))
		((unless? exp) (analyze (unless->if exp)))
		((lambda? exp) (analyze-lambda exp))
		((let? exp)
		 (analyze (let->combination exp)))
		((begin? exp) 
		 (display 		 (analyze-sequence (begin-actions exp)))
		 (analyze-sequence (begin-actions exp)))
		((cond? exp) (analyze (cond->if exp)))
		((application? exp) (analyze-application exp))
		(else
		 (error "Unknown expression type -- ANALYZE" exp))))


(define (analyze-sequence exps)
  (define (sequentially proc1 proc2)
	(lambda (env) (proc1 env) (proc2 env)))
  (define (loop first-proc rest-procs)
	(if (null? rest-procs)
		first-proc
		(loop (sequentially first-proc (car rest-procs))
			  (cdr rest-procs))))
  (let ((procs (map analyze exps)))
	(if (null? procs)
		(error "Empty sequence -- ANALYZE"))
	(loop (car procs) (cdr procs))))




(define (analyze-sequence exps)
  (define (execute-sequence procs env)
	(cond ((null? (cdr procs)) ((car procs) env))
		  (else ((car procs) env)
				(execute-sequence (cdr procs) env))))
  (let ((procs (map analyze exps)))
	(if (null? procs)
		(error "Empty sequence -- ANALYZE"))
	(lambda (env) (execute-sequence procs env))))




(define (unless? exp) (tagged-list? exp 'unless)))

(define (unless-predicate exp) (cadr exp))

(define (unless-consequent exp) (caddr exp))

(define (unless-alternative exp)
  (if (not (null? (cdddr exp)))
	  (cadddr exp)
	  'false))

(define (unless->if exp)
  (make-if (unless-predicate exp)
		   (unless-alternative exp)
		   (unless-consequent exp)))


(driver-loop)
(define (factorial n)
  (unless (= n 1)
		  (* n (factorial (- n 1)))
		  1))

(factorial 5)
end