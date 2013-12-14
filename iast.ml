(*
  Created 19-Feb-2006

  Input AST
*)

open Globals
open Gen.Basic
(* open Exc.ETABLE_NFLOW *)
open Exc.GTable
open Perm

module F = Iformula
module P = Ipure
module Err = Error
module CP = Cpure
module LO = Label_only.LOne

type typed_ident = (typ * ident)


type prog_decl = { 
    prog_include_decls : ident list;
    mutable prog_data_decls : data_decl list;
    prog_global_var_decls : exp_var_decl list;
    prog_logical_var_decls : exp_var_decl list;
    prog_enum_decls : enum_decl list;
    mutable prog_view_decls : view_decl list;
    mutable prog_func_decls : func_decl list; (* TODO: Need to handle *)
    mutable prog_rel_decls : rel_decl list; 
    mutable prog_hp_decls : hp_decl list; 
    mutable prog_rel_ids : (typ * ident) list; 
    mutable prog_hp_ids : (typ * ident) list; 
    mutable prog_axiom_decls : axiom_decl list; (* [4/10/2011] An hoa : axioms *)
    mutable prog_hopred_decls : hopred_decl list;
    (* An Hoa: relational declaration *)
    prog_proc_decls : proc_decl list;
    prog_barrier_decls : barrier_decl list;
    mutable prog_coercion_decls : coercion_decl_list list
}

and data_field_ann =
  | VAL
  | REC
  | F_NO_ANN

and data_decl = { 
    data_name : ident;
    data_fields : (typed_ident * loc * bool * data_field_ann) list; 
    (* An Hoa [20/08/2011] : add a bool to indicate whether a field is an inline field or not. TODO design revision on how to make this more extensible; for instance: use a record instead of a bool to capture additional information on the field?  *)
    data_parent_name : ident;
    data_invs : F.formula list;
    data_pos : loc;
    data_is_template: bool;
    data_methods : proc_decl list }

(*
  and global_var_decl = { global_var_decl_type : typ;
  global_var_decl_decls : (ident * exp option * loc) list;
  global_var_decl_pos : loc }
*)

and view_kind =
  | View_PRIM
  | View_NORM
  | View_EXTN

and view_decl = 
    { view_name : ident; 
    mutable view_data_name : ident;
    (* view_frac_var : iperm; (\*LDK: frac perm ??? think about it later*\) *)
    mutable view_vars : ident list;
    mutable view_imm_map: (P.ann * int) list;
    view_pos : loc;
    view_labels : LO.t list * bool;
    view_modes : mode list;
    mutable view_typed_vars : (typ * ident) list;
    view_kind : view_kind;
    view_prop_extns:  ident list;
    view_is_prim : bool;
    view_invariant : P.formula;
    view_mem : F.mem_formula option; 
    (* Represents the Memory Permission Set. Option None will not use Memory Permission Set*)
    view_formula : Iformula.struc_formula;
    view_inv_lock : F.formula option;
    mutable view_pt_by_self : ident list; (* list of views pointed by self *)
    (* view_targets : ident list;  *)(* list of views pointed within declaration *)
    try_case_inference: bool;
    view_materialized_vars: ident list; }

and func_decl = { func_name : ident; 
func_typed_vars : (typ * ident) list;}

(* An Hoa: relational declaration, nearly identical to view_decl except for the view_data_name *)
and rel_decl = { rel_name : ident; 
(* rel_vars : ident list; *)
(* rel_labels : branch_label list; *)
rel_typed_vars : (typ * ident) list;
(* rel_invariant : (P.formula * (branch_label * P.formula) list); *)
rel_formula : P.formula (* Iformula.struc_formula *) ; 
(* try_case_inference: bool *) }

(* [4/10/2011] An Hoa: axiom for pure constraints *)
and axiom_decl = {
    axiom_id : int;
    axiom_hypothesis : P.formula ;
    axiom_conclusion : P.formula ;
}

and hp_decl = { hp_name : ident; 
(* rel_vars : ident list; *)
(* rel_labels : branch_label list; *)
hp_typed_inst_vars : (typ * ident * hp_arg_kind) list;
mutable hp_root_pos: int;
hp_is_pre: bool;
hp_formula : Iformula.formula ;
(* try_case_inference: bool *)}

and hopred_decl = { hopred_name : ident;
hopred_mode : ho_branch_label;
hopred_mode_headers : ident list;
hopred_typed_vars: (typ * ident) list;
mutable hopred_typed_args : (typ * ident) list;
hopred_fct_args : ident list;
hopred_shape    : Iformula.struc_formula list;
hopred_invariant :P.formula }

and barrier_decl = {
    barrier_thc : int;
    barrier_name : ident;
    barrier_shared_vars : (typ*ident) list;
    barrier_tr_list : (int*int* Iformula.struc_formula list) list ;
}


and enum_decl = { enum_name : ident;
enum_fields : (ident * int option) list } 
    (* a field of an enum may optionally be initialized by an integer *)

and param_modifier =
  | NoMod
  | RefMod
  | CopyMod (* WN : this signify pass-by-copy semantics *)
    (* TODO : need to be captured in both parser + cast.ml and hip verifier *)

and jump_label_type =
  | NoJumpLabel 
  | JumpLabel of ident
        
and rise_type = 
  | Const_flow of constant_flow
  | Var_flow of ident

and param = { param_type : typ;
param_name : ident;
param_mod : param_modifier;
param_loc : loc }

(*
  and multi_spec = spec list

  and spec = 
  | SCase of scase_spec
  | SRequires of srequires_spec
  | SEnsure of sensures_spec
  
  and scase_spec = 
  {
  scase_branches : (Ipure.formula * multi_spec ) list ;
  scase_pos : loc 
  }
  
  and srequires_spec = 
  {		
  srequires_explicit_inst : (ident * primed) list;
  srequires_implicit_inst : (ident * primed) list;
  srequires_base : Iformula.formula;
  srequires_continuation : multi_spec;
  srequires_pos : loc
  }	
  
  and sensures_spec = 
  {
  sensures_base : Iformula.formula;
  sensures_pos : loc
  }
*)

and proc_decl = { proc_name : ident;
mutable proc_mingled_name : ident;
mutable proc_data_decl : data_decl option; (* the class containing the method *)
mutable proc_hp_decls : hp_decl list; (* add hp decl list for proc *)
proc_flags: (ident*ident*(flags option)) list;
proc_source : ident;
proc_constructor : bool;
proc_args : param list;
proc_return : typ;
(*   mutable proc_important_vars : CP.spec_var list;*)
proc_static_specs : Iformula.struc_formula;
proc_dynamic_specs : Iformula.struc_formula;
proc_exceptions : ident list;
proc_body : exp option;
proc_is_main : bool;
proc_file : string;
proc_loc : loc;
proc_test_comps: test_comps option}

and coercion_decl = { coercion_type : coercion_type;
coercion_exact : bool;
coercion_name : ident;
coercion_infer_vars : ident list;
coercion_head : F.formula;
coercion_body : F.formula;
coercion_proof : exp }

and coercion_decl_list = {
    coercion_list_elems : coercion_decl list;
    coercion_list_kind:   lemma_kind;
}

and coercion_type = 
  | Left
  | Equiv
  | Right



(********vp:for parse compare file************)
and cp_file_comps = 
  | Hpdecl of hp_decl
  | ProcERes of (ident * test_comps)
        
and test_comps = {
    expected_ass: (((ident list) * (ident list) * (ass list)) option);
    expected_hpdefs: (((ident list) * (ident list) * (ass list)) option) }
    
and expected_comp = 
  | ExpectedAss of ((ident list) * (ident list) *(ass list)) 
  | ExpectedHpDef of ((ident list) * (ident list) *(ass list))

and ass = {
    ass_lhs: F.formula;
    ass_guard: F.formula option;
    ass_rhs: F.formula }

(********end parse compare file************)

and uni_op = 
  | OpUMinus
  | OpPreInc
  | OpPreDec
  | OpPostInc
  | OpPostDec
  | OpNot
          (*For pointers: *v and &v *)
  | OpVal (*value-of*)
  | OpAddr (*address-off*)

and bin_op = 
  | OpPlus
  | OpMinus
  | OpMult
  | OpDiv
  | OpMod
  | OpEq
  | OpNeq
  | OpLt
  | OpLte
  | OpGt
  | OpGte
  | OpLogicalAnd
  | OpLogicalOr
  | OpIsNull
  | OpIsNotNull

and assign_op =
  | OpAssign
  | OpPlusAssign
  | OpMinusAssign
  | OpMultAssign
  | OpDivAssign
  | OpModAssign



(* An Hoa : v[i] where v is an identifier and i is an expression *)
and exp_arrayat = { exp_arrayat_array_base : exp; (* An Hoa : modified from a single ident to exp to support expressions like x.A[i] for a data structure that has an array as a field *)
exp_arrayat_index : exp list; (* An Hoa : allow multi-dimensional arrays *)
exp_arrayat_pos : loc; }

(* (\* An Hoa : array memory allocation expression *\) *)
(* and exp_aalloc = { exp_aalloc_etype_name : ident;		(\* Name of the base element *\) *)
(* 					exp_aalloc_dimensions : exp list;	(\* List of size for each dimensions *\) *)
(* 					exp_aalloc_pos : loc; } *)

(* An Hoa : array memory allocation expression *)
and exp_aalloc = { exp_aalloc_etype_name : ident; (* Name of the base element *)
exp_aalloc_dimensions : exp list; (* List of size for each dimensions *)
exp_aalloc_pos : loc; }

and exp_assert = { exp_assert_asserted_formula : (F.struc_formula*bool) option;
exp_assert_assumed_formula : F.formula option;
exp_assert_path_id : formula_label;
exp_assert_type : assert_type;
exp_assert_pos : loc }

and exp_assign = { exp_assign_op : assign_op;
exp_assign_lhs : exp;
exp_assign_rhs : exp;
exp_assign_path_id : control_path_id;
exp_assign_pos : loc }

and exp_binary = { exp_binary_op : bin_op;
exp_binary_oper1 : exp;
exp_binary_oper2 : exp;
exp_binary_path_id : control_path_id;
exp_binary_pos : loc }

and exp_bind = { exp_bind_bound_var : ident;
exp_bind_fields : ident list;
exp_bind_body : exp;
exp_bind_path_id : control_path_id;
exp_bind_pos : loc }
    
and exp_break = { exp_break_jump_label : jump_label_type;
exp_break_path_id : control_path_id;
exp_break_pos : loc }	

and exp_block = { exp_block_body : exp;
exp_block_jump_label : jump_label_type;
exp_block_local_vars: (ident*typ*loc) list;
exp_block_pos : loc }

and exp_bool_lit = { exp_bool_lit_val : bool;
exp_bool_lit_pos : loc }
    
and exp_barrier = {exp_barrier_recv : ident; exp_barrier_pos : loc}

and exp_call_nrecv = { exp_call_nrecv_method : ident;
exp_call_nrecv_lock : ident option;
exp_call_nrecv_arguments : exp list;
exp_call_nrecv_path_id : control_path_id;
exp_call_nrecv_pos : loc }

and exp_call_recv = { exp_call_recv_receiver : exp;
exp_call_recv_method : ident;
exp_call_recv_arguments : exp list;
exp_call_recv_path_id : control_path_id;
exp_call_recv_pos : loc }

and exp_catch = { exp_catch_var : ident option ;
exp_catch_flow_type : constant_flow;
exp_catch_alt_var_type : typ option;
exp_catch_flow_var : ident option;
exp_catch_body : exp;
exp_catch_pos : loc }

and exp_cast = { exp_cast_target_type : typ;
exp_cast_body : exp;
exp_cast_pos : loc }

and exp_cond = { exp_cond_condition : exp;
exp_cond_then_arm : exp;
exp_cond_else_arm : exp;
exp_cond_path_id : control_path_id;
exp_cond_pos : loc }

and exp_const_decl = { exp_const_decl_type : typ;
exp_const_decl_decls : (ident * exp * loc) list;
exp_const_decl_pos : loc }

and exp_continue = { exp_continue_jump_label : jump_label_type;
exp_continue_path_id : control_path_id;
exp_continue_pos : loc }
    
and exp_debug = { exp_debug_flag : bool;
exp_debug_pos : loc }

and exp_finally = { exp_finally_body : exp;
exp_finally_pos : loc }

and exp_float_lit = { exp_float_lit_val : float;
exp_float_lit_pos : loc }

and exp_int_lit = { exp_int_lit_val : int;
exp_int_lit_pos : loc }

and exp_java = { exp_java_code : string;
exp_java_pos : loc }

and exp_member = { exp_member_base : exp;
exp_member_fields : ident list;
exp_member_path_id : control_path_id;
exp_member_pos : loc }

and exp_new = { exp_new_class_name : ident;
exp_new_arguments : exp list;
exp_new_pos : loc }

and exp_raise = { exp_raise_type : rise_type;
exp_raise_val : exp option;
exp_raise_from_final :bool; (*if so the result can have any type...*)
exp_raise_use_type : bool; 
exp_raise_path_id : control_path_id;
exp_raise_pos : loc }
    
and exp_return = { exp_return_val : exp option;
exp_return_path_id : control_path_id;
exp_return_pos : loc }

and exp_seq = { exp_seq_exp1 : exp;
exp_seq_exp2 : exp;
exp_seq_pos : loc }

and exp_this = { exp_this_pos : loc }

and exp_try = { exp_try_block : exp;
exp_catch_clauses : exp list;
exp_finally_clause : exp list;
exp_try_path_id : control_path_id;
exp_try_pos : loc}

(*and exp_throw = { exp_throw_type : ident;
  exp_throw_pos : loc }
*)
and exp_unary = { exp_unary_op : uni_op;
exp_unary_exp : exp;
exp_unary_path_id : control_path_id;
exp_unary_pos : loc }

and exp_var = { exp_var_name : ident;
exp_var_pos : loc }

and exp_var_decl = { exp_var_decl_type : typ;
exp_var_decl_decls : (ident * exp option * loc) list;
exp_var_decl_pos : loc }

and exp_while = { exp_while_condition : exp;
exp_while_body : exp;
(*before pointer translation*)
(*need a list of address-off vars that may belong to
  specs of while loop. Updated in Pointers.trans_exp_addrr.
  Used in Astsimpl.trans_loop_proc*)
exp_while_addr_vars : ident list;  
exp_while_specs : Iformula.struc_formula (*multi_spec*);
exp_while_jump_label : jump_label_type;
exp_while_path_id : control_path_id;
exp_while_f_name: ident;
exp_while_wrappings: (exp*ident) option;
(*used temporary to store the break wrappers, these wrappers are catch clauses which will
  wrap the method so that it catches and converts the break flows with target jump_label_type*)
exp_while_pos : loc }

and exp_dprint = { exp_dprint_string : string;
exp_dprint_pos : loc }

and exp_unfold = { exp_unfold_var : (string * primed);
exp_unfold_pos : loc } 

