Starting Reduce... 
Starting Omega...oc
Translating global variables to procedure parameters...
Eliminating variable aliasing...
Eliminating pointers...PASSED 

Checking procedure main$... 
dprint: cell.ss:57: ctx:  List of Failesc Context: [FEC(0, 0, 1  )]

Successful States:
[
 Label: 
 State:x_29'::cell()<v_int_53_638>@M[Orig] * l_30'::LOCKA()<x_29>@M[Derv]&Anon_full_perm=FLOAT 1. & v_int_53_638=0 & l_30'!=null&{FLOW,(20,21)=__norm}[]
       es_var_measures: MayLoop

 ]

Procedure main$ SUCCESS

Checking procedure main1$... 
procedure call:cell.ss:80: 2: 
Verification Context:(Line:70,Col:10)
Proving precondition in method release$lock~cell~cell for spec:
 EBase exists (Expl)(Impl)[f_683; v1_684; 
       v2_685](ex)x_26'::cell()<v1_684>@M[Orig] * 
       y_27'::cell()<v2_685>@M[Orig] * 
       l_28'::LOCKB(f_683)<x_26,y_27>@M[Derv]&0<=(v2_685+v1_684) & 
       f_683>FLOAT 0. & f_683<=FLOAT 1.&{FLOW,(20,21)=__norm}[]
         EAssume 4::
           l_28'::LOCKB(f_683)<x_26,y_27>@M[Orig]&true&
           {FLOW,(20,21)=__norm}[] has failed 


procedure call:cell.ss:83: 2: 
Verification Context:(Line:70,Col:10)
Proving precondition in method acquire$lock~cell~cell for spec:
 EBase exists (Expl)(Impl)[f_690](ex)l_28'::LOCKB(f_690)<x_26,y_27>@M[Derv]&
       f_690>FLOAT 0. & f_690<=FLOAT 1.&{FLOW,(1,23)=__flow}[]
         EAssume 4::
           EXISTS(v1_691,v2_692: x_26'::cell()<v1_691>@M[Orig] * 
           y_27'::cell()<v2_692>@M[Orig] * 
           l_28'::LOCKB(f_690)<x_26,y_27>@M[Derv]&0<=(v2_692+v1_691)&
           {FLOW,(20,21)=__norm})[] has failed 


procedure call:cell.ss:84: 2: 
Verification Context:(Line:70,Col:10)
Proving precondition in method finalize$lock~cell~cell for spec:
 EBase l_28'::LOCKB()<x_26,y_27>@M[Derv]&true&{FLOW,(20,21)=__norm}[]
         EAssume 4::
           l_28'::lock()@M[Orig]&true&{FLOW,(20,21)=__norm}[] has failed 


Procedure main1$ result FAIL-1
Halting Reduce... 
Stop Omega... 30 invocations 
0 false contexts at: ()

Total verification time: 0.65 second(s)
	Time spent in main process: 0.28 second(s)
	Time spent in child processes: 0.37 second(s)
