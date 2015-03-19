(set-logic QF_S)
(set-info :source |
  James Brotherston, Carsten Fuhs, Nikos Gorogiannis, and Juan Navarro Pérez. 
  A decision procedure for satisfiability in separation logic with inductive 
  predicates. To appear at CSL-LICS, 2014. 
  https://github.com/ngorogiannis/cyclist/releases/tag/CSL-LICS14
|)
(set-info :smt-lib-version 2.0)
(set-info :category "crafted")
(set-info :status sat)
(set-info :version 2014-05-31)




;generic sort 

(declare-sort GTyp 0)

;generic fields 
(declare-fun f0 () (Field GTyp GTyp))
(declare-fun f1 () (Field GTyp GTyp))

;predicates 

(define-fun P ((?x1 GTyp) (?x2 GTyp) (?x3 GTyp) (?x4 GTyp)) Space 

	(ssep (one ?x1)
		(one ?x2)
		(one ?x3)
		(one ?x4)
		(Q ?x1 ?x2 ?x3 ?x4)
	)
)


(define-fun Q ((?y1 GTyp) (?y2 GTyp) (?y3 GTyp) (?y4 GTyp)) Space 
(tospace (or 
(tobool 
	(ssep (zero ?y1)
		(zero ?y2)
		(zero ?y3)
		(zero ?y4)
	)
)

	(exists ((?x1 GTyp) (?x2 GTyp) (?x3 GTyp) (?x4 GTyp))
		
		 (tobool 
	(ssep (succ4rec ?x1 ?x2 ?x3 ?x4 ?y1 ?y2 ?y3 ?y4)
		(Q ?x1 ?x2 ?x3 ?x4)
	)

		)
	)
))
)


(define-fun succ4rec ((?x1 GTyp) (?x2 GTyp) (?x3 GTyp) (?x4 GTyp) (?y1 GTyp) (?y2 GTyp) (?y3 GTyp) (?y4 GTyp)) Space 
(tospace (or 

	(and (= ?x2 ?y2)
		(= ?x3 ?y3)
		(= ?x4 ?y4)
		 (tobool 
	(ssep (zero ?x1)
		(one ?y1)
	)

		)
	)

(tobool 
	(ssep (succ3rec ?x2 ?x3 ?x4 ?y2 ?y3 ?y4)
		(one ?x1)
		(zero ?y1)
	)
)))
)


(define-fun succ3rec ((?x1 GTyp) (?x2 GTyp) (?x3 GTyp) (?y1 GTyp) (?y2 GTyp) (?y3 GTyp)) Space 
(tospace (or 

	(and (= ?x2 ?y2)
		(= ?x3 ?y3)
		 (tobool 
	(ssep (zero ?x1)
		(one ?y1)
	)

		)
	)

(tobool 
	(ssep (succ2rec ?x2 ?x3 ?y2 ?y3)
		(one ?x1)
		(zero ?y1)
	)
)))
)


(define-fun succ2rec ((?x1 GTyp) (?x2 GTyp) (?y1 GTyp) (?y2 GTyp)) Space 
(tospace (or 

	(and (= ?x2 ?y2)
		 (tobool 
	(ssep (zero ?x1)
		(one ?y1)
	)

		)
	)

(tobool 
	(ssep (succ1rec ?x2 ?y2)
		(one ?x1)
		(zero ?y1)
	)
)))
)


(define-fun succ1rec ((?x1 GTyp) (?y1 GTyp)) Space 

	(ssep (zero ?x1)
		(one ?y1)
	)
)


(define-fun zero ((?x GTyp)) Space 

	(tospace (= nil ?x))
)


(define-fun one ((?x GTyp)) Space 

	(tospace (distinct nil ?x))
)


;vars 

;problem 
(declare-fun x0 () GTyp)
(declare-fun x1 () GTyp)
(declare-fun x2 () GTyp)
(declare-fun x3 () GTyp)

(assert (tobool (P  x0 x1 x2 x3)))

(check-sat)