and exp =
  | ArrayAt of exp_arrayat (* An Hoa *)
  | ArrayAlloc of exp_aalloc (* An Hoa *)
  | Assert of exp_assert
  | Assign of exp_assign
  | Binary of exp_binary
  | Bind of exp_bind
  | Block of exp_block
  | BoolLit of exp_bool_lit
  | Break of exp_break
  | Barrier of exp_barrier
  | CallRecv of exp_call_recv
  | CallNRecv of exp_call_nrecv
  | Cast of exp_cast
  | Cond of exp_cond
  | ConstDecl of exp_const_decl
  | Continue of exp_continue
  | Catch of exp_catch
  | Debug of exp_debug
  | Dprint of exp_dprint
  | Empty of loc
  | FloatLit of exp_float_lit
  | Finally of exp_finally
  | IntLit of exp_int_lit
  | Java of exp_java
  | Label of ((control_path_id * path_label) * exp)
  | Member of exp_member
  | New of exp_new
  | Null of loc
  | Raise of exp_raise 
  | Return of exp_return
  | Seq of exp_seq
  | This of exp_this
  | Time of (bool*string*loc)
  | Try of exp_try
  | Unary of exp_unary
  | Unfold of exp_unfold
  | Var of exp_var
  | VarDecl of exp_var_decl
  | While of exp_while

(* utility functions *)

let void_type = Void

let int_type = Int

let infint_type = INFInt

let ann_type = AnnT

let float_type = Float

let bool_type = Bool

let bag_type = BagT Int

(* utility functions *)

let print_struc_formula = ref (fun (x:F.struc_formula) -> "Uninitialised printer")
let print_h_formula = ref (fun (x:F.h_formula) -> "Uninitialised printer")
let print_view_decl = ref (fun (x:view_decl) -> "Uninitialised printer")
let print_data_decl = ref (fun (x:data_decl) -> "Uninitialised printer")
let print_exp = ref (fun (x:exp) -> "Uninitialised printer")
let print_param_list = ref (fun (x: param list) -> "Uninitialised printer")
let print_hp_decl = ref (fun (x: hp_decl) -> "Uninitialised printer")


let find_empty_static_specs iprog = 
  let er = List.filter (fun c-> F.isEConstTrue c.proc_static_specs) iprog.prog_proc_decls in
  let s = "Empty Specs: " ^ (pr_list pr_id (List.map (fun x -> x.proc_name) er)) in
  report_warning no_pos s
 
(* apply substitution to an id *)
let apply_subs_to_id (subs:(ident *ident) list) (id:ident) : ident
 = try       
     List.assoc id subs
   with 
     Not_found -> id

(* apply substitution to exp_var *)
let apply_subs_to_exp_var (subs:(ident *ident) list) (ev:exp_var) : exp_var
 = { ev with  exp_var_name = apply_subs_to_id subs ev.exp_var_name; }

(* apply substitution to list of id *)
let apply_subs_to_list_id (subs:(ident *ident) list) (lst:ident list) : ident list
 = List.map (apply_subs_to_id subs) lst


(* check if id is in domain of subs *)
let member_domain (id:ident) (subs:(ident * ident) list)  : bool
 = List.exists (fun (x,_) -> (String.compare id x)==0) subs


(* intersection of two lists of ids *)
let intersect (lst1:'a list) (lst2:'a list) : 'a list
  = List.filter (fun x -> List.mem x lst2) lst1


(* make new renaming substitution that avoids name clash *)
let new_renaming (lst:ident list) : (ident * ident) list
  = List.map (fun x -> (x,x^"_tmp" (* fresh name *))) lst

(* transform each proc by a map function *)
let map_proc (prog:prog_decl)
  (f_p : proc_decl -> proc_decl) : prog_decl =
  { prog with
      prog_proc_decls = List.map (f_p) prog.prog_proc_decls;
  }

