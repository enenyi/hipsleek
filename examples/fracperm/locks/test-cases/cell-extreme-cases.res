Starting Reduce... 
Starting Omega...oc
Translating global variables to procedure parameters...
Eliminating variable aliasing...
Eliminating pointers...PASSED 

Checking procedure test$... 
dprint: cell-extreme-cases.ss:64: ctx:  List of Failesc Context: [FEC(0, 0, 1  )]

Successful States:
[
 Label: 
 State:EXISTS(v_int_55_631: l_33'::lock()@M[Orig] * x_32'::cell()<v_int_55_631>@M[Orig]&Anon_full_perm=FLOAT 1. & MayLoop & v_int_55_631=0&{FLOW,(20,21)=__norm})[]

 ]

procedure call:cell-extreme-cases.ss:65: 2: 
Verification Context:(Line:50,Col:10)
Proving precondition in method finalize$lock~cell for spec:
 EBase l_33'::LOCKA()<x_32>@M[Derv]&true&{FLOW,(20,21)=__norm}[]
         EAssume 1::
           l_33'::lock()@M[Orig]&true&{FLOW,(20,21)=__norm}[] has failed 


dprint:cell-extreme-cases.ss:66 empty/false context
Procedure test$ result FAIL-1

Checking procedure test2$... 
procedure call:cell-extreme-cases.ss:83: 2: 
Verification Context:(Line:73,Col:10)
Proving precondition in method release$lock~cell for spec:
 EBase exists (Expl)(Impl)[f_639; v_640](ex)x_30'::cell()<v_640>@M[Orig] * 
       l_31'::LOCKA(f_639)<x_30>@M[Derv]&0<=v_640 & f_639>FLOAT 0. & 
       f_639<=FLOAT 1.&{FLOW,(20,21)=__norm}[]
         EAssume 4::
           l_31'::LOCKA(f_639)<x_30>@M[Orig]&true&{FLOW,(20,21)=__norm}[] has failed 


Procedure test2$ result FAIL-1

Checking procedure test3$... 
Procedure test3$ SUCCESS

Checking procedure test4$... 
procedure call:cell-extreme-cases.ss:133: 2: 
Verification Context:(Line:122,Col:10)
Proving precondition in method release$lock~cell for spec:
 EBase exists (Expl)(Impl)[f_674; v_675](ex)x_26'::cell()<v_675>@M[Orig] * 
       l_27'::LOCKA(f_674)<x_26>@M[Derv]&0<=v_675 & f_674>FLOAT 0. & 
       f_674<=FLOAT 1.&{FLOW,(20,21)=__norm}[]
         EAssume 10::
           l_27'::LOCKA(f_674)<x_26>@M[Orig]&true&{FLOW,(20,21)=__norm}[] has failed 


dprint:cell-extreme-cases.ss:134 empty/false context
Procedure test4$ result FAIL-1
Halting Reduce... 
Stop Omega... 34 invocations 
0 false contexts at: ()

Total verification time: 0.51 second(s)
	Time spent in main process: 0.22 second(s)
	Time spent in child processes: 0.29 second(s)
