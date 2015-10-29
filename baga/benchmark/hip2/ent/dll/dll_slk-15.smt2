(set-logic QF_S)
(set-info :source |  Sleek solver
  http://loris-7.ddns.comp.nus.edu.sg/~project/hip/
|)

(set-info :smt-lib-version 2.0)
(set-info :category "crafted")
(set-info :status unsat)


(declare-sort node2 0)
(declare-fun val () (Field node2 Int))
(declare-fun prev () (Field node2 node2))
(declare-fun next () (Field node2 node2))

(define-fun dll ((?in node2) (?p node2) (?n Int))
Space (tospace
(or
(and 
(= ?in nil)
(= ?n 0)

)(exists ((?p_41 node2)(?self_42 node2)(?flted_12_40 Int))(and 
(= (+ ?flted_12_40 1) ?n)
(= ?p_41 ?p)
(= ?self_42 ?in)
(tobool (ssep 
(pto ?in (sref (ref val ?Anon_14) (ref prev ?p_41) (ref next ?q) ))
(dll ?q ?self_42 ?flted_12_40)
) )
)))))








































































































































(declare-fun Anon5_446 () Int)
(declare-fun q4_447 () node2)
(declare-fun Anon1 () Int)
(declare-fun next () node2)
(declare-fun n1 () Int)
(declare-fun n () Int)
(declare-fun p3 () node2)
(declare-fun p () node2)
(declare-fun m1 () Int)
(declare-fun q3 () node2)
(declare-fun tmp () node2)
(declare-fun q2 () node2)
(declare-fun x () node2)
(declare-fun yprm () node2)
(declare-fun y () node2)
(declare-fun self2 () node2)
(declare-fun xprm () node2)
(declare-fun p2 () node2)
(declare-fun q () node2)
(declare-fun flted1 () Int)
(declare-fun m () Int)
(declare-fun self3_444 () node2)
(declare-fun tmpprm () node2)
(declare-fun p4_443 () node2)
(declare-fun Anon4 () node2)
(declare-fun flted5_445 () Int)
(declare-fun flted4 () Int)


(assert 
(exists ((p4 node2)(self3 node2)(flted5 Int)(Anon5 Int)(q4 node2))(and 
;lexvar(= next q2)
(<= 0 n1)
(<= 0 m1)
(= flted4 (+ n1 m1))
(<= 0 flted1)
(<= 0 n)
(= n1 n)
(= p3 p)
(= m1 flted1)
(= q3 self2)
(= tmp q2)
(= xprm x)
(= yprm y)
(distinct xprm nil)
(not )(= self2 xprm)
(= p2 q)
(= (+ flted1 1) m)
(distinct tmpprm nil)
(= self3 tmpprm)
(= p4 Anon4)
(= (+ flted5 1) flted4)
(tobool (ssep 
(pto tmpprm (sref (ref val Anon5) (ref prev p4) (ref next q4) ))
(dll q4 self3 flted5)
(pto xprm (sref (ref val Anon1) (ref prev p2) (ref next tmpprm) ))
) )
))
)

(assert (not 
(and 
(tobool  
(pto tmpprm (sref (ref val val2prm) (ref prev prev2prm) (ref next next2prm) ))
 )
)
))

(check-sat)