(* process each proc into some data which are then combined,
   e.g. verify each method and collect the failure points
*)
let fold_proc (prog:prog_decl)
  (f_p : proc_decl -> 'b) (f_comb: 'b -> 'b -> 'b) (zero:'b) : 'b =
  List.fold_left (fun x p -> f_comb (f_p p) x) 
		zero prog.prog_proc_decls

(* iterate each proc to check for some property *)
let iter_proc (prog:prog_decl) (f_p : proc_decl -> unit) : unit =
  fold_proc prog (f_p) (fun _ _ -> ()) ()


let trans_exp (e:exp) (init_arg:'b) (f:'b->exp->(exp* 'a) option)  (f_args:'b->exp->'b) (comb_f: exp -> 'a list -> 'a) : (exp * 'a) =
  let rec helper (in_arg:'b) (e:exp) :(exp* 'a) =	
    match (f in_arg e) with
	  | Some e1 -> e1
	  | None  ->
		let n_arg = f_args in_arg e in 
                let comb_f = comb_f e in
                let zero = comb_f [] in  
		match e with	
                  | Assert _ 
                  | BoolLit _ 
                  | Break _
                  | Continue _ 
                  | Debug _ 
                  | Dprint _ 
                  | Empty _ 
                  | FloatLit _ 
                  | IntLit _
                  | Java _ 
                  | Null _ 
                  | This _ 
                  | Time _ 
                  | Unfold _ 
                  | Var _ -> (e,zero)
	          | ArrayAt b -> (* An Hoa *)
		        let el,rl = List.split (List.map (helper n_arg) b.exp_arrayat_index) in
		        (ArrayAt {b with exp_arrayat_index = el},comb_f rl)
                  | Assign b ->
                        let e1,r1 = helper n_arg b.exp_assign_lhs  in
                        let e2,r2 = helper n_arg b.exp_assign_rhs  in
                        (Assign { b with exp_assign_lhs = e1; exp_assign_rhs = e2;},(comb_f [r1;r2]))
                  | Binary b -> 
                        let e1,r1 = helper n_arg b.exp_binary_oper1  in
                        let e2,r2 = helper n_arg b.exp_binary_oper2  in
                        (Binary {b with exp_binary_oper1 = e1; exp_binary_oper2 = e2;},(comb_f [r1;r2]))
                  | Bind b -> 
                        let e1,r1 = helper n_arg b.exp_bind_body  in
                        (Bind {b with exp_bind_body = e1; },r1)
		  | Barrier _ -> (e,zero)
			(*let e,r = helper n_arg b.exp_barrier_recv  in     
                          (Barrier {b with exp_barrier_recv = e},r)*)
                  | Block b -> 
                        let e1,r1 = helper n_arg b.exp_block_body  in     
                        (Block {b with exp_block_body = e1;},r1)
                  | CallRecv b -> 
                        let e1,r1 = helper n_arg b.exp_call_recv_receiver  in     
                        let ler = List.map (helper n_arg) b.exp_call_recv_arguments in    
                        let e2l,r2l = List.split ler in
                        let r = comb_f (r1::r2l) in
                        (CallRecv {b with exp_call_recv_receiver = e1;exp_call_recv_arguments = e2l;},r)
                  | CallNRecv b -> 
                        let ler = List.map (helper n_arg) b.exp_call_nrecv_arguments in    
                        let e2l,r2l = List.split ler in
                        let r = comb_f r2l in
                        (CallNRecv {b with exp_call_nrecv_arguments = e2l;},r)
                  | Cast b -> 
                        let e1,r1 = helper n_arg b.exp_cast_body  in  
                        (Cast {b with exp_cast_body = e1},r1)
	          | Catch b -> 
		        let e1,r1 = helper n_arg b.exp_catch_body in
		        (Catch {b with exp_catch_body = e1},r1)
                  | Cond b -> 
                        let e1,r1 = helper n_arg b.exp_cond_condition in
                        let e2,r2 = helper n_arg b.exp_cond_then_arm in
                        let e3,r3 = helper n_arg b.exp_cond_else_arm in
                        let r = comb_f [r1;r2;r3] in
                        (Cond {b with
                            exp_cond_condition = e1;
                            exp_cond_then_arm = e2;
                            exp_cond_else_arm = e3;},r)
	          | Finally b ->
		        let e1,r1 = helper n_arg b.exp_finally_body in
		        (Finally {b with exp_finally_body=e1},r1)
                  | Label (l,b) -> 
                        let e1,r1 = helper n_arg b in
                        (Label (l,e1),r1)
                  | Member b -> 
                        let e1,r1 = helper n_arg b.exp_member_base in
                        (Member {b with exp_member_base = e1;},r1)
			    (* An Hoa *)
		  | ArrayAlloc b -> 
                        let el,rl = List.split (List.map (helper n_arg) b.exp_aalloc_dimensions) in
                        (ArrayAlloc {b with exp_aalloc_dimensions = el},(comb_f rl))
                  | New b -> 
                        let el,rl = List.split (List.map (helper n_arg) b.exp_new_arguments) in
                        (New {b with exp_new_arguments = el},(comb_f rl))
                  | Raise b -> (match b.exp_raise_val with
                      | None -> (e,zero)
                      | Some body -> 
                            let e1,r1 = helper n_arg body in
                            (Raise {b with exp_raise_val = Some e1},r1))
                  | Return b->(match b.exp_return_val with
                      | None -> (e,zero)
                      | Some body -> 
                            let e1,r1 = helper n_arg body in
                            (Return {b with exp_return_val = Some e1},r1))
                  | Seq b -> 
                        let e1,r1 = helper n_arg  b.exp_seq_exp1 in 
                        let e2,r2 = helper n_arg  b.exp_seq_exp2 in 
                        let r = comb_f [r1;r2] in
                        (Seq {b with exp_seq_exp1 = e1;exp_seq_exp2 = e2;},r)
                  | Try b -> 
                        let ecl = List.map (helper n_arg) b.exp_catch_clauses in
                        let fcl = List.map (helper n_arg) b.exp_finally_clause in
                        let tb,r1 = helper n_arg b.exp_try_block in
                        let catc, rc = List.split ecl in
                        let fin, rf = List.split fcl in
                        let r = comb_f (r1::(rc@rf)) in
                        (Try {b with
                            exp_try_block = tb;
                            exp_catch_clauses = catc;
                            exp_finally_clause = fin;},r)
                  | Unary b -> 
                        let e1,r1 = helper n_arg b.exp_unary_exp in
                        (Unary {b with exp_unary_exp = e1},r1)
                  | ConstDecl b -> 
                        let l = List.map (fun (c1,c2,c3)-> 
                            let e1,r1 = helper n_arg c2 in
                            ((c1,e1,c3),r1))b.exp_const_decl_decls in
                        let el,rl = List.split l in
                        let r = comb_f rl in
                        (ConstDecl {b with exp_const_decl_decls=el},r) 
                  | VarDecl b -> 
                        let ll = List.map (fun (c1,c2,c3)-> match c2 with
                          | None -> ((c1,None,c3),zero)
                          | Some s -> 
                                let e1,r1 = helper n_arg s in
                                ((c1,Some e1, c3),r1)) b.exp_var_decl_decls in 
                        let dl,rl =List.split ll in
                        let r = comb_f rl in
                        (VarDecl {b with exp_var_decl_decls = dl},r)
                  | While b -> 
                        let wrp,r = match b.exp_while_wrappings with
                          | None -> (None,zero)
                          | Some (s,l) -> 
                                let wrp,r = helper n_arg s in
                                (Some (wrp,l),r) in
                        let ce,cr = helper n_arg b.exp_while_condition in
                        let be,br = helper n_arg b.exp_while_body in
                        let r = comb_f [r;cr;br] in
                        (While {b with
                            exp_while_condition = ce;
                            exp_while_body = be;
                            exp_while_wrappings = wrp},r) in
  helper init_arg e

let transform_exp (e:exp) (init_arg:'b)(f:'b->exp->(exp* 'a) option)  (f_args:'b->exp->'b)(comb_f:'a list -> 'a) (zero:'a) :(exp * 'a) =
  let f_c e lst = match lst with
    | [] -> zero
    | _ -> comb_f lst in
  trans_exp e init_arg f f_args f_c

  (*this maps an expression by passing an argument*)
let map_exp_args (e:exp) (arg:'a) (f:'a -> exp -> exp option) (f_args: 'a -> exp -> 'a) : exp =
  let f1 ac e = push_opt_void_pair (f ac e) in
  fst (transform_exp e arg f1 f_args voidf ())

  (*this maps an expression without passing an argument*)
let map_exp (e:exp) (f:exp->exp option) : exp = 
  (* fst (transform_exp e () (fun _ e -> push_opt_void_pair (f e)) idf2  voidf ()) *)
  map_exp_args e () (fun _ e -> f e) idf2 

  (*this computes a result from expression passing an argument*)
let fold_exp_args (e:exp) (init_a:'a) (f:'a -> exp-> 'b option) (f_args: 'a -> exp -> 'a) (comb_f: 'b list->'b) (zero:'b) : 'b =
  let f1 ac e = match (f ac e) with
    | Some r -> Some (e,r)
    | None ->  None in
  snd(transform_exp e init_a f1 f_args comb_f zero)
 
  (*this computes a result from expression without passing an argument*)
let fold_exp (e:exp) (f:exp-> 'b option) (comb_f: 'b list->'b) (zero:'b) : 'b =
  fold_exp_args e () (fun _ e-> f e) voidf2 comb_f zero

  (*this iterates over the expression and passing an argument*)
let iter_exp_args (e:exp) (init_arg:'a) (f:'a -> exp-> unit option) (f_args: 'a -> exp -> 'a) : unit =
  fold_exp_args  e init_arg f f_args voidf ()

  (*this iterates over the expression without passing an argument*)
let iter_exp (e:exp) (f:exp-> unit option)  : unit =  iter_exp_args e () (fun _ e-> f e) voidf2

  (*this computes a result from expression passing an argument with side-effects*)
let fold_exp_args_imp (e:exp)  (arg:'a) (imp:'c ref) (f:'a -> 'c ref -> exp-> 'b option)
  (f_args: 'a -> 'c ref -> exp -> 'a) (f_imp: 'c ref -> exp -> 'c ref) (f_comb:'b list->'b) (zero:'b) : 'b =
  let fn (arg,imp) e = match (f arg imp e) with
    | Some r -> Some (e,r)
    | None -> None in
  let fnargs (arg,imp) e = ((f_args arg imp e), (f_imp imp e)) in
  snd(transform_exp e (arg,imp) fn fnargs f_comb zero)

  (*this iterates over the expression and passing an argument*)
let iter_exp_args_imp e (arg:'a) (imp:'c ref) (f:'a -> 'c ref -> exp -> unit option)
  (f_args: 'a -> 'c ref -> exp -> 'a) (f_imp: 'c ref -> exp -> 'c ref) : unit =
  fold_exp_args_imp e arg imp f f_args f_imp voidf ()

let set_proc_data_decl (p : proc_decl) (d : data_decl) = p.proc_data_decl <- Some d

let are_same_type (t1 : typ) (t2 : typ) = t1 = t2 (*TODO: this function should be removed, use the one in Cast instead *)

let is_named_type (t : typ) = match t with
  | Named _ -> true
  | _ -> false

let is_null (e : exp) : bool = match e with
  | Null _ -> true
  | _ -> false


let is_var (e : exp) : bool = match e with
  | Var _ -> true
  | _ ->false
  
let rec get_exp_pos (e0 : exp) : loc = match e0 with
  | ArrayAt e -> e.exp_arrayat_pos (* An oa *)
  | Label (_,e) -> get_exp_pos e
  | Assert e -> e.exp_assert_pos
  | Assign e -> e.exp_assign_pos
  | Binary e -> e.exp_binary_pos
  | Bind e -> e.exp_bind_pos
  | Block e -> e.exp_block_pos
  | BoolLit e -> e.exp_bool_lit_pos
  | Break p -> p.exp_break_pos
  | Barrier e -> e.exp_barrier_pos
  | CallRecv e -> e.exp_call_recv_pos
  | CallNRecv e -> e.exp_call_nrecv_pos
  | Cast e -> e.exp_cast_pos
  | Catch e -> e.exp_catch_pos
  | Cond e -> e.exp_cond_pos
  | ConstDecl e -> e.exp_const_decl_pos
  | Continue p -> p.exp_continue_pos
  | Debug e -> e.exp_debug_pos
  | Dprint e -> e.exp_dprint_pos
  | Empty p -> p
  | FloatLit e -> e.exp_float_lit_pos
  | Finally e -> e.exp_finally_pos
  | IntLit e -> e.exp_int_lit_pos
  | Java e -> e.exp_java_pos
  | Member e -> e.exp_member_pos
  | ArrayAlloc e -> e.exp_aalloc_pos (* An Hoa *)
  | New e -> e.exp_new_pos
  | Null p -> p
  | Return e -> e.exp_return_pos
  | Seq e -> e.exp_seq_pos
  | This e -> e.exp_this_pos
  | Unary e -> e.exp_unary_pos
  | Var e -> e.exp_var_pos
  | VarDecl e -> e.exp_var_decl_pos
  | While e -> e.exp_while_pos
  | Unfold e -> e.exp_unfold_pos
  | Try e -> e.exp_try_pos
  | Time (_,_,l) ->  l
  | Raise e -> e.exp_raise_pos

let get_catch_of_exp e = match e with
	| Catch e -> e
	| _  -> Error.report_error {Err.error_loc = get_exp_pos e; Err.error_text = "malformed expression, expecting catch clause"}

let get_finally_of_exp e = match e with
	| Finally e -> e
	| _  -> Error.report_error {Err.error_loc = get_exp_pos e; Err.error_text = "malformed expression, expecting finally clause"}
	(*
let rec type_of_exp e = match e with
  | Assert _ -> None
  | Assign _ -> Some void_type
  | Binary { 
      exp_binary_op = op;
      exp_binary_oper1 = e1;
      exp_binary_oper2 = e2;
      exp_binary_pos = _ 
    } ->
        begin
          let t1 = type_of_exp e1 in
          let t2 = type_of_exp e2 in
          let typ = match op with
            | OpEq | OpNeq | OpLt | OpLte | OpGt | OpGte
            | OpLogicalAnd | OpLogicalOr | OpIsNull | OpIsNotNull -> 
                bool_type
            | OpPlus | OpMinus | OpMult ->
                begin
                  match t1, t2 with
                  | Some Prim Int, Some Prim Int -> int_type 
                  | _ -> float_type
                end
            | OpDiv -> float_type
            | OpMod -> int_type
          in Some typ
        end
  | Bind {
      exp_bind_bound_var = _;
      exp_bind_fields = _;
      exp_bind_body = e1;
      exp_bind_pos = _
    } -> type_of_exp e1
  | Block _ -> Some void_type
  | BoolLit _ -> Some bool_type
  | Break _ -> Some void_type
  | CallRecv _ -> None (* FIX-IT *)
  | CallNRecv _ -> Some void_type
  | Cast {
      exp_cast_target_type = typ;
      exp_cast_body = _;
      exp_cast_pos = _
    } -> Some typ
  | Cond _ -> Some void_type
  | ConstDecl _ -> Some void_type
  | Continue _ -> Some void_type
  | Debug _ -> None
  | Dprint _ -> None
  | Empty _ -> None
  | FloatLit _ -> Some float_type
  | IntLit _ -> Some int_type
  | Java _ -> None
  | Member _ -> None (* FIX-IT *)
  | New {
      exp_new_class_name = name;
      exp_new_arguments = _;
      exp_new_pos = _
    } -> Some (Named name)
  | Null _ -> Some void_type
  | Raise _ -> Some void_type
  | Return _ -> Some void_type
  | Seq _ -> Some void_type
  | This _ -> None
  | Try _ -> Some void_type
  | Unary {
      exp_unary_op = op;
      exp_unary_ = e1;
      exp_unary_pos = _
    } -> type_of_exp e1
  | Unfold _ -> None
  | Var _ -> None
  | VarDecl _ -> Some void_type
  | While _ -> Some void_type
*)

and mkSpecTrue pos = Iformula.mkETrue pos
	(*[SRequires {
		srequires_explicit_inst = [];
		srequires_implicit_inst = [];
		srequires_base  = Iformula.mkTrue pos;
		srequires_continuation =  [SEnsure{
			sensures_base =  Iformula.mkTrue pos;
			sensures_pos = pos
			}];
		srequires_pos = pos
		}]	*)

and mkHoPred  n m mh tv ta fa s i=
      {   hopred_name = n;
          hopred_mode = m;
          hopred_mode_headers = mh;
          hopred_typed_vars = tv;
          hopred_typed_args = ta;
          hopred_fct_args = fa;
          hopred_shape    = s;
          hopred_invariant = i}

let rec get_mut_vars_x e0 =
  (* let comb_f = List.concat in *)
  let f e=
    match e with
      | Var { exp_var_name = id} -> Some [id]
      | _ -> None
  in
  let get_vars e= fold_exp e f (List.concat) [] in
  (* let rec helper (e:exp) = *)
  (*   match e with *)
  (*     | Assert _ *)
  (*     | BoolLit _ *)
  (*     | Break _ *)
  (*     | Continue _ *)
  (*     | Debug _ *)
  (*     | Dprint _ *)
  (*     | Empty _ *)
  (*     | FloatLit _ *)
  (*     | IntLit _ *)
  (*     | Java _ *)
  (*     | Null _ *)
  (*     | This _ *)
  (*     | Time _ *)
  (*     | Unfold _ *)
  (*     | Var _ -> [] *)
  (*     | ArrayAt b -> (\* An Hoa *\) *)
  (*           let rl = (List.map helper b.exp_arrayat_index) in *)
  (*           comb_f rl *)
  (*     | Assign b -> begin *)
  (*           let r1 = helper b.exp_assign_lhs  in *)
  (*           let r2 = helper  b.exp_assign_rhs  in *)
  (*           match b.exp_assign_lhs with *)
  (*             | Var {exp_var_name = id} -> id::r1@r2 *)
  (*             | _ -> r1@r2 *)
  (*       end *)
  (*     | Binary b -> *)
  (*           let r1 = helper  b.exp_binary_oper1  in *)
  (*           let r2 = helper  b.exp_binary_oper2  in *)
  (*           (comb_f [r1;r2]) *)
  (*     | Bind b -> *)
  (*           let r1 = helper  b.exp_bind_body  in *)
  (*           b.exp_bind_bound_var::r1 *)
  (*     | Barrier _ -> [] *)
  (*     | Block b -> *)
  (*            helper  b.exp_block_body *)
  (*     | CallRecv b -> *)
  (*           let r1 = helper  b.exp_call_recv_receiver in *)
  (*           let ler = List.map (helper ) b.exp_call_recv_arguments in *)
  (*            comb_f (r1::ler) *)
  (*     | CallNRecv b -> *)
  (*           let ler = List.map (helper ) b.exp_call_nrecv_arguments in *)
  (*           let r = comb_f ler in *)
  (*           r *)
  (*     | Cast b -> *)
  (*           let r1 = helper b.exp_cast_body in *)
  (*           r1 *)
  (*     | Catch b -> *)
  (*           helper b.exp_catch_body *)
  (*     | Cond b -> *)
  (*           let r1 = helper  b.exp_cond_condition in *)
  (*           let r2 = helper  b.exp_cond_then_arm in *)
  (*           let r3 = helper  b.exp_cond_else_arm in *)
  (*           let r = comb_f [r1;r2;r3] in *)
  (*           r *)
  (*     | Finally b -> *)
  (*           let r1 = helper b.exp_finally_body in *)
  (*           r1 *)
  (*     | Label (l,b) -> *)
  (*           helper  b *)
  (*     | Member b -> (\* begin let _ =  print_endline (!print_exp b.exp_member_base) in *\) *)
  (*            get_vars b.exp_member_base *)
  (*       (\* with *\) *)
  (*       (\*       | Var { exp_var_name = id} -> [id] *\) *)
  (*       (\*       | _ -> [] *\) *)
  (*       (\* end *\) *)
  (*     | ArrayAlloc b -> *)
  (*           let rl= (List.map helper b.exp_aalloc_dimensions) in *)
  (*           comb_f rl *)
  (*     | New b -> *)
  (*           let rl = (List.map helper b.exp_new_arguments) in *)
  (*           (comb_f rl) *)
  (*     | Raise b -> (match b.exp_raise_val with *)
  (*         | None -> [] *)
  (*         | Some body -> *)
  (*               helper  body *)
  (*       ) *)
  (*     | Return b->(match b.exp_return_val with *)
  (*         | None -> [] *)
  (*         | Some body -> *)
  (*               helper body *)
  (*       ) *)
  (*     | Seq b -> *)
  (*           let r1 = helper b.exp_seq_exp1 in *)
  (*           let r2 = helper b.exp_seq_exp2 in *)
  (*           let r = comb_f [r1;r2] in *)
  (*           r *)
  (*     | Try b -> *)
  (*           let ecl = List.map helper b.exp_catch_clauses in *)
  (*           let fcl = List.map helper b.exp_finally_clause in *)
  (*           let r1 = helper b.exp_try_block in *)
  (*           let r = comb_f (r1::(ecl@fcl)) in r *)
  (*     | Unary b -> *)
  (*           let r1 = helper b.exp_unary_exp in *)
  (*           r1 *)
  (*     | ConstDecl b -> *)
  (*           let l = List.map (fun (c1,c2,c3)-> *)
  (*               let r1 = helper  c2 in *)
  (*               r1 *)
  (*           ) b.exp_const_decl_decls *)
  (*           in *)
  (*           let r = comb_f l in *)
  (*           r *)
  (*     | VarDecl b -> *)
  (*           let ll = List.map (fun (c1,c2,c3)-> match c2 with *)
  (*             | None -> [] *)
  (*             | Some s -> *)
  (*                   let r1 = helper s in *)
  (*                   r1 *)
  (*           ) b.exp_var_decl_decls in *)
  (*           let r = comb_f ll in *)
  (*           r *)
  (*     | While b -> *)
  (*           let r = match b.exp_while_wrappings with *)
  (*             | None -> [] *)
  (*             | Some (s,l) -> *)
  (*                   let r = helper s in *)
  (*                   r *)
  (*           in *)
  (*           let cr = helper b.exp_while_condition in *)
  (*           let br = helper b.exp_while_body in *)
  (*           let r = comb_f [r;cr;br] in *)
  (*           r *)
  (* in *)
  (**************************END****************)
  let rec collect_lhs_ass_vars e=
    match e with
      | Assign {exp_assign_lhs = lhs} -> begin
          match lhs with
            | Var {exp_var_name = id} -> Some [id]
            |  _ -> begin
                 collect_lhs_ass_vars lhs
               end
        end
      | _ -> None
  in
  let rec collect_bind_vars e=
    match e with
      | Bind {exp_bind_bound_var = id;
        exp_bind_body = b;
        } -> begin let b_opt = collect_bind_vars b in
        match b_opt with
          | None -> Some [id]
          | Some ids -> Some (id::ids)
        end
      | Member b -> Some (get_vars b.exp_member_base)
      | _ -> None
  in
  let lhs_vars = fold_exp e0 collect_lhs_ass_vars (List.concat) [] in
  let bind_vars = fold_exp e0 collect_bind_vars(List.concat) [] in
  Gen.BList.remove_dups_eq (fun s1 s2 -> String.compare s1 s2 = 0) (lhs_vars@bind_vars)
  (* let mut_vars = helper e0 in *)
  (* Gen.BList.remove_dups_eq (fun s1 s2 -> String.compare s1 s2 = 0) mut_vars *)

let rec get_mut_vars e0 =
  let pr1 = !print_exp in
  let pr2 = pr_list pr_id in
  Debug.no_1 "get_mut_vars" pr1 pr2
      (fun _ -> get_mut_vars_x e0) e0

let genESpec_x body_opt args ret pos=
  (*generate one HeapPred for args and one HeapPred for ret*)
  if args = [] && ret = Void then
    F.mkETrueTrueF (),[]
  else
    let mut_vars = match body_opt with
      | Some body_exp -> get_mut_vars body_exp
      | None -> []
    in
    let hp_pre_decl = {
        hp_name = Globals.hp_default_prefix_name ^ (string_of_int (Globals.fresh_int()));
        hp_typed_inst_vars = List.map (fun arg ->
            let in_info =
              if Gen.BList.mem_eq (fun s1 s2 -> String.compare s1 s2 = 0)
                  arg.param_name mut_vars then Globals.I else Globals.NI
            in
            (arg.param_type, arg.param_name, in_info)
        ) args;
        hp_root_pos = 0;
        hp_is_pre = true;
        hp_formula = F.mkBase F.HEmp (P.mkTrue pos) top_flow [] pos;
    }
    in
    let _ = Debug.ninfo_hprint (add_str "generate HP for Pre" !print_hp_decl) hp_pre_decl no_pos in
    let hp_post_decl = {
        hp_name = Globals.hppost_default_prefix_name ^ (string_of_int (Globals.fresh_int()));
        hp_typed_inst_vars = (List.fold_left (fun r arg ->
            let in_info =
              if Gen.BList.mem_eq (fun s1 s2 -> String.compare s1 s2 = 0)
                  arg.param_name mut_vars then Globals.I else Globals.NI
            in
            let hp_arg = (arg.param_type, arg.param_name, in_info) in
            let ref_args = if arg.param_mod = RefMod then
              [hp_arg;(arg.param_type, arg.param_name ^ (string_of_int (Globals.fresh_int())), Globals.I)]
            else [hp_arg]
            in
            r@ref_args
        ) [] args)@
	    (match ret with
	      | Globals.Void -> []
	      | _ -> [(ret, res_name, Globals.I)]
	    );
        hp_root_pos = 0;
        hp_is_pre = false;
        hp_formula = F.mkBase F.HEmp (P.mkTrue pos) top_flow [] pos;}
    in
    let _ = Debug.ninfo_hprint (add_str "generate HP for Post" !print_hp_decl) hp_post_decl no_pos in
    let pre_eargs = List.map (fun p -> P.Var ((p.param_name, Unprimed),pos)) args in
    (*todo: care ref args*)
    let post_eargs0 = List.fold_left (fun r p ->
        let up_arg = P.Var ((p.param_name, Unprimed),pos) in
        let hp_args =
          if p.param_mod = RefMod then [up_arg; (P.Var ((p.param_name, Primed),pos))]
        else [up_arg]
        in
        r@hp_args
    ) [] args in
    let post_eargs = match ret with
      | Void -> post_eargs0
      | _ -> post_eargs0@[P.Var ((res_name, Unprimed),pos)]
    in
    let _ = Debug.ninfo_hprint (add_str "post_eargs" (pr_list !Ipure.print_formula_exp)) post_eargs no_pos in
    let ipost_simpl = (F.formula_of_heap_with_flow (F.HRel (hp_post_decl.hp_name, post_eargs, pos)) n_flow pos) in
    let ipost = F.mkEAssume ipost_simpl ( F.mkEBase [] [] [] ipost_simpl None pos) (fresh_formula_label "") None in
    let ipre = F.mkEBase [] [] [] (F.formula_of_heap_with_flow (F.HRel (hp_pre_decl.hp_name, pre_eargs, pos)) n_flow pos) (Some ipost) pos in
    (* generate Iformula.struc_infer_formula*)
    (F.EInfer {
        F.formula_inf_post = true;
        F.formula_inf_xpost = None;
        F.formula_inf_transpec = None;
        F.formula_inf_vars = [(hp_pre_decl.hp_name, Globals.Unprimed); (hp_post_decl.hp_name, Globals.Unprimed)];
        F.formula_inf_continuation = ipre;
        F.formula_inf_pos = pos;
    }, [hp_pre_decl;hp_post_decl])

let genESpec body_opt args ret pos=
  let pr1 = !print_param_list in
  let pr2 = string_of_typ in
  Debug.no_2 "genESpec" pr1 pr2 (pr_pair !F.print_struc_formula pr_none)
      (fun _ _ -> genESpec_x body_opt args ret pos) args ret


let genESpec_wNI body_header body_opt args ret pos=
  let print_gen_spec ss unk_hps=
    let _ = print_endline "\nHeap Predicate Declarations" in
    let _ = List.iter (fun hpdcl -> print_endline (!print_hp_decl hpdcl)) unk_hps in
    let _ = Debug.info_hprint (add_str "\ngen spec:" !F.print_struc_formula) ss no_pos in
    ()
  in
  let ss, n_hp_dcls =
    match body_header.proc_static_specs with
      | F.EList [] ->
          let ss, hps = genESpec body_opt args ret pos in
          let _ = print_gen_spec ss hps in
          let _ = Debug.ninfo_hprint (add_str "ss" !F.print_struc_formula) ss no_pos in
          (ss,hps)
      | _ ->
            let _ = if !Globals.sags then
              let ss, hps = genESpec body_opt args ret pos in
              let _ = print_gen_spec ss hps in
              ()
            else ()
            in
            (body_header.proc_static_specs,[])
  in
  {body_header with
      proc_hp_decls = body_header.proc_hp_decls@n_hp_dcls;
      proc_static_specs = ss;
  }

let mkProc sfile id flgs n dd c ot ags r ss ds pos bd =
  (* Debug.info_hprint (add_str "static spec" !print_struc_formula) ss pos; *)
  (* let ni_name = match bd with *)
  (*   | None -> [] *)
  (*   | Some bd -> get_ni_name bd *)
  (* in *)
  (*move this to body parsing step. we know which parameter is mut or imm*)
  (* let ss, n_hp_dcls = match ss with *)
  (*   | F.EList [] -> *)
  (*         let ss, hps = genESpec bd ags r pos in *)
  (*         let _ = Debug.ninfo_hprint (add_str "ss" !F.print_struc_formula) ss no_pos in *)
  (*         (ss,hps) *)
  (*             (\* F.mkETrueTrueF ()  *\) *)
  (*   | _ -> *)
  (*         (\* let _ = Debug.info_hprint (add_str "ss" !F.print_struc_formula) ss no_pos in *\) *)
  (*         ss,[] *)
  (* in *)
  { proc_name = id;
  proc_source =sfile;
  proc_flags = flgs;
  proc_hp_decls = (* n_hp_dcls *)[];
  proc_mingled_name = n; 
  proc_data_decl = dd;
  proc_constructor = c;
  proc_exceptions = ot;
  proc_args = ags;
  proc_return = r;
  (*  proc_important_vars = [];*)
  proc_static_specs = ss;
  proc_dynamic_specs = ds;
  proc_loc = pos;
  proc_is_main = true;
  proc_file = !input_file_name;
  proc_body = bd;
  proc_test_comps = None}

let mkAssert asrtf assmf pid atype pos =
      Assert { exp_assert_asserted_formula = asrtf;
               exp_assert_assumed_formula = assmf;
               exp_assert_path_id = pid;
               exp_assert_type = atype;
               exp_assert_pos = pos }

(** An Hoa [22/08/2011] Extract information from a field declaration of data **)

(**
 * An Hoa : get the typed identifier from a field declaration
 **)
let get_field_typed_id d =
	match d with
		| (tid,_,_,_) -> tid

(**
 * An Hoa : Extract the field name from a field declaration
 **)
let get_field_name f = snd (get_field_typed_id f)

(**
 * An Hoa : Extract the field name from a field declaration
 **)
let get_field_typ f = fst (get_field_typed_id f)

(**
 * An Hoa : Extract the field position from a field declaration
 **)
let get_field_pos f =
	match f with
		| (_,p,_,_) -> p 

(**
 * An Hoa : Check if a field is an inline field 
 **)
let is_inline_field f =
	match f with
		| (_,_,inline,_) -> inline

(** An Hoa [22/08/2011] : End of information extracting functions from field declaration **)



(* look up functions *)

(** An Hoa:
 *  Returns a list of data types which possess a field_name specified.
 **)
let rec look_up_types_containing_field (defs : data_decl list) (field_name : ident) = 
	match defs with
	| [] -> []
	| d::t -> let temp = look_up_types_containing_field t field_name in
				if (List.exists (fun x -> (get_field_name x) = field_name) d.data_fields) then
					d.data_name :: temp
				else temp
(* An Hoa : End *)

let rec look_up_data_def_x pos (defs : data_decl list) (name : ident) = match defs with
  | d :: rest -> if d.data_name = name then d else look_up_data_def_x pos rest name
  | [] -> Err.report_error {Err.error_loc = pos; Err.error_text = "no type declaration named " ^ name ^ " is found"}

and look_up_data_def i pos (defs : data_decl list) (name : ident) 
      = Debug.no_1_num i "look_up_data_def" pr_id pr_none (look_up_data_def_x pos defs) name 

and look_up_parent_name pos ddefs name =
  let ddef = look_up_data_def 1 pos ddefs name in
  ddef.data_parent_name

and look_up_data_def_raw (defs : data_decl list) (name : ident) =
  match defs with
  | d :: rest -> if d.data_name = name then d else look_up_data_def_raw rest name
  | [] -> raise Not_found

and look_up_view_def_raw_x (defs : view_decl list) (name : ident) = match defs with
  | d :: rest -> if d.view_name = name then d else look_up_view_def_raw_x rest name
  | [] -> raise Not_found

and look_up_view_def_raw i (defs : view_decl list) (name : ident) 
      = let pr = pr_list !print_view_decl in
      Debug.no_2_num i "look_up_view_def_raw" pr pr_id pr_none (look_up_view_def_raw_x) defs name 

and look_up_func_def_raw (defs : func_decl list) (name : ident) = match defs with
  | d :: rest -> if d.func_name = name then d else look_up_func_def_raw rest name
  | [] -> raise Not_found

(* An Hoa *)
and look_up_rel_def_raw (defs : rel_decl list) (name : ident) = match defs with
  | d :: rest ->
      (* let _ = print_endline ("l2: rel-def=" ^ d.rel_name) in *)
      if d.rel_name = name then d else look_up_rel_def_raw rest name
  | [] -> raise Not_found

and look_up_hp_def_raw (defs : hp_decl list) (name : ident) = match defs with
  | d :: rest -> if d.hp_name = name then d else look_up_hp_def_raw rest name
  | [] -> raise Not_found

and cmp_hp_def d1 d2 = String.compare d1.hp_name d2.hp_name = 0

and look_up_enum_def pos (defs : enum_decl list) (name : ident) = match defs with
  | d :: rest -> if d.enum_name = name then d else look_up_enum_def pos rest name
  | [] -> Err.report_error {Err.error_loc = pos; Err.error_text = "no enum declaration named " ^ name ^ " is found"}

and look_up_enum_def_raw (defs : enum_decl list) (name : ident) = match defs with
  | d :: rest -> if d.enum_name = name then d else look_up_enum_def_raw rest name
  | [] -> raise Not_found

and look_up_proc_def_raw (procs : proc_decl list) (name : string) = match procs with
  | p :: rest ->
        if p.proc_name = name then
		  p
        else
		  look_up_proc_def_raw rest name
  | [] -> raise Not_found
	    
and look_up_proc_def_mingled_name (procs : proc_decl list) (name : string) = 
  match procs with
    | p :: rest ->
          if p.proc_mingled_name = name then
		    p
          else
		    look_up_proc_def_mingled_name rest name
    | [] -> raise Not_found

(*
(* takes a proc and returns the class where it is declared *)
  and look_up_proc_class_mingled_name (classes : class_decl list) (name : string) = match classes with
  | c :: rest ->
  if (List.exists (fun t -> t.proc_mingled_name =  name) c.class_methods) then c
  else (look_up_proc_class_mingled_name rest name)
  | []	-> raise Not_found    
*)

(* takes a class and returns the list of all the methods from that class or from any of the parent classes *)
and look_up_all_methods (prog : prog_decl) (c : data_decl) : proc_decl list = match c.data_parent_name with 
  | "Object" -> c.data_methods (* it does not have a superclass *)
  | _ ->  
        let cparent_decl = List.find (fun t -> (String.compare t.data_name c.data_parent_name) = 0) prog.prog_data_decls in
        c.data_methods @ (look_up_all_methods prog cparent_decl)  

(**
   * An Hoa : expand the inline fields. This is just the fixed point computation.
   * Input: A list of Iast fields. Output: A list of Iast fields without inline.
**)
and expand_inline_fields ddefs fls =
  (** [Internal] An Hoa : add a prefix k to a field declaration f **)
  let augment_field_with_prefix f k = match f with
	| ((t,id),p,i,ann) -> ((t,k ^ id),p,i,ann)
  in
  if (List.exists is_inline_field fls) then
	let flse = List.map (fun fld -> if (is_inline_field fld) then
	  let fn  = get_field_name fld in
	  let ft = get_field_typ fld in
	  try
		let ddef = look_up_data_def_raw ddefs (string_of_typ ft) in
		let fld_fs = List.map (fun y -> augment_field_with_prefix y (fn ^ Globals.inline_field_expand)) ddef.data_fields in
		fld_fs
	  with
		| Not_found -> failwith "[expand_inline_fields] type not found!"
	else [fld]) fls in
	let flse = List.flatten flse in
	expand_inline_fields ddefs flse
  else fls

and look_up_all_fields (prog : prog_decl) (c : data_decl) = 
  let pr1 = pr_list (fun (ti,_,_,_) -> pr_pair string_of_typ pr_id ti) in 
  Debug.no_1 "look_up_all_fields" pr_id pr1 (fun _ -> look_up_all_fields_x prog c) c.data_name

and look_up_all_fields_x (prog : prog_decl) (c : data_decl) = 
  let current_fields = c.data_fields in
  (* An Hoa : expand the inline fields *)
  let current_fields = expand_inline_fields prog.prog_data_decls current_fields in
  if (String.compare c.data_name "Object") = 0 then
	[]
  else
    let parent = (look_up_data_def 0 no_pos prog.prog_data_decls c.data_parent_name) in 
	current_fields @ (look_up_all_fields prog parent)

(*
  Find view_data_name. Look at each branch, find the data self points to.
  If there are conflicts, report as errors.
*)

and look_up_all_fields_cname (prog : prog_decl) (c : ident) = 
  let ddef = look_up_data_def_raw prog.prog_data_decls c
  in look_up_all_fields prog ddef


and collect_data_view_from_struc (data_names: ident list) (f:F.struc_formula): (ident list) * (ident list) =
  match f with
  | F.EAssume b ->
      collect_data_view_from_formula data_names b.F.formula_assume_simpl
  | F.ECase b->
      let dvll = List.map (fun (_, sf) ->
        collect_data_view_from_struc data_names sf
      ) b.F.formula_case_branches in
      let dll, vll = List.split dvll in
      let dl = Gen.Basic.remove_dups (List.concat dll) in
      let vl = Gen.Basic.remove_dups (List.concat vll) in
      (dl, vl)
  | F.EBase b->
      let dl1, vl1 = collect_data_view_from_formula data_names b.F.formula_struc_base in
      let dl2, vl2 = (
        match b.F.formula_struc_continuation with
        | None -> ([], [])
        | Some sf -> collect_data_view_from_struc data_names sf
      ) in
      let dl = Gen.Basic.remove_dups (dl1 @ dl2) in
      let vl = Gen.Basic.remove_dups (vl1 @ vl2) in
      (dl, vl)
  | F.EInfer b -> collect_data_view_from_struc data_names b.F.formula_inf_continuation
  | F.EList b -> 
      let dvll = List.map (fun (_, sf) -> collect_data_view_from_struc data_names sf) b in
      let dll, vll = List.split dvll in
      let dl = Gen.Basic.remove_dups (List.concat dll) in
      let vl = Gen.Basic.remove_dups (List.concat vll) in
      (dl, vl)
  
and collect_data_view_from_formula_x (data_names: ident list) (f0 : F.formula) : (ident list) * (ident list) = 
  let rec helper (h0 : F.h_formula) = (
    match h0 with
    | F.HeapNode h -> 
        let (v, p), c = h.F.h_formula_heap_node, h.F.h_formula_heap_name in
        if v = self then (
          let deref_str = ref "" in
          for i = 1 to h.F.h_formula_heap_deref do
            deref_str := !deref_str ^ "_star"
          done;
          let view_data_name = c ^ !deref_str in
          let dl, vl = (
            if (List.mem view_data_name data_names) then ([view_data_name], [])
            else ([], [view_data_name])
          ) in
          (dl, vl)
        )
        else ([], [])
    | F.Star h -> 
        let h1, h2, pos = h.F.h_formula_star_h1, h.F.h_formula_star_h2, h.F.h_formula_star_pos in
        let dl1, vl1 = helper h1 in
        let dl2, vl2 = helper h2 in
        let d1 = List.length (dl1 @ vl1) in
        let d2 = List.length (dl2 @ vl2) in
        if d1>0 & d2>0 then
          let _ = report_warning pos ("Star:multiple occurrences of self as heap nodes in one branch are not allowed") in
          ([],[])
        else (
          let dl = Gen.Basic.remove_dups (dl1 @ dl2) in
          let vl = Gen.Basic.remove_dups (vl1 @ vl2) in
          (dl, vl)
        )
    | F.Phase h -> 
        let h1, h2, pos = h.F. h_formula_phase_rd, h.F.h_formula_phase_rw, h.F.h_formula_phase_pos in
        let dl1, vl1 = helper h1 in
        let dl2, vl2 = helper h2 in
        let d1 = List.length (dl1 @ vl1) in
        let d2 = List.length (dl2 @ vl2) in
        if d1>0 & d2>0 then
          report_error pos ("Phase: multiple occurrences of self as heap nodes in one branch are not allowed")
        else (
          let dl = Gen.Basic.remove_dups (dl1 @ dl2) in
          let vl = Gen.Basic.remove_dups (vl1 @ vl2) in
          (dl, vl)
        )
    | F.Conj h ->
        let h1, h2, pos = h.F.h_formula_conj_h1, h.F.h_formula_conj_h2, h.F.h_formula_conj_pos in
        let dl1, vl1 = helper h1 in
        let dl2, vl2 = helper h2 in
        let d1 = List.length (dl1 @ vl1) in
        let d2 = List.length (dl2 @ vl2) in
        if d1>0 & d2>0 then
          report_error pos ("multiple occurrences of self as heap nodes in one branch are not allowed")
        else (
          let dl = Gen.Basic.remove_dups (dl1 @ dl2) in
          let vl = Gen.Basic.remove_dups (vl1 @ vl2) in
          (dl, vl)
        )
    | _ -> ([], [])
  ) in
  match f0 with
    | F.Base f ->
        let dl1, vl1 = helper f.F.formula_base_heap in
        let dl2, vl2 = collect_data_view_from_pure_formula data_names f.F.formula_base_pure in
        let dl = Gen.Basic.remove_dups (dl1 @ dl2) in
        let vl = Gen.Basic.remove_dups (vl1 @ vl2) in
        (dl, vl)
    | F.Exists f -> 
        let dl1, vl1 = helper f.F.formula_exists_heap in
        let dl2, vl2 = collect_data_view_from_pure_formula data_names f.F.formula_exists_pure in
        let dl = Gen.Basic.remove_dups (dl1 @ dl2) in
        let vl = Gen.Basic.remove_dups (vl1 @ vl2) in
        (dl, vl)
    | F.Or f -> 
        let dl1, vl1 = collect_data_view_from_formula data_names f.F.formula_or_f1 in
        let dl2, vl2 = collect_data_view_from_formula data_names f.F.formula_or_f2 in
        let dl = Gen.Basic.remove_dups (dl1 @ dl2) in
        let vl = Gen.Basic.remove_dups (vl1 @ vl2) in
        (dl, vl)

and collect_data_view_from_formula (data_names: ident list) (f0 : F.formula) : (ident list) * (ident list) = 
  let pr1 = !F.print_formula in
  let pr2 = pr_list pr_id in
  let pr3 = pr_pair pr2 pr2 in
  Debug.no_1 "collect_data_view_from_formula" pr1 pr3
      (fun _ -> collect_data_view_from_formula_x data_names f0) f0

and collect_data_view_from_pure_formula_x (data_names: ident list) (f0 : P.formula) : (ident list) * (ident list) =
  match f0 with
  | P.BForm (bf, _) -> collect_data_view_from_pure_bformula data_names bf
  | P.And (f1, f2, _) ->
      let dl1, vl1 = collect_data_view_from_pure_formula data_names f1 in
      let dl2, vl2 = collect_data_view_from_pure_formula data_names f2 in
      let dl = Gen.Basic.remove_dups (dl1 @ dl2) in
      let vl = Gen.Basic.remove_dups (vl1 @ vl2) in
      (dl, vl)
  | P.AndList fs ->
      let dvll = List.map (fun (_, f1) -> collect_data_view_from_pure_formula data_names f1) fs in
      let dll, vll = List.split dvll in
      let dl = Gen.Basic.remove_dups (List.concat dll) in
      let vl = Gen.Basic.remove_dups (List.concat vll) in
      (dl, vl)
  | P.Or (f1, f2, _, _) ->
      let dl1, vl1 = collect_data_view_from_pure_formula data_names f1 in
      let dl2, vl2 = collect_data_view_from_pure_formula data_names f2 in
      let dl = Gen.Basic.remove_dups (dl1 @ dl2) in
      let vl = Gen.Basic.remove_dups (vl1 @ vl2) in
      (dl, vl)
  | P.Not (f1, _, _) -> collect_data_view_from_pure_formula data_names f1
  | P.Forall (_, f1, _, _) -> collect_data_view_from_pure_formula data_names f1
  | P.Exists (_, f1, _, _) -> collect_data_view_from_pure_formula data_names f1


and collect_data_view_from_pure_formula (data_names: ident list) (f0 : P.formula) : (ident list) * (ident list) =
  let pr1 = !P.print_formula in
  let pr2 = pr_list pr_id in
  let pr3 = pr_pair pr2 pr2 in
  Debug.no_1 "collect_data_view_from_pure_formula" pr1 pr3
      (fun _ -> collect_data_view_from_pure_formula_x data_names f0) f0

and collect_data_view_from_pure_bformula (data_names: ident list) (bf : P.b_formula) : (ident list) * (ident list) =
  let pf, _ = bf in
  match pf with
  | P.XPure _ | P.BConst _ | P.BVar _ | P.SubAnn _ -> ([], [])
  | P.Lt _ | P.Lte _ | P.Gt _ | P.Gte _ -> ([], [])
  | P.Eq (e1, e2, _)
  | P.Neq (e1, e2, _) ->
      let dl1, vl1 = collect_data_view_from_pure_exp data_names e1 in
      let dl2, vl2 = collect_data_view_from_pure_exp data_names e2 in
      let dl = Gen.Basic.remove_dups (dl1 @ dl2) in
      let vl = Gen.Basic.remove_dups (vl1 @ vl2) in
      (dl, vl)
  | P.EqMax _ | P.EqMin _ | P.LexVar _ -> ([], [])
  | P.BagIn _ | P.BagNotIn _ | P.BagSub _ | P.BagMin _ | P.BagMax _ -> ([], [])
  | P.ListIn _ | P.ListNotIn _ | P.ListAllN _ | P.ListPerm _ -> ([], [])
  | P.VarPerm _ | P.RelForm _ -> ([], [])

and collect_data_view_from_pure_exp_x (data_names: ident list) (e0 : P.exp) : (ident list) * (ident list) =
  match e0 with
  | P.Ann_Exp (e, t, pos) -> (
      match e with
      | P.Var ((id, _), _) ->
            if String.compare id self != 0 then ([],[]) else
              let t_id = string_of_typ t in
              if (List.mem t_id data_names) then
                ([t_id], [])       (* type annotation of self to view decl *)
              else
                report_error pos ("self has invalid type: " ^ t_id)
      | _ -> ([], [])
    )
  | P.Bptriple _ -> ([], []) (*MERGE CHECK*)
  | P.Null _ | P.Level _  | P.Var _ -> ([], [])
  | P.IConst _ | P.FConst _ | P.AConst _  | P.InfConst _ | P.Tsconst _ -> ([], [])
  | P.Add _ | P.Subtract _ | P.Mult _ | P.Div _ -> ([], [])
  | P.Max _ | P.Min _ | P.TypeCast _ -> ([], [])
  | P.Bag _ | P.BagUnion _ | P.BagIntersect _ | P.BagDiff _ -> ([], [])
  | P.List _ | P.ListCons _ | P.ListHead _ | P.ListTail _ -> ([], [])
  | P.ListLength _ | P.ListAppend _ | P.ListReverse _ -> ([], [])
  | P.ArrayAt _ | P.Func _ -> ([], [])

and collect_data_view_from_pure_exp (data_names: ident list) (e0 : P.exp) : (ident list) * (ident list) =
  let pr1 = !P.print_formula_exp in
  let pr2 = pr_list pr_id in
  let pr3 = pr_pair pr2 pr2 in
  Debug.no_1 "collect_data_view_from_pure_exp" pr1 pr3
      (fun _ -> collect_data_view_from_pure_exp_x data_names e0) e0

and find_data_view_x (data_names: ident list) (f:Iformula.struc_formula) pos :  (ident list) * (ident list) =
  let (dl,el) = collect_data_view_from_struc data_names f in
  if (List.length dl>1) then report_error pos ("self points to different data node types")
  else (dl,el)

and find_data_view (data_names: ident list) (f:Iformula.struc_formula) pos :  (ident list) * (ident list) =
  let pr1 a= String.concat  "," a in
  let pr2 = !print_struc_formula in
  Debug.no_2 "find_data_view" pr1 pr2 (pr_pair pr1 pr1)
      (fun _ _ -> find_data_view_x data_names f pos) data_names f

and syn_data_name  (data_decls : data_decl list)  (view_decls : view_decl list) : (view_decl * (ident list) * (ident list)) list =
  Debug.no_1 "syn_data_name" pr_no pr_no
      (fun _ -> syn_data_name_x data_decls view_decls) () 

and syn_data_name_x  (data_decls : data_decl list)  (view_decls : view_decl list) : (view_decl * (ident list) * (ident list)) list =
  let view_decls_org = view_decls in
  let data_names = List.map (fun v -> v.data_name) data_decls in
  (* Restore the original list of view_decls and continue with the previous implementation *)
  let view_decls = view_decls_org in
  let rl = List.map (fun v -> let (a,b)=(find_data_view data_names v.view_formula no_pos) in (v, a, b)) view_decls in
  rl

and fixpt_data_name (view_ans)  =
  let pr1 vd = vd.view_name in
  let pr2 = pr_list (fun x -> x) in
  let pr = pr_list (pr_triple pr1 pr2 pr2)  in 
  Debug.no_1 "fixpt_data_name" pr pr fixpt_data_name_x view_ans

(* TODO : cater to aliasing with SELF; cater to mutual-recursion *)

and fixpt_data_name_x (view_ans:(view_decl * ident list *ident list) list) =
  let fetch r = List.concat (List.map 
      (fun id -> 
          try 
          let (_,a,_) = List.find (fun (v,_,_)-> v.view_name=id) view_ans in a
          with Not_found -> 
              []
      )
      r) in 
  (*let v,a,r = view_ans in*)
  let r = List.map (fun (v,a,r) ->  
  (*let _ = print_string("View :"^List.hd a^"\n") in*) (v,Gen.Basic.remove_dups (a@(fetch r)),r)) view_ans in
  let check (v,a1,_) (_,a2,_) c = 
    let d1=List.length a1 in
    let d2=List.length a2 in
    if d1==d2 then c
    else if d2>1 then report_error no_pos ("self of "^(v.view_name)^"indirectly points to different data node types")
    else true in
  (* let check a1 a2 c =  *)
  (*   let pr (_,a,_) = string_of_ident_list a in *)
  (*   Debug.no_2 "check_fixpt_data_name" pr pr string_of_bool (fun _ _ -> check a1 a2 c) a1 a2 in  *)
  let change = List.fold_right2 check r view_ans false in 
  if change then fixpt_data_name_x r
  else r

and incr_fixpt_view (dl:data_decl list) (view_decls: view_decl list)  = 
  let create n = if n="" then [] else [n] in
  match view_decls with
    | [] -> ""
    | vd::vds -> let vans = List.map (fun v -> (v,(create v.view_data_name),v.view_pt_by_self)) vds in
      let vl = syn_data_name dl [vd] in
      let vl = fixpt_data_name (vl@vans) in
	  (* let _ = print_endline "Call update_fixpt from incr_fixpt_view" in *)
      let _ = update_fixpt vl in
      (List.hd view_decls).view_data_name

and update_fixpt_x (vl:(view_decl * ident list *ident list) list)  = 
  List.iter (fun (v,a,tl) ->
	  (* print_endline ("update_fixpt for " ^ v.view_name);
		 print_endline ("Feasible self type: " ^ (String.concat "," a)); *)
      v.view_pt_by_self<-tl;
      if (List.length a==0) then 
        if v.view_is_prim || v.view_kind = View_EXTN then v.view_data_name <- (v.view_name) (* TODO WN : to add pred name *)
        else if String.length v.view_data_name = 0 then
          report_warning no_pos ("self of "^(v.view_name)^" cannot have its type determined")
        else ()
      else v.view_data_name <- List.hd a) vl

and update_fixpt (vl:(view_decl * ident list *ident list) list)  =
  let pr_idl = pr_list pr_id in
  let pr = pr_list (pr_triple !print_view_decl pr_idl pr_idl) in
  Debug.no_1 "update_fixpt" pr pr_none update_fixpt_x vl

and set_check_fixpt (data_decls : data_decl list) (view_decls: view_decl list)  =
  let pr = pr_list_ln !print_data_decl in 
  let pr2 = pr_list_ln !print_view_decl in 
  Debug.no_2 "set_check_fixpt" pr pr2 pr_none (fun _ _ -> set_check_fixpt_x data_decls view_decls )  data_decls view_decls

and set_check_fixpt_x  (data_decls : data_decl list) (view_decls : view_decl list)  =
  let vl = syn_data_name data_decls view_decls in
  let vl = fixpt_data_name vl in
  (* An Hoa *)
  (* let _ = print_endline "Call update_fixpt from set_check_fixpt_x" in *)
  update_fixpt vl


and data_name_of_view (view_decls : view_decl list) (f0 : F.struc_formula) : ident = 
  let pr = !print_struc_formula in
  Debug.no_1(* _loop *) "data_name_of_view" pr (fun x->x)
      (fun _ -> data_name_of_view_x (view_decls : view_decl list) (f0 : F.struc_formula)) f0

and data_name_of_view_x (view_decls : view_decl list) (f0 : F.struc_formula) : ident = 

  let handle_list_res  (e:string list): string = 
	let r = List.filter (fun c-> (String.length c)>0) e in
	if (List.length r == 0 ) then ""
	else
	  let h = List.hd r in
	  let tl = List.tl r in
	  if (List.for_all (fun c-> (String.compare c h)==0 ) tl) then (List.hd r)
	  else "" in
  
  let rec data_name_in_struc (f:F.struc_formula):ident = match f with
	| F.EAssume b -> data_name_of_view1 view_decls b.F.formula_assume_simpl
	| F.ECase b-> handle_list_res (Gen.fold_l_snd (fun c->[data_name_in_struc c]) b.F.formula_case_branches)
	| F.EBase b-> handle_list_res (data_name_of_view1 view_decls b.F.formula_struc_base ::(Gen.fold_opt (fun c-> [data_name_of_view_x view_decls c]) b.F.formula_struc_continuation))
	| F.EInfer b -> data_name_in_struc b.F.formula_inf_continuation
	| F.EList b -> handle_list_res (List.map (fun c-> data_name_in_struc(snd c)) b)  in
   data_name_in_struc f0

and data_name_of_view1 (view_decls : view_decl list) (f0 : F.formula) : ident = 
  let rec get_name_from_heap (h0 : F.h_formula) : ident option = match h0 with
	| F.HeapNode h ->
		  let (v, p), c = h.F.h_formula_heap_node, h.F.h_formula_heap_name in
		  if v = self then
			(* if c is a view, use the view's data name recursively.
			   Otherwise (c is data) use c *)
			try
			  let vdef = look_up_view_def_raw 1 view_decls c in
			  if String.length (vdef.view_data_name) > 0 then
				Some vdef.view_data_name
			  else
				Some (data_name_of_view_x view_decls vdef.view_formula)
			with
			  | Not_found -> Some c
		  else
			None
	| F.Star h ->
		  let h1, h2, pos = h.F.h_formula_star_h1, h.F.h_formula_star_h2, h.F.h_formula_star_pos in
		  let n1 = get_name_from_heap h1 in
		  let n2 = get_name_from_heap h2 in
		  if Gen.is_some n1 && Gen.is_some n2 then
			report_error pos ("multiple occurrences of self as heap nodes in one branch are not allowed")
		  else if Gen.is_some n1 then
			n1
		  else
			n2
	| F.Conj h ->
		  let h1, h2, pos = h.F.h_formula_conj_h1, h.F.h_formula_conj_h2, h.F.h_formula_conj_pos in
		  let n1 = get_name_from_heap h1 in
		  let n2 = get_name_from_heap h2 in
		  if Gen.is_some n1 && Gen.is_some n2 then
			report_error pos ("multiple occurrences of self as heap nodes in one branch are not allowed")
		  else if Gen.is_some n1 then
			n1
		  else
			n2			
	| _ -> None 
  and get_name (f0 : F.formula) = match f0 with
	| F.Or f ->
		  let f1, f2, pos = f.F.formula_or_f1, f.F.formula_or_f2, f.F.formula_or_pos in
		  let n1 = get_name f1 in
		  let n2 = get_name f2 in
		  if Gen.is_some n1 && Gen.is_some n2 then
			let nn1 = Gen.unsome n1 in
			let nn2 = Gen.unsome n2 in
			if nn1 = nn2 then
			  Some nn1
			else
			  report_error pos ("two branches define self with different node types")
		  else if Gen.is_some n1 then
			n1
		  else
			n2
	| F.Base f ->
		  let h, p, pos = f.F.formula_base_heap, f.F.formula_base_pure, f.F.formula_base_pos in
		  get_name_from_heap h
	| F.Exists f ->
		  let h, p, pos = f.F.formula_exists_heap, f.F.formula_exists_pure, f.F.formula_exists_pos in
		  get_name_from_heap h
  in
  let data_name = match get_name f0 with
	| Some nn -> nn
	| None -> ""
  in
  data_name

and contains_field_ho (e:exp) : bool =
  let helper e = match e with | Member _ -> Some true | _ -> None in
  fold_exp e (helper) (List.exists (fun b -> b)) false

 
(* smart constructors *)

(* WN : may want to add pos info *)
let mkDataDecl name fields parent_name invs is_template methods =
  { data_name = name;
    data_fields = fields;
    data_parent_name = parent_name;
    data_invs = invs;
    data_pos = no_pos;
    data_is_template = is_template;
    data_methods = methods }

let mkConstDecl t d p = 
  ConstDecl { exp_const_decl_type = t;
              exp_const_decl_decls = d;
              exp_const_decl_pos = p }

and mkVarDecl t d p = 
  VarDecl { exp_var_decl_type = t;
            exp_var_decl_decls = d;
            exp_var_decl_pos = p }

and mkGlobalVarDecl t d p = 
  { exp_var_decl_type = t;
    exp_var_decl_decls = d;
    exp_var_decl_pos = p }

and mkLogicalVarDecl t d p =
  { exp_var_decl_type = t;
    exp_var_decl_decls = d;
    exp_var_decl_pos = p }

and mkSeq e1 e2 l = match e1 with
  | Empty _ -> e2
  | _ -> (
      match e2 with
      | Empty _ -> e1
      | _ -> Seq { exp_seq_exp1 = e1;
                   exp_seq_exp2 = e2;
                   exp_seq_pos = l }
    )

and mkAssign op lhs rhs path_id pos = 
  Assign { exp_assign_op = op;
           exp_assign_lhs = lhs;
           exp_assign_rhs = rhs;
           exp_assign_path_id = path_id;
           exp_assign_pos = pos }

and mkBinary op oper1 oper2 path_id pos =
  Binary { exp_binary_op = op;
           exp_binary_oper1 = oper1;
           exp_binary_oper2 = oper2;
           exp_binary_path_id = path_id;
           exp_binary_pos = pos }

and mkUnary op oper path_id pos =
  Unary { exp_unary_op = op;
          exp_unary_exp = oper;
          exp_unary_path_id = path_id;
          exp_unary_pos = pos }

and mkRaise ty usety rval final pid pos =
  Raise { exp_raise_type = ty ;
          exp_raise_val = rval;
          exp_raise_from_final = final;
          exp_raise_use_type = usety;
          exp_raise_path_id = pid;
          exp_raise_pos = pos;}

and mkCatch var var_type fl_type fl_var body pos =
  Catch { exp_catch_var = var; 
          exp_catch_flow_type = fl_type;
          exp_catch_alt_var_type = var_type;
          exp_catch_flow_var = fl_var;
          exp_catch_body = body; 
          exp_catch_pos = pos }

and mkTry body catch finally pid pos =
  Try { exp_try_block = body;
        exp_catch_clauses = catch;
        exp_finally_clause = finally;
        exp_try_path_id = pid;
        exp_try_pos = pos; }

and mkVar name pos =
  Var { exp_var_name = name;
        exp_var_pos = pos;}

and mkBlock body lbl local_vars pos =
  Block { exp_block_body = body;
          exp_block_jump_label = lbl;
          exp_block_local_vars = local_vars;
          exp_block_pos = pos }

and mkIntLit i pos =
  IntLit { exp_int_lit_val = i;
           exp_int_lit_pos = pos }

and mkFloatLit f pos =
  FloatLit { exp_float_lit_val = f;
             exp_float_lit_pos = pos}

and mkBoolLit b pos =
  BoolLit { exp_bool_lit_val = b;
            exp_bool_lit_pos = pos; }

and mkNew class_name args pos= 
  New { exp_new_class_name = class_name;
        exp_new_arguments = args;
        exp_new_pos = pos }

and mkNull pos = Null pos

and mkArrayAt base index pos =
  ArrayAt { exp_arrayat_array_base = base;
            exp_arrayat_index = index;
            exp_arrayat_pos = pos; }

and mkMember base fields path_id pos =
  Member { exp_member_base = base;
           exp_member_fields = fields;
           exp_member_path_id = path_id;
           exp_member_pos = pos }

and mkCallNRecv method_name lock args path_id pos =
  CallNRecv { exp_call_nrecv_method = method_name;
              exp_call_nrecv_lock = lock;
              exp_call_nrecv_arguments = args;
              exp_call_nrecv_path_id = path_id;
              exp_call_nrecv_pos = pos }

and mkCond condition then_exp else_exp path_id pos =
  Cond { exp_cond_condition = condition;
        exp_cond_then_arm = then_exp;
        exp_cond_else_arm = else_exp;
        exp_cond_path_id = path_id;
        exp_cond_pos = pos }

and mkReturn return_val path_id pos =
  Return { exp_return_val = return_val;
           exp_return_path_id = path_id;
           exp_return_pos = pos }

and mkBreak jump_label path_id pos =
  Break { exp_break_jump_label = jump_label;
          exp_break_path_id = path_id;
          exp_break_pos = pos }

and mkContinue jump_label path_id pos =
  Continue { exp_continue_jump_label = jump_label;
             exp_continue_path_id = path_id;
             exp_continue_pos = pos }

and mkCast target_typ body pos =
  Cast { exp_cast_target_type = target_typ;
         exp_cast_body = body;
         exp_cast_pos = pos }

(*************************************************************)
(* Building the graph representing the class hierarchy       *)
(*************************************************************)

type ch_node = { ch_node_name : ident
				   (* mutable ch_node_class : data_decl option *) }
	
module CD = struct
  type t = ch_node
  let compare c1 c2 = compare c1.ch_node_name c2.ch_node_name
  let hash c = Hashtbl.hash c.ch_node_name
  let equal c1 c2 = (c1.ch_node_name = c2.ch_node_name)
end

module CH = Graph.Imperative.Digraph.Concrete(CD)
module TraverseCH = Graph.Traverse.Dfs(CH)

module W = struct
  type label = CH.E.label
  type t = int
  let weight x = 1
  let zero = 0
  let add = (+)
  let compare = compare
end

module PathCH = Graph.Path.Dijkstra(CH)(W)

let class_hierarchy = CH.create ()

let build_hierarchy (prog : prog_decl) =
  (* build the class hierarchy *)
  let add_edge (cdef : data_decl) = 
	CH.add_edge class_hierarchy (CH.V.create {ch_node_name = cdef.data_name})
	  (CH.V.create {ch_node_name = cdef.data_parent_name}) in
  let add_edge cdef = 
	let pr cdef = cdef.data_name^"<:"^cdef.data_parent_name in
	Debug.no_1 "add_edge" pr (fun _ -> "") add_edge cdef in
  let _ = List.map add_edge prog.prog_data_decls in
	if TraverseCH.has_cycle class_hierarchy then begin
	  print_string ("Error: Class hierarchy has cycles\n");
	  failwith ("Class hierarchy has cycles\n");
	end (* else begin
	  (* now add class definitions in *)
		   let update_node node = 
		   let cdef = look_up_data_def no_pos prog.prog_data_decls node.ch_node_name in
		   node.ch_node_class <- Some cdef
		   in
		   CH.iter_vertex update_node class_hierarchy
		   end
		*)
(*
  see if c1 is sub class of c2 and what are the classes in between.
*)
let exists_path (c1 : ident) (c2 : ident) :bool = 
  if c2="null" then true
  else
	  try
		let _ = PathCH.shortest_path class_hierarchy 
				(CH.V.create {ch_node_name = c1}) 
				(CH.V.create {ch_node_name = c2}) in
		true
	  with 
 		| _ -> false

let exists_path c1 c2 =	Debug.no_2(* _loop *) "exists_path" pr_id pr_id  string_of_bool exists_path c1 c2 
		
(* (\* is t1 a subtype of t2 *\) *)
let sub_type2 (t1 : typ) (t2 : typ) =  
  if is_named_type t1 && is_named_type t2 then 
    exists_path (string_of_typ t1) (string_of_typ t2)
  else false
   
let sub_type t1 t2 = sub_type t1 t2 || sub_type2 t1 t2

let compatible_types (t1 : typ) (t2 : typ) = sub_type t1 t2 || sub_type t2 t1

let inbuilt_build_exc_hierarchy () =
  let _  = exlist # add_edge top_flow "" in
  let _ = (exlist # add_edge c_flow top_flow) in
  let _ = (exlist # add_edge "__abort" top_flow) in
  let _ = (exlist # add_edge n_flow c_flow) in
  let _ = (exlist # add_edge abnormal_flow c_flow) in
  let _ = (exlist # add_edge raisable_class abnormal_flow) in
  let _ = (exlist # add_edge "__others" abnormal_flow) in
  let _ = (exlist # add_edge ret_flow "__others") in
  let _ = (exlist # add_edge loop_ret_flow "__others") in
  let _ = (exlist # add_edge cont_top "__others") in
  let _ = (exlist # add_edge brk_top "__others") in
  let _ = (exlist # add_edge spec_flow "__others") in
  let _ = (exlist # add_edge error_flow top_flow) in
  let _ = (exlist # add_edge bfail_flow top_flow) in
  ()

let build_exc_hierarchy (clean:bool)(prog : prog_decl) =
  (* build the class hierarchy *)
  let _ = List.map (fun c-> (exlist # add_edge c.data_name c.data_parent_name)) (prog.prog_data_decls) in
  let _ = if clean then (exlist # remove_dupl ) in
	if (exlist # has_cycles) then begin
	  print_string ("Error: Exception hierarchy has cycles\n");
	  failwith ("Exception hierarchy has cycles\n");
	end 

let build_exc_hierarchy (clean:bool)(prog : prog_decl) =
  let pr _ = exlist # string_of in
  Debug.no_1 "build_exc_hierarchy" pr pr (fun _ -> build_exc_hierarchy clean prog) clean

let rec label_e e =
  let rec helper e = match e with
    | Catch e -> Error.report_error   {Err.error_loc = e.exp_catch_pos; Err.error_text = "unexpected catch clause"}  
    | Block _
	| ArrayAt _ (* AN HOA : no label for array access *)
    | Cast _
    | ConstDecl _ 
    | BoolLit _ 
	| Barrier _  (*Cristian: no label for barrier calls*)
    | Debug _ 
    | Dprint _ 
    | Empty _ 
    | FloatLit _ 
    | IntLit _
    | Java _ 
    | Unfold _ 
    | Var _ 
    | This _ 
    | Time _
    | Null _ 
    | VarDecl _
    | Seq _
		| ArrayAlloc _ (* An Hoa *)
    | New _ 
    | Finally _ 
    | Label _ -> None
    | _ -> Some (helper2 e)
  and helper2 e = match e with
    | Assert e -> 
		  let nl = fresh_formula_label (snd e.exp_assert_path_id) in
		  iast_label_table:= (Some nl,"assert",[],e.exp_assert_pos) ::!iast_label_table;
		  Assert {e with exp_assert_path_id = nl }
    | Assign e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"assign",[],e.exp_assign_pos) ::!iast_label_table;
		  Assign {e with 
			  exp_assign_lhs = label_e e.exp_assign_lhs;
			  exp_assign_rhs = label_e e.exp_assign_rhs;
			  exp_assign_path_id = nl;}
    | Binary e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"binary",[],e.exp_binary_pos) ::!iast_label_table;
		  Binary{e with
			  exp_binary_oper1 = label_e e.exp_binary_oper1;
			  exp_binary_oper2 = label_e e.exp_binary_oper2;
			  exp_binary_path_id = nl;}
    | Bind e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"bind",[],e.exp_bind_pos) ::!iast_label_table;
		  Bind {e with
 			  exp_bind_body = label_e e.exp_bind_body;
			  exp_bind_path_id  = nl;}
    | Break e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"break",[],e.exp_break_pos) ::!iast_label_table;
		  Break{ e with exp_break_path_id = nl;}  
    | CallRecv e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"callRecv",[],e.exp_call_recv_pos) ::!iast_label_table;
		  CallRecv {e with
			  exp_call_recv_receiver = label_e e.exp_call_recv_receiver;
			  exp_call_recv_arguments  = List.map label_e e.exp_call_recv_arguments;
			  exp_call_recv_path_id = nl;}
    | CallNRecv e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"callNRecv",[],e.exp_call_nrecv_pos) ::!iast_label_table;
		  CallNRecv { e with 
			  exp_call_nrecv_arguments =  List.map label_e e.exp_call_nrecv_arguments;
			  exp_call_nrecv_path_id = nl;}
    | Cond e -> 
		  let nl = fresh_branch_point_id "" in
      let then_pos = get_exp_pos e.exp_cond_then_arm in
      let else_pos = get_exp_pos e.exp_cond_else_arm in
		  iast_label_table:= (nl,"cond",[(nl,0,then_pos);(nl,1,else_pos)],e.exp_cond_pos) ::!iast_label_table;
		  Cond {e with 
			  exp_cond_condition = label_e e.exp_cond_condition;
			  exp_cond_then_arm  = Label ((nl,0),(label_e e.exp_cond_then_arm));
			  exp_cond_else_arm  = Label ((nl,1),(label_e e.exp_cond_else_arm));
			  exp_cond_path_id =nl;}
    | Continue e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"continue",[],e.exp_continue_pos) ::!iast_label_table;
		  Continue {e with  exp_continue_path_id = nl;}
    | Member e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"member",[],e.exp_member_pos) ::!iast_label_table;
		  Member {e with
			  exp_member_base = label_e e.exp_member_base;
			  exp_member_path_id = nl;}  
    | Raise e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"raise",[],e.exp_raise_pos) ::!iast_label_table;
		  Raise {e with
		      exp_raise_val = 
			      (match e.exp_raise_val with 
				    | None -> None 
				    | Some s-> Some (label_e s));
		      exp_raise_path_id = nl;}  
    | Return e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"return",[],e.exp_return_pos) ::!iast_label_table;
		  Return{ e with
			  exp_return_val = (match e.exp_return_val with | None -> None | Some s-> Some (label_e s));
			  exp_return_path_id = nl;}  
    | Try e -> 
		  let nl = fresh_branch_point_id "" in
      let rec lbl_list_constr id cclauses = match cclauses with
        | [] -> []
        | exp::rest -> (nl, id, get_exp_pos exp)::(lbl_list_constr (id+1) rest)
      in
		  iast_label_table:= (nl,"try",(lbl_list_constr 0 e.exp_catch_clauses),e.exp_try_pos)::!iast_label_table;
		  let lbl_c n d = 
			let d = get_catch_of_exp d in
			Catch {d with	exp_catch_body = Label((nl,n),label_e d.exp_catch_body);} in
		  Try {e with
			  exp_try_block = label_e e.exp_try_block;
			  exp_try_path_id = nl;
			  exp_catch_clauses  = (fst (List.fold_left (fun (a,c) d-> ((lbl_c c d)::a, c+1)) ([],0) e.exp_catch_clauses));
			  exp_finally_clause = List.map label_e e.exp_finally_clause;}
    | Unary e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"unary",[],e.exp_unary_pos) ::!iast_label_table;
		  Unary{ e with
			  exp_unary_exp = label_e e.exp_unary_exp;
			  exp_unary_path_id = fresh_branch_point_id "";}  		
    | While e -> 
		  let nl = fresh_branch_point_id "" in
		  iast_label_table:= (nl,"while",[],e.exp_while_pos) ::!iast_label_table;
		  While {e with
			  exp_while_condition = label_e e.exp_while_condition;
			  exp_while_body = label_e e.exp_while_body;
			  exp_while_path_id = nl;
			  exp_while_wrappings = match e.exp_while_wrappings with | None -> None | Some (s,l)-> Some (label_e s,l);}  
    | _ -> Error.report_error   
      {Err.error_loc = get_exp_pos e; Err.error_text = "exp not considered in label_e yet"}  
  in map_exp e helper

(* This method adds (label,name,branches,loc) to iast_lable_table.
   For  branching points of expressions, such
   as conditionals, a Label construct is added.
*)
let label_exp e = label_e e 
(*
let rec label_exp e = match e with
  | Block e -> Block {e with exp_block_body = label_exp e.exp_block_body;}
  | Cast e -> Cast {e with  exp_cast_body = label_exp e.exp_cast_body;}
  | ConstDecl e -> ConstDecl {e with exp_const_decl_decls = List.map (fun (c1,c2,c3)-> (c1,(label_exp c2),c3)) e.exp_const_decl_decls;}
  | Catch e -> Error.report_error   {Err.error_loc = e.exp_catch_pos; Err.error_text = "unexpected catch clause"}
  | BoolLit _ 
  | Debug _ 
  | Dprint _ 
  | Empty _ 
  | FloatLit _ 
  | IntLit _
  | Java _ 
  | Unfold _ 
  | Var _ 
  | This _ 
  | Time _ 
  | Null _ -> e
  | VarDecl e -> VarDecl {e with exp_var_decl_decls = List.map (fun (c1,c2,c3)-> (c1,(match c2 with | None-> None | Some s -> Some(label_exp s)),c3)) e.exp_var_decl_decls;}  
  | Seq e -> Seq {e with
		exp_seq_exp1 = label_exp e.exp_seq_exp1;
		exp_seq_exp2 = label_exp e.exp_seq_exp2;}
  | New e -> New{e with exp_new_arguments = List.map label_exp e.exp_new_arguments;}
  | Finally e -> Finally {e with exp_finally_body = label_exp e.exp_finally_body}
  | Label (pid,e) -> Label (pid, (label_exp e))
  | Assert e -> 
		let nl = fresh_formula_label (snd e.exp_assert_path_id) in
		iast_label_table:= (Some nl,"assert",[],e.exp_assert_pos) ::!iast_label_table;
		Assert {e with exp_assert_path_id = nl }
  | Assign e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"assign",[],e.exp_assign_pos) ::!iast_label_table;
		Assign {e with 
				   exp_assign_lhs = label_exp e.exp_assign_lhs;
				   exp_assign_rhs = label_exp e.exp_assign_rhs;
				   exp_assign_path_id = nl;}
  | Binary e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"binary",[],e.exp_binary_pos) ::!iast_label_table;
		Binary{e with
				   exp_binary_oper1 = label_exp e.exp_binary_oper1;
				   exp_binary_oper2 = label_exp e.exp_binary_oper2;
				   exp_binary_path_id = nl;}
  | Bind e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"bind",[],e.exp_bind_pos) ::!iast_label_table;
		Bind {e with
 				 exp_bind_body = label_exp e.exp_bind_body;
				 exp_bind_path_id  = nl;}
  | Break e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"break",[],e.exp_break_pos) ::!iast_label_table;
		Break{ e with exp_break_path_id = nl;}  
  | CallRecv e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"callRecv",[],e.exp_call_recv_pos) ::!iast_label_table;
		CallRecv {e with
					  exp_call_recv_receiver = label_exp e.exp_call_recv_receiver;
					  exp_call_recv_arguments  = List.map label_exp e.exp_call_recv_arguments;
					  exp_call_recv_path_id = nl;}
  | CallNRecv e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"callNRecv",[],e.exp_call_nrecv_pos) ::!iast_label_table;
		CallNRecv { e with 
			exp_call_nrecv_arguments =  List.map label_exp e.exp_call_nrecv_arguments;
			exp_call_nrecv_path_id = nl;}
  | Cond e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"cond",[(nl,0);(nl,1)],e.exp_cond_pos) ::!iast_label_table;
		Cond {e with 
			exp_cond_condition = label_exp e.exp_cond_condition;
			exp_cond_then_arm  = Label ((nl,0),(label_exp e.exp_cond_then_arm));
			exp_cond_else_arm  = Label ((nl,1),(label_exp e.exp_cond_else_arm));
			exp_cond_path_id =nl;}
  | Continue e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"continue",[],e.exp_continue_pos) ::!iast_label_table;
		Continue {e with  exp_continue_path_id = nl;}
  | Member e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"member",[],e.exp_member_pos) ::!iast_label_table;
		Member {e with
			exp_member_base = label_exp e.exp_member_base;
			exp_member_path_id = nl;}  
  | Raise e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"raise",[],e.exp_raise_pos) ::!iast_label_table;
		Raise {e with
		exp_raise_val = 
			(match e.exp_raise_val with 
				| None -> None 
				| Some s-> Some (label_exp s));
		exp_raise_path_id = nl;}  
  | Return e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"return",[],e.exp_return_pos) ::!iast_label_table;
		Return{ e with
			exp_return_val = (match e.exp_return_val with | None -> None | Some s-> Some (label_exp s));
			exp_return_path_id = nl;}  
  | Try e -> 
		let nl = fresh_branch_point_id "" in
		let rec lbl_list_constr n = if n==0 then [] else (nl,n)::(lbl_list_constr (n-1)) in
		iast_label_table:= (nl,"try",(lbl_list_constr (List.length e.exp_catch_clauses)),e.exp_try_pos)::!iast_label_table;
		let lbl_c n d = 
			let d = get_catch_of_exp d in
			Catch {d with	exp_catch_body = Label((nl,n),label_exp d.exp_catch_body);} in
		Try {e with
				exp_try_block = label_exp e.exp_try_block;
				exp_try_path_id = nl;
				exp_catch_clauses  = (fst (List.fold_left (fun (a,c) d-> ((lbl_c c d)::a, c+1)) ([],0) e.exp_catch_clauses));
				exp_finally_clause = List.map label_exp e.exp_finally_clause;}
  | Unary e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"unary",[],e.exp_unary_pos) ::!iast_label_table;
		Unary{ e with
			exp_unary_exp = label_exp e.exp_unary_exp;
			exp_unary_path_id = fresh_branch_point_id "";}  		
  | While e -> 
		let nl = fresh_branch_point_id "" in
		iast_label_table:= (nl,"while",[],e.exp_while_pos) ::!iast_label_table;
		While {e with
			exp_while_condition = label_exp e.exp_while_condition;
			exp_while_body = label_exp e.exp_while_body;
			exp_while_path_id = nl;
			exp_while_wrappings = match e.exp_while_wrappings with | None -> None | Some s-> Some (label_exp s);}  
*)
	
