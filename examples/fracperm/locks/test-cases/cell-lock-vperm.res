Starting Reduce... 
Starting Omega...oc
Translating global variables to procedure parameters...
Eliminating variable aliasing...
Eliminating pointers...PASSED 

Checking procedure testCell$... 
dprint: cell-lock-vperm.ss:110: ctx:  List of Failesc Context: [FEC(0, 0, 1  )]

Successful States:
[
 Label: 
 State:x_24'::cell()<v_int_106_633>@M[Orig] * l_25'::LOCKB()<x_24>@M[Derv]&Anon_full_perm=FLOAT 1. & v_int_106_633=0 & l_25'!=null&{FLOW,(20,21)=__norm}[]
       es_var_measures: MayLoop

 ]

dprint: cell-lock-vperm.ss:112: ctx:  List of Failesc Context: [FEC(0, 0, 1  )]

Successful States:
[
 Label: 
 State:EXISTS(v_int_111_611': l_25'::LOCKB()<x_24>@M[Orig] * x_24'::cell(f_644)<v_int_111_611'>@M[Orig]&Anon_full_perm=FLOAT 1. & v_int_106_633=0 & l_25'!=null & f_635=Anon_full_perm & f_635>FLOAT 0. & f_635<=FLOAT 1. & v_int_111_611'=1+v_int_106_633 & f_644=f_635 & f_644=FLOAT 1.&{FLOW,(20,21)=__norm})[]
       es_var_measures: MayLoop

 ]

dprint: cell-lock-vperm.ss:115: ctx:  List of Failesc Context: [FEC(0, 0, 1  )]

Successful States:
[
 Label: 
 State:l_25'::LOCKB(f_648)<x_24>@M[Orig]&Anon_full_perm=FLOAT 1. & v_int_106_633=0 & f_635=Anon_full_perm & f_635>FLOAT 0. & f_635<=FLOAT 1. & v_int_111_650=1+v_int_106_633 & f_644=f_635 & f_644=FLOAT 1. & f_648=Anon_full_perm & v_649=v_int_111_650 & x_24'!=null & l_25'!=null&{FLOW,(20,21)=__norm}[]
       es_var_measures: MayLoop

 ]

dprint: cell-lock-vperm.ss:129: ctx:  List of Failesc Context: [FEC(0, 0, 1  )]

Successful States:
[
 Label: 
 State:x_24'::cell()<v_666>@M[Orig] * l_25'::lock()@M[Orig]&Anon_full_perm=FLOAT 1. & v_int_106_633=0 & f_635=Anon_full_perm & f_635>FLOAT 0. & f_635<=FLOAT 1. & v_int_111_650=1+v_int_106_633 & f_644=f_635 & f_644=FLOAT 1. & f_648=Anon_full_perm & v_649=v_int_111_650 & f_653=f_648 & 0<=v_660 & f_658=f_653 & v_659=v_660 & x_24'!=null & f_663=f_658 & 0<=v_666 & l_25'!=null&{FLOW,(20,21)=__norm}[]
       es_var_measures: MayLoop

 ]

Procedure testCell$ SUCCESS

Checking procedure testVar$... 
dprint: cell-lock-vperm.ss:95: ctx:  List of Failesc Context: [FEC(0, 0, 1  )]

Successful States:
[
 Label: 
 State:l_27'::lock()@M[Orig]&Anon_full_perm=FLOAT 1. & x_680=1+0 & f_679=Anon_full_perm & f_684=f_679 & 0<=v_int_76_693 & x_26'=1+v_int_76_693 & l_27'!=null&{FLOW,(20,21)=__norm}[]
       es_var_measures: MayLoop

 ]

Procedure testVar$ SUCCESS
Halting Reduce... 
Stop Omega... 28 invocations 
0 false contexts at: ()

Total verification time: 0.64 second(s)
	Time spent in main process: 0.27 second(s)
	Time spent in child processes: 0.37 second(s)
