Starting Reduce... 
Starting Omega...oc
infer_heap_nodes
infer var: [y]
new infer var: [inf_ann_28,inf_a_29,inf_b_30,y]
Entail  (1): Valid. 
<1>true & a=inf_a_29 & b=inf_b_30 & inf_ann_28<=0 & {FLOW,(17,18)=__norm}
inferred heap: [y::node<inf_a_29,inf_b_30>@inf_ann_28[Orig]]
inferred pure: [inf_ann_28<=0]

infer_heap_nodes
infer var: [y]
new infer var: [inf_ann_34,inf_n_35,y]
Entail  (2): Valid. 
<1>true & n=inf_n_35 & inf_ann_34<=0 & {FLOW,(17,18)=__norm}
inferred heap: [y::ll<inf_n_35>@inf_ann_34[Orig][LHSCase]]
inferred pure: [inf_ann_34<=0]

infer_heap_nodes
infer var: [y]
new infer var: [inf_ann_42,inf_a_43,inf_b_44,y]
infer_heap_nodes
infer var: [inf_ann_42,inf_a_43,inf_b_44,y]
new infer var: [inf_ann_45,inf_c_46,inf_d_47,inf_ann_42,inf_a_43,inf_b_44,y]
Entail  (3): Valid. 
<1>true & a=inf_a_43 & b=inf_b_44 & c=inf_c_46 & d=inf_d_47 & inf_ann_45<=0 & inf_ann_42<=0 & {FLOW,(17,18)=__norm}
inferred heap: [b::node<inf_c_46,inf_d_47>@inf_ann_45[Orig]; 
               y::node<inf_a_43,inf_b_44>@inf_ann_42[Orig]]
inferred pure: [inf_ann_45<=0; inf_ann_42<=0; inf_b_44=b]

infer_heap_nodes
infer var: [y]
new infer var: [inf_ann_53,inf_a_54,inf_b_55,y]
infer_heap_nodes
infer var: [inf_ann_53,inf_a_54,inf_b_55,y]
new infer var: [inf_ann_56,inf_m_57,inf_ann_53,inf_a_54,inf_b_55,y]
Entail  (4): Valid. 
<1>true & a=inf_a_54 & b=inf_b_55 & m=inf_m_57 & inf_ann_56<=0 & inf_ann_53<=0 & {FLOW,(17,18)=__norm}
inferred heap: [b::ll<inf_m_57>@inf_ann_56[Orig][LHSCase]; 
               y::node<inf_a_54,inf_b_55>@inf_ann_53[Orig]]
inferred pure: [inf_ann_56<=0; inf_ann_53<=0; inf_b_55=b]

infer_heap_nodes
infer var: [x]
new infer var: [inf_ann_61,inf_n_62,x]
Entail  (5): Valid. 
<1>true & x=y & n=inf_n_62 & inf_ann_61<=0 & {FLOW,(17,18)=__norm}
inferred heap: [y::ll<inf_n_62>@inf_ann_61[Orig][LHSCase]]
inferred pure: [inf_ann_61<=0]

infer_heap_nodes
infer var: [x]
new infer var: [inf_ann_70,inf_n_71,x]
Entail  (6): Valid. 
<1>true & n=0 & x=y & inf_ann_70<=0 & inf_n_71=0 & {FLOW,(17,18)=__norm}
inferred heap: [y::ll<inf_n_71>@inf_ann_70[Orig][LHSCase]]
inferred pure: [inf_ann_70<=0; inf_n_71=0]

infer_heap_nodes
infer var: [x]
new infer var: [inf_ann_80,inf_n_81,x]
Entail  (7): Valid. 
<1>true & x=y & n=inf_n_81 & inf_ann_80<=0 & {FLOW,(17,18)=__norm}
inferred heap: [x::ll<inf_n_81>@inf_ann_80[Orig][LHSCase]]
inferred pure: [inf_ann_80<=0]

Entail  (8): Valid. 
<1>true & a=ia & b=ib & {FLOW,(17,18)=__norm}

infer_heap_nodes
infer var: [y]
new infer var: [inf_ann_99,inf_a_100,inf_flted_43_101,y]
Entail  (9): Valid. 
<1>true & inf_ann_99<=0 & inf_flted_43_101=null & 1<=inf_a_100 & {FLOW,(17,18)=__norm}
inferred heap: [y::node<inf_a_100,inf_flted_43_101>@inf_ann_99[Orig]]
inferred pure: [inf_ann_99<=0; inf_flted_43_101=null & 1<=inf_a_100]

Entail  (10): Valid. 
<1>EXISTS(flted_47_127: true & flted_47_127=null & 1<=aa & {FLOW,(17,18)=__norm})
inferred pure: [1<=aa]

Entail  (11): Valid. 
<1>true & n=m & {FLOW,(17,18)=__norm}

Entail  (12): Valid. 
<1>false & false & {FLOW,(17,18)=__norm}
inferred pure: [x!=null]

Entail  (13): Valid. 
<1>false & false & {FLOW,(17,18)=__norm}
inferred pure: [y!=null]

Stop Omega... 215 invocations 