let label_proc keep proc = {proc with 
 proc_is_main = if keep then proc.proc_is_main else false;
	proc_body = 
		match proc.proc_body with  
			| None -> None 
			| Some s -> Some (label_exp s);}

let label_procs_prog prog keep = {prog with
	prog_data_decls = List.map (fun c->{ c with data_methods = List.map (label_proc keep) c.data_methods}) prog.prog_data_decls;	
	prog_proc_decls = List.map (label_proc keep) prog.prog_proc_decls;
	}
(************************************************************************************
 * Use to support pragma declaration in system
 *   - Remove duplicated Obj/Class, such as Object and String which are
 *   automatically generated when translating Iast to Cast.
 *   - Append all primitives in many seperated prelude files.
 ************************************************************************************)

(* Use to remove to duplicated Obj/Class when translating many header files along with source program *)
let rec remove_dup_obj (defs : data_decl list) : data_decl list=
        match defs with
        | [] -> []
        | head::tail ->
                if (List.mem head tail && (head.data_name = "Object" ||
                head.data_name = "String")) then
                        remove_dup_obj tail
                else head::remove_dup_obj tail

(* Append two prog_decl list *)
let rec append_iprims_list (iprims : prog_decl) (iprims_list : prog_decl list) : prog_decl =
  match iprims_list with
  | [] -> iprims
  | hd::tl ->
        let new_iprims = {
					      prog_include_decls = hd.prog_include_decls @ iprims.prog_include_decls;
                prog_data_decls = hd.prog_data_decls @ iprims.prog_data_decls;
                prog_logical_var_decls = hd.prog_logical_var_decls @ iprims.prog_logical_var_decls;
                prog_global_var_decls = hd.prog_global_var_decls @ iprims.prog_global_var_decls;
                prog_enum_decls = hd.prog_enum_decls @ iprims.prog_enum_decls;
                prog_view_decls = hd.prog_view_decls @ iprims.prog_view_decls;
                prog_func_decls = hd.prog_func_decls @ iprims.prog_func_decls;
                prog_rel_decls = hd.prog_rel_decls @ iprims.prog_rel_decls; (* An Hoa *)
                prog_rel_ids = hd.prog_rel_ids @ iprims.prog_rel_ids; (* An Hoa *)
                prog_hp_decls = hd.prog_hp_decls @ iprims.prog_hp_decls;
                prog_hp_ids = hd.prog_hp_ids @ iprims.prog_hp_ids; 
                prog_axiom_decls = hd.prog_axiom_decls @ iprims.prog_axiom_decls; (* [4/10/2011] An Hoa *)
                prog_hopred_decls = hd.prog_hopred_decls @ iprims.prog_hopred_decls;
                prog_proc_decls = hd.prog_proc_decls @  iprims.prog_proc_decls;
                prog_coercion_decls = hd.prog_coercion_decls @  iprims.prog_coercion_decls;
				prog_barrier_decls = hd.prog_barrier_decls @ iprims.prog_barrier_decls;
				} in
             append_iprims_list new_iprims tl

