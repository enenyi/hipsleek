(set-logic QF_S)
(set-info :source |  Sleek solver
  http://loris-7.ddns.comp.nus.edu.sg/~project/hip/
|)

(set-info :smt-lib-version 2.0)
(set-info :category "crafted")
(set-info :status unsat)


(declare-sort node 0)
(declare-fun left () (Field node node))
(declare-fun right () (Field node node))
(declare-fun next () (Field node node))

(define-fun tree ((?in node) (?n Int))
Space (tospace
(or
(exists ((?flted_15_28 node)(?flted_15_29 node))(and 
(= ?flted_15_29 nil)
(= ?flted_15_28 nil)
(= ?n 1)
(tobool  
(pto ?in (sref (ref left ?flted_15_29) (ref right ?flted_15_28) (ref next ?Anon_14) ))
 )
))(exists ((?flted_16_30 node))(and 
(= ?flted_16_30 nil)
(= ?n (+ (+ 1 ?n1) ?n2))
(tobool (ssep 
(pto ?in (sref (ref left ?l) (ref right ?r) (ref next ?flted_16_30) ))
(tree ?l ?n1)
(tree ?r ?n2)
) )
)))))

(define-fun tll ((?in node) (?ll node) (?lr node) (?n Int))
Space (tospace
(or
(exists ((?lr_37 node)(?flted_10_34 node)(?flted_10_35 node))(and 
(= ?flted_10_35 nil)
(= ?flted_10_34 nil)
(= ?in ?ll)
(= ?n 1)
(= ?lr_37 ?lr)
(tobool  
(pto ?in (sref (ref left ?flted_10_35) (ref right ?flted_10_34) (ref next ?lr_37) ))
 )
))(exists ((?ll_38 node)(?z_39 node)(?lr_40 node)(?flted_11_36 node))(and 
(= ?flted_11_36 nil)
(= ?n (+ (+ 1 ?n1) ?n2))
(= ?ll_38 ?ll)
(= ?z_39 ?z)
(= ?lr_40 ?lr)
(tobool (ssep 
(pto ?in (sref (ref left ?l) (ref right ?r) (ref next ?flted_11_36) ))
(tll ?l ?ll_38 ?z ?n1)
(tll ?r ?z_39 ?lr_40 ?n2)
) )
)))))























(declare-fun l1 () node)
(declare-fun r2 () node)
(declare-fun rprm () node)
(declare-fun r () node)
(declare-fun tprm () node)
(declare-fun t () node)
(declare-fun xprm () node)
(declare-fun x () node)
(declare-fun lr3 () node)
(declare-fun ggg () node)
(declare-fun z2 () node)
(declare-fun z3 () node)
(declare-fun ll1 () node)
(declare-fun t3 () node)
(declare-fun n () Int)
(declare-fun n4 () Int)
(declare-fun n3 () Int)
(declare-fun flted5 () node)


(assert 
(and 
;lexvar(distinct r2 nil)
(not )(= t3 t)
(= rprm r)
(= tprm t)
(= xprm x)
(= lr3 ggg)
(= z2 z3)
(= ll1 t3)
(= n (+ (+ 1 n3) n4))
(= flted5 nil)
(tobool (ssep 
(tll l1 ll1 z3 n3)
(pto xprm (sref (ref left l1) (ref right r2) (ref next flted5) ))
(tll r2 z2 lr3 n4)
) )
)
)

(assert (not 
(and 
(tobool  
(pto xprm (sref (ref left left1prm) (ref right right1prm) (ref next next1prm) ))
 )
)
))

(check-sat)