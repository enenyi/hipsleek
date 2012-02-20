
Processing file "bsort-1.ss"
Parsing bsort-1.ss ...
Parsing ../../prelude.ss ...
Starting Reduce... 
Starting Omega...oc
Translating global variables to procedure parameters...

Checking procedure bubble$node... 
!!! REL :  A(res)
!!! POST:  !(res)
!!! PRE :  true
!!! REL :  B(res)
!!! POST:  true
!!! PRE :  true
!!! NEW RELS:[ (res<=0) --> A(res),
 (res<=0) --> B(res),
 (tmp_42' & 1<=res & A(tmp_42')) --> A(res),
 (!(tmp_42') & res<=0 & A(tmp_42')) --> A(res),
 (A(tmp_42') & 1<=res & tmp_42') --> A(res),
 (A(tmp_42') & res<=0 & !(tmp_42')) --> A(res),
 (res<=0) --> B(res),
 (1<=res) --> B(res),
 (res<=0) --> B(res),
 (1<=res) --> B(res),
 (res<=0) --> B(res),
 (B(tmp_42') & 1<=res & tmp_42') --> B(res),
 (B(tmp_42') & res<=0 & !(tmp_42')) --> B(res)]
!!! NEW ASSUME:[]
!!! NEW RANK:[]
Procedure bubble$node SUCCESS

Termination checking result:

Stop Omega... 769 invocations 
0 false contexts at: ()

Total verification time: 2.97 second(s)
	Time spent in main process: 1.85 second(s)
	Time spent in child processes: 1.12 second(s)