let append_iprims_list_head (iprims_list : prog_decl list) : prog_decl =
  match iprims_list with
  | [] ->
        let new_prims = {
					      prog_include_decls = [];
                prog_data_decls = [];
                prog_global_var_decls = [];
                prog_logical_var_decls = [];
                prog_enum_decls = [];
                prog_view_decls = [];
                prog_func_decls = [];
                prog_rel_decls = [];
                prog_rel_ids = [];
                prog_hp_decls = [];
                prog_hp_ids = [];
                prog_axiom_decls = [];
                prog_hopred_decls = [];
                prog_proc_decls = [];
                prog_coercion_decls = [];
				prog_barrier_decls = [];}
        in new_prims
  | hd::tl -> append_iprims_list hd tl

(**
 * An Hoa : Find the field with field_name of compound data structure with name data_name
 **)
let get_field_from_typ ddefs data_typ field_name = match data_typ with
	| Named data_name -> 
       (* let _ = print_endline ("1: " ^ data_name) in *)
       (* let _ = print_endline ("2: " ^ field_name) in *)
		let ddef = look_up_data_def_raw ddefs data_name in
        (try
		let field = List.find (fun x -> (get_field_name x = field_name)) ddef.data_fields in
       (* let _ = print_endline ("3: " ^ (snd (fst3 field))) in*)
		field
         with _ -> Err.report_error { Err.error_loc = no_pos; Err.error_text = ("field name " ^ field_name ^ " is not found");}
        )
	| _ -> failwith ((string_of_typ data_typ) ^ " is not a compound data type.")


(**
 * An Hoa : Find the type of the field with indicated name in ddef
 **)
let get_type_of_field ddef field_name =
	let tids = List.map get_field_typed_id ddef.data_fields in
	try
		let field_typed_id = List.find (fun x -> (snd x = field_name)) tids in
			fst field_typed_id
	with
		| Not_found -> UNK


(**
 * An Hoa : Traversal a list of access to get the type.
 **)
let rec get_type_of_field_seq ddefs root_type field_seq =
	(* let _ = print_endline ("[get_type_of_field_seq] : input = { " ^ (string_of_typ root_type) ^ " , [" ^ (String.concat "," field_seq) ^ "] }") in *)
	match field_seq with
		| [] -> root_type
		| f::t -> (match root_type with
			| Named c -> (try
					let ddef = look_up_data_def_raw ddefs c in
					let ft = get_type_of_field ddef f in
						(match ft with
							| UNK -> Err.report_error { Err.error_loc = no_pos; Err.error_text = "[get_type_of_field_seq] Compound type " ^ c ^ " has no field " ^ f ^ "!" }
							| _ -> get_type_of_field_seq ddefs ft t)
				with
					| Not_found -> Err.report_error { Err.error_loc = no_pos; Err.error_text = "[get_type_of_field_seq] Either data type " ^ c ^ " cannot be found!" })
			| _ -> Err.report_error { Err.error_loc = no_pos; Err.error_text = "[get_type_of_field_seq] " ^ (string_of_typ root_type) ^ " is not a compound type!" })


(**
 * An Hoa : Check if an identifier is a name for some data type
 **)
let is_data_type_identifier (ddefs : data_decl list) id =
	List.exists (fun x -> x.data_name = id) ddefs


(**
 * An Hoa : Check if an identifier is NOT a name for some data type
 **)
let is_not_data_type_identifier (ddefs : data_decl list) id =
	not (is_data_type_identifier ddefs id)

(**
 * An Hoa : Compute the size of a typ in memory.
 *          Each primitive type count 1 while compound data type is the sum of
 *          its component. Inline types should be expanded.
 **)
let rec compute_typ_size ddefs t = 
	(* let _ = print_endline ("[compute_typ_size] input = " ^ (string_of_typ t)) in *)
	let res = match t with
		| Named data_name -> (try 
				let ddef = look_up_data_def_raw ddefs data_name in
					List.fold_left (fun a f -> 
						let fs = if (is_inline_field f) then 
							compute_typ_size ddefs (get_field_typ f) 
						else 1 in a + fs) 0 ddef.data_fields
			with | Not_found -> Err.report_error { Err.error_loc = no_pos; Err.error_text = "[compute_typ_size] input type does not exist."})
		| _ -> 1 in
	(* let _ = print_endline ("[compute_typ_size] output = " ^ (string_of_int res)) in *)
		res


(**
 * An Hoa : Get the number of pointers by looking up the corresponding record 
 *          in data_dec instead of doing the full recursive computation. This
 *          caching of information is to reduce the workload.
 **)
let get_typ_size = compute_typ_size

(**
 * An Hoa : Compute the offset of the pointer to a field with respect to the root.
 **)
let rec compute_field_offset ddefs data_name accessed_field =
	try 
		(* let _ = print_endline ("[compute_field_offset] input = { " ^ data_name ^ " , " ^ accessed_field ^ " }") in *)
		let found = ref false in
		let ddef = look_up_data_def_raw ddefs data_name in
		(* Accumulate the offset along the way *)
		let offset = List.fold_left (fun a f -> 
										if (!found) then a (* Once found, just keep constant*)
										else let fn = get_field_name f in 
											let ft = get_field_typ f in
											if (fn = accessed_field) then (* Found the field *)
												begin found := true; a end
											else if (is_inline_field f) then (* Accumulate *)
												a + (get_typ_size ddefs ft)
											else a + 1)
									0 ddef.data_fields in
		(* The field is not really a field of the data type ==> raise error. *)
		if (not !found) then 
			Err.report_error { Err.error_loc = no_pos; Err.error_text = "[compute_field_offset] " ^ "The data type " ^ data_name ^ " does not have field " ^ accessed_field }
		else 
			(* let _ = print_endline ("[compute_field_offset] output = " ^ (string_of_int offset)) in *)
				offset
	with
		| Not_found -> Err.report_error { Err.error_loc = no_pos; Err.error_text = "[compute_field_offset] is call with non-existing data type." }


(**
 * An Hoa : Compute the offset of the pointer indicated by a field sequence with
 *          respect to the root (that points to a type with name data_name)
 **)
and compute_field_seq_offset ddefs data_name field_sequence = 
	(* let _ = print_endline ("[compute_field_seq_offset] input = { " ^ data_name ^ " , [" ^ (String.concat "," field_sequence) ^ "] }") in *)
	let dname = ref data_name in
	let res = 
		List.fold_left (fun a field_name ->
							let offset = compute_field_offset ddefs !dname field_name in
							(* Update the dname to the data type of the field_name *)
							try
								let ddef = look_up_data_def_raw ddefs !dname in
								let field_type = get_type_of_field ddef field_name in
								begin
									dname := string_of_typ field_type;
									a + offset
								end
							with
								| Not_found -> Err.report_error { Err.error_loc = no_pos; Err.error_text = "[compute_field_seq_offset]: " ^ !dname ^ " does not exists!" } )
						0 field_sequence in
	(* let _ = print_endline ("[compute_field_seq_offset] output = { " ^ (string_of_int res) ^ " }") in *)
		res

let b_data_constr bn larg=
	if bn = b_datan || (snd (List.hd larg))="state" then		
		{ data_name = bn;
                data_pos = no_pos;
		  data_fields = List.map (fun c-> c,no_pos,false,F_NO_ANN) larg ;
		  data_parent_name = if bn = b_datan then "Object" else b_datan;
		  data_invs =[];
          data_is_template = false;
		  data_methods =[]; }
	else report_error no_pos ("the first field of barrier "^bn^" is not state")
	
	
let add_bar_inits prog = 
  let b_data_def = (b_data_constr b_datan []) :: 
	(List.map (fun c-> b_data_constr c.barrier_name c.barrier_shared_vars) prog.prog_barrier_decls) in
	
  let b_proc_def = List.map (fun b-> 
			let largs = (*(P.IConst (0,no_pos))::*)List.map (fun (_,n)-> 
			(*print_string (n^"\n"); *)
			P.Var ((n,Unprimed),no_pos)) b.barrier_shared_vars in
			let pre_hn = 
				F.mkHeapNode ("b",Unprimed) b_datan 0 false (P.ConstAnn(Mutable)) false false false None [] [] None no_pos in
			let pre = F.formula_of_heap_with_flow pre_hn n_flow no_pos in 
			let post_hn = 
				F.mkHeapNode ("b",Unprimed) b.barrier_name 0 false (P.ConstAnn(Mutable)) false false false None largs [] None no_pos in
			let post =  
				let simp = F.formula_of_heap_with_flow post_hn n_flow no_pos in
				let str = F.mkEBase [] [] [] simp None no_pos in
				F.mkEAssume simp str (fresh_formula_label "") None in
			(*let _ =print_string ("post: "^(!print_struc_formula post)^"\n") in*)
			{ proc_name = "init_"^b.barrier_name;
                          proc_source = "source_file";
			  proc_flags = [];
			  proc_mingled_name = "";
			  proc_data_decl = None ;
			  proc_hp_decls = [];
			  proc_constructor = false;
			  proc_args = {param_type =barrierT; param_name = "b"; param_mod = RefMod;param_loc=no_pos}::
				(List.map (fun (t,n)-> {param_type =t; param_name = n; param_mod = NoMod;param_loc=no_pos})
								b.barrier_shared_vars);
			  proc_return = Void;
			  proc_static_specs = F.mkEBase [] [] [] pre (Some post) no_pos;
			  proc_dynamic_specs = F.mkEFalseF ();
			  proc_exceptions = [];
			  proc_body = None;
			  proc_is_main = false;
			  proc_file = "";
			  proc_loc = no_pos;
			proc_test_comps = None}) prog.prog_barrier_decls in
 {prog with 
	prog_data_decls = prog.prog_data_decls@b_data_def; 
	prog_proc_decls = prog.prog_proc_decls@b_proc_def; }

let mk_lemma lemma_name coer_type ihps ihead ibody=
  { coercion_type = coer_type;
  coercion_exact = false;
  coercion_infer_vars = ihps;
  coercion_name = (lemma_name);
  coercion_head = (F.subst_stub_flow F.top_flow ihead);
  coercion_body = (F.subst_stub_flow F.top_flow ibody);
  coercion_proof = Return ({ exp_return_val = None;
  exp_return_path_id = None ;
  exp_return_pos = no_pos })}

let gen_normalize_lemma_comb ddef = 
 let self = (self,Unprimed) in
 let lem_name = "c"^ddef.data_name in
 let gennode perm hl= F.mkHeapNode self ddef.data_name 0 false (P.ConstAnn Mutable) false false false (Some perm) hl [] None no_pos in
 let fresh () = P.Var ((P.fresh_old_name lem_name,Unprimed),no_pos) in
 let perm1,perm2,perm3 = fresh (), fresh (), fresh () in
 let args1,args2 = List.split (List.map (fun _-> fresh () ,fresh ()) ddef.data_fields) in
 let pure = List.fold_left2 (fun a c1 c2 -> P.And (a,P.BForm ((P.Eq (c1,c2,no_pos),None),None), no_pos)) (P.BForm ((P.Eq (perm3,P.Add (perm1,perm2,no_pos),no_pos),None),None)) args1 args2 in
 {coercion_type = Left;
  coercion_name = lem_name;
  coercion_exact = false;
  coercion_infer_vars = [];
  coercion_head = F.formula_of_heap_1 (F.mkStar (gennode perm1 args1) (gennode perm2 args2) no_pos) no_pos;
  coercion_body = F. mkBase (gennode perm3 args1) pure  top_flow [] no_pos;
  coercion_proof =  Return { exp_return_val = None; exp_return_path_id = None ; exp_return_pos = no_pos }
 }
 
 let gen_normalize_lemma_split ddef = 
 let self = (self,Unprimed) in
 let lem_name = "s"^ddef.data_name in
 let gennode perm hl= F.mkHeapNode self ddef.data_name 0 false (P.ConstAnn Mutable) false false false (Some perm) hl [] None no_pos in
 let fresh () = P.Var ((P.fresh_old_name lem_name,Unprimed),no_pos) in
 let perm1,perm2,perm3 = fresh (), fresh (), fresh () in
 let args = List.map (fun _-> fresh ()) ddef.data_fields in
 let pure = P.BForm ((P.Eq (perm3,P.Add (perm1,perm2,no_pos),no_pos),None),None) in
 {coercion_type = Left;
  coercion_name = lem_name;
  coercion_exact = false;
  coercion_infer_vars = [];
  coercion_head = F.mkBase (gennode perm3 args) pure  top_flow [] no_pos;
  coercion_body = F.formula_of_heap_1 (F.mkStar (gennode perm1 args) (gennode perm2 args) no_pos) no_pos;
  
  coercion_proof =  Return { exp_return_val = None; exp_return_path_id = None ; exp_return_pos = no_pos }
 }
	
let add_normalize_lemmas prog4 = 
	if !perm = NoPerm || not !enable_split_lemma_gen then prog4
	else {prog4 with prog_coercion_decls =
                let new_lems =  List.fold_left(fun a c-> (gen_normalize_lemma_split c)::(gen_normalize_lemma_comb c)::a) [] prog4.prog_data_decls in
                let new_lst  = 
                  { coercion_list_elems = new_lems;
                    coercion_list_kind  = LEM;} in
                new_lst::prog4.prog_coercion_decls
        }

let rec get_breaks e = 
	let f e = match e with
		| Raise {exp_raise_type = rt}-> (match rt with
			| Const_flow fl -> if (is_subsume_flow (exlist # get_hash brk_top) (exlist # get_hash fl)) then Some [fl]
								else Some []
			| Var_flow _ -> Some [])
		| Try { exp_try_block = body;
				exp_catch_clauses = cl} ->
				let lb = get_breaks body in
				let lb = List.filter (fun l -> not (List.exists (fun c-> match c with | Catch c-> (String.compare c.exp_catch_flow_type l) == 0 | _-> false) cl)) lb in
				let lbc = List.map get_breaks cl in
				Some (List.concat (lb::lbc))
		| _ -> None in
	fold_exp e f (List.concat) [] 

let exists_return_x e0=
  let rec helper e=
    (* let _ = Debug.info_zprint (lazy  (" helper: " ^ (!print_exp e)  )) no_pos in *)
    match e with
      | Block { exp_block_body = bb} ->
          (* let _ = Debug.info_pprint (" BLOCK" ) no_pos in *)
          helper bb
      | Cond {exp_cond_then_arm = tb; exp_cond_else_arm=eb} ->
          (* let _ = Debug.info_pprint (" COND" ) no_pos in *)
          (helper tb) || (helper eb)
      | Raise {exp_raise_type = et} -> begin
          (* let _ = Debug.info_pprint (" RAISE" ) no_pos in *)
          match et with
            | Const_flow f ->
                (* let _ = Debug.info_zprint (lazy  (" et" ^ ( f))) no_pos in *)
                if (is_eq_flow  (exlist # get_hash loop_ret_flow) (exlist # get_hash f)) then true else false
            | _ -> false
      end
      | Return _ ->
          true
      | Seq {exp_seq_exp1 = e1; exp_seq_exp2 = e2} ->
          (helper e2) || (helper e1)
      | While {exp_while_body = wb} ->
          (* let _ = Debug.info_pprint (" WHILE" ) no_pos in *)
          helper wb
      (* | Bind _ -> let _ = Debug.info_pprint (" BIND" ) no_pos in false *)
      (* | Assign _ -> let _ = Debug.info_pprint (" ASS" ) no_pos in false *)
      (* | Var _ -> let _ = Debug.info_pprint (" VAR" ) no_pos in false *)
      | Label (_, el) -> (* let _ = Debug.info_pprint (" LABEL" ) no_pos in *)
                         helper el
      | _ ->
          (* let _ = Debug.info_pprint (" *****" ) no_pos in *)
          false
  in
  helper e0

let exists_return e0=
  let pr1 = !print_exp in
  Debug.no_1 "exists_return" pr1 string_of_bool
      (fun _ -> exists_return_x e0) e0

let exists_return_val_x e0=
  let rec helper e=
    (* let _ = Debug.info_zprint (lazy  (" helper: " ^ (!print_exp e)  )) no_pos in *)
    match e with
      | Block { exp_block_body = bb} ->
          (* let _ = Debug.info_pprint (" BLOCK" ) no_pos in *)
          helper bb
      | Cond {exp_cond_then_arm = tb; exp_cond_else_arm=eb} ->
          (* let _ = Debug.info_pprint (" COND" ) no_pos in *)
          (helper tb) || (helper eb)
      | Raise {exp_raise_type = et} -> begin
          (* let _ = Debug.info_pprint (" RAISE" ) no_pos in *)
          match et with
            | Const_flow _ ->
                (* let _ = Debug.info_zprint (lazy  (" et" ^ ( f))) no_pos in *)
                false
            | _ -> true
      end
      | Return b ->(
          match b.exp_return_val with
            | None -> false
            | Some _ -> true
      )
      | Seq {exp_seq_exp1 = e1; exp_seq_exp2 = e2} ->
          (helper e2) || (helper e1)
      | While {exp_while_body = wb} ->
          (* let _ = Debug.info_pprint (" WHILE" ) no_pos in *)
          helper wb
      (* | Bind _ -> let _ = Debug.info_pprint (" BIND" ) no_pos in false *)
      (* | Assign _ -> let _ = Debug.info_pprint (" ASS" ) no_pos in false *)
      (* | Var _ -> let _ = Debug.info_pprint (" VAR" ) no_pos in false *)
      | Label (_, el) -> (* let _ = Debug.info_pprint (" LABEL" ) no_pos in *)
                         helper el
      | _ ->
          (* let _ = Debug.info_pprint (" *****" ) no_pos in *)
          false
  in
  helper e0

let exists_return_val e0=
  let pr1 = !print_exp in
  Debug.no_1 "exists_return_val" pr1 string_of_bool
      (fun _ -> exists_return_val_x e0) e0

let get_return_exp_x e0=
  let rec helper e=
    (* let _ = Debug.info_zprint (lazy  (" helper: " ^ (!print_exp e)  )) no_pos in *)
    match e with
      | Block { exp_block_body = bb} ->
          (* let _ = Debug.info_pprint (" BLOCK" ) no_pos in *)
          helper bb
      | Cond {exp_cond_then_arm = tb; exp_cond_else_arm=eb} -> begin
          (* let _ = Debug.info_pprint (" COND" ) no_pos in *)
          let r = (helper tb) in
          match r with
            | None ->  (helper eb)
            | Some _ -> r
      end
      | Raise {exp_raise_type = et} -> None
      | Return b -> b.exp_return_val
      | Seq {exp_seq_exp1 = e1; exp_seq_exp2 = e2} ->(
          let r = (helper e1) in
          match r with
            | None -> (helper e2)
            | Some _ -> r
      )
      | While {exp_while_body = wb} ->
          helper wb
      | Label (_, el) -> (* let _ = Debug.info_pprint (" LABEL" ) no_pos in *)
                         helper el
      | _ -> None
  in
  helper e0

let get_return_exp e0=
  let pr1 = !print_exp in
  let pr2 oe=
    match oe with
      | None -> "none"
      | Some e -> pr1 e
  in
  Debug.no_1 "get_return_exp" pr1 pr2
      (fun _ -> get_return_exp_x e0) e0

let trans_to_exp_form exp0=
  let rec helper exp=
    match exp with
      | Var v -> P.Var ((v.exp_var_name, Primed), v.exp_var_pos)
      | IntLit i -> P.IConst (i.exp_int_lit_val, i.exp_int_lit_pos)
      | _ -> report_error no_pos "iast.trans_exp_to_form: not handle yet"
  in
  helper exp0

let lbl_getter prog vn id = 
  try 
	let vd = look_up_view_def_raw 15 prog.prog_view_decls vn in
	let vl, v_has_l = vd.view_labels in
	if v_has_l then
	 try
	  Some (List.nth vl id )
	 with Failure _ -> report_error no_pos "lbl_getter, index out of range"
	else None
  with 
   | Not_found -> None 

let eq_coercion c1 c2 = (String.compare c1.coercion_name c2.coercion_name) == 0

let eq_coercion_list = (==)             (* to be modified *)

let annot_args_getter_all prog vn: (P.ann * int) list =
  try 
    let vd = look_up_view_def_raw 18 prog.prog_view_decls vn in
    vd.view_imm_map
  with 
    | Not_found -> [] 

let annot_args_getter prog vn =
  List.filter (fun (_,p) -> (p != 0) ) (annot_args_getter_all prog vn)
