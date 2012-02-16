open Globals
module DD = Debug
open Gen
open Exc.GTable
open Perm
open Cformula
open Context
open Cpure
open Global_var

module Err = Error
module CP = Cpure
module MCP = Mcpure
module CF = Cformula
module TP = Tpdispatcher

(* let keep_dist f = match f with *)
(*   | BForm ((Eq(e1,e2,_),_),_) -> not(eqExp_f eq_spec_var e1 e2) *)
(*   | _ -> true *)

(* (\* TODO Cristina : can remove duplicates too ; *)
(*    remove x=x*\) *)
(* let simplify_conjs f = *)
(*   let ls = split_conjunctions f in *)
(*   let ls = List.filter keep_dist ls in *)
(*   join_conjunctions ls *)

let keep_dist f = match f with
  | BForm ((Eq(e1,e2,_),_),_) ->  not((eqExp_f eq_spec_var e1 e2) || (is_null e1 && (is_null_const_exp e2)) || ((is_null_const_exp e1) && is_null e2)) 
			(* | Or(f1, f2, lb, l) -> let _ = print_string("cris: f_or = " ^ (!CP.print_formula f) ^ "\n") in true *)
  | _ -> true

(* TODO Cristina : can remove duplicates too ; remove x=x*)
(* let rec simplify_disj_list conjl = *)
(*   let simpl_conjl = List.map *)
(*     (fun x-> *)
(*       let disjl = split_disjunctions x in *)
(*       let simpl_disjl = List.map (fun x-> simplify_conjs x) disjl in *)
(*       join_disjunctions simpl_disjl) conjl *)
(*   in *)
(*   simpl_conjl *)
let simplify_conjs f =
  let ls = split_conjunctions f in
  let ls = List.map (simplify_disj_new) ls in
  let ls = List.concat (List.map (split_conjunctions) ls) in
			(* remove x=x *)
  let ls = List.filter keep_dist ls in
			(* remove duplicated conjuncts *)
  let ls = remove_dupl_conj_eq ls in
			(* remove x=x inside inner disjuncts *)
			(* let ls = simplify_disj_list ls in *)
  join_conjunctions ls

let simplify_conjs f =
  Debug.no_1 "simplify_conjs" (!CP.print_formula) (!CP.print_formula) simplify_conjs f 

let simp_lhs_rhs vars (c,lhs,rhs) =
  let ra = MCP.pure_ptr_equations lhs in
  let (subs,rest) = CP.simplify_subs ra vars [] in
  let nsubs = CP.norm_subs (rest@subs) in
  let asubs = rest@nsubs in	  
  let n_rhs = (CP.subst asubs rhs) in
  let lhs = (CP.subst asubs lhs) in
  let lhs = simplify_conjs lhs in
  let n_lhs = CP.filter_ante lhs n_rhs in
  (c,n_lhs,n_rhs)



let no_infer estate = (estate.es_infer_vars == [])

let no_infer_rel estate = (estate.es_infer_vars_rel == [])

let no_infer_all estate = (estate.es_infer_vars == [] && estate.es_infer_vars_rel == [])
  
let remove_infer_vars_all estate =
  let iv = estate.es_infer_vars in
  ({estate with es_infer_vars=[];}, iv) 

let remove_infer_vars_partial estate rt =
  let iv = estate.es_infer_vars in
  if (iv==[]) then (estate,iv)
  else ({estate with es_infer_vars=CP.diff_svl iv rt;}, iv) 

let remove_infer_vars_partial estate rt =
  let pr1 = !print_entail_state in
  let pr2 = !print_svl in
  Debug.no_2 "remove_infer_vars_partial" pr1 pr2 (pr_pair pr1 pr2) 
      remove_infer_vars_partial estate rt 

let rec remove_infer_vars_all_ctx ctx =
  match ctx with
    | Ctx estate -> 
          let (es,_) = remove_infer_vars_all estate in
          Ctx es
    | OCtx (ctx1, ctx2) -> OCtx (remove_infer_vars_all_ctx ctx1, remove_infer_vars_all_ctx ctx2)

let remove_infer_vars_all_partial_context (a,pc) = 
  (a,List.map (fun (b,c) -> (b,remove_infer_vars_all_ctx c)) pc)

let remove_infer_vars_all_list_context ctx = 
  match ctx with
    | FailCtx _ -> ctx
    | SuccCtx lst -> SuccCtx (List.map remove_infer_vars_all_ctx lst)

let remove_infer_vars_all_list_partial_context lpc = 
  List.map remove_infer_vars_all_partial_context lpc

(* let collect_pre_heap_list_partial_context (ctx:list_partial_context) = *)
(*   let r = List.map (fun (_,cl) -> List.concat (List.map (fun (_,c) -> collect_pre_heap c) cl))  ctx in *)
(*   List.concat r *)

let rec restore_infer_vars_ctx iv ctx = 
  match ctx with
  | Ctx estate -> 
        if iv==[] then ctx
        else Ctx {estate with es_infer_vars=iv;}
  | OCtx (ctx1, ctx2) -> OCtx (restore_infer_vars_ctx iv ctx1, restore_infer_vars_ctx iv ctx2)

let rec add_infer_vars_ctx iv ctx = 
  match ctx with
  | Ctx estate -> 
        if iv==[] then ctx
        else Ctx {estate with es_infer_vars = iv @ estate.es_infer_vars;}
  | OCtx (ctx1, ctx2) -> OCtx (add_infer_vars_ctx iv ctx1, add_infer_vars_ctx iv ctx2)

let add_impl_expl_vars_ctx iv ev ctx =
  let rec helper ctx = 
    match ctx with
      | Ctx estate -> Ctx {estate with es_gen_impl_vars = iv@estate.es_gen_impl_vars;
                                       es_gen_expl_vars = ev@estate.es_gen_expl_vars;}
      | OCtx (ctx1, ctx2) -> OCtx (helper ctx1, helper ctx2)
  in helper ctx

let add_impl_expl_vars_list_partial_context iv ev (ctx:list_partial_context) =
  List.map (fun (fl,bl) -> (fl, List.map (fun (t,b) -> (t,add_impl_expl_vars_ctx iv ev b)) bl)) ctx

let restore_infer_vars_list_partial_context iv (ctx:list_partial_context) =
  List.map (fun (fl,bl) -> (fl, List.map (fun (t,b) -> (t, restore_infer_vars_ctx iv b)) bl)) ctx

let restore_infer_vars iv cl =
  if (iv==[]) then cl
  else match cl with
    | FailCtx _ -> cl
    | SuccCtx lst -> SuccCtx (List.map (restore_infer_vars_ctx iv) lst)

let rec get_all_args alias_of_root heap = match heap with
  | ViewNode h -> h.h_formula_view_arguments
  | Star s -> (get_all_args alias_of_root s.h_formula_star_h1) @ (get_all_args alias_of_root s.h_formula_star_h2)
  | Conj c -> (get_all_args alias_of_root c.h_formula_conj_h1) @ (get_all_args alias_of_root c.h_formula_conj_h1)
  | Phase p -> (get_all_args alias_of_root p.h_formula_phase_rd) @ (get_all_args alias_of_root p.h_formula_phase_rw) 
  | _ -> []


let is_inferred_pre_list_context ctx = 
  match ctx with
  | FailCtx _ -> false
  | SuccCtx lst -> List.exists CF.is_inferred_pre_ctx lst

let is_inferred_pre_list_context ctx = 
  Debug.no_1 "is_inferred_pre_list_context"
      !print_list_context string_of_bool
      is_inferred_pre_list_context ctx

(* let rec is_inferred_pre_list_context = match ctx with *)
(*   | Ctx estate -> is_inferred_pre estate  *)
(*   | OCtx (ctx1, ctx2) -> (is_inferred_pre_ctx ctx1) || (is_inferred_pre_ctx ctx2) *)

let collect_pre_heap_list_context ctx = 
  match ctx with
  | FailCtx _ -> []
  | SuccCtx lst -> List.concat (List.map collect_pre_heap lst)

let collect_infer_vars_list_context ctx = 
  match ctx with
  | FailCtx _ -> []
  | SuccCtx lst -> List.concat (List.map collect_infer_vars lst)

let collect_formula_list_context ctx = 
  match ctx with
  | FailCtx _ -> []
  | SuccCtx lst -> List.concat (List.map collect_formula lst)

let collect_pre_heap_list_partial_context (ctx:list_partial_context) =
  let r = List.map (fun (_,cl) -> List.concat (List.map (fun (_,c) -> collect_pre_heap c) cl))  ctx in
  List.concat r

let collect_infer_vars_list_partial_context (ctx:list_partial_context) =
  let r = List.map (fun (_,cl) -> List.concat (List.map (fun (_,c) -> collect_infer_vars c) cl))  ctx in
  List.concat r

let collect_formula_list_partial_context (ctx:list_partial_context) =
  let r = List.map (fun (_,cl) -> List.concat (List.map (fun (_,c) -> collect_formula c) cl))  ctx in
  List.concat r

let collect_pre_pure_list_context ctx = 
  match ctx with
  | FailCtx _ -> []
  | SuccCtx lst -> List.concat (List.map collect_pre_pure lst)

let collect_pre_pure_list_partial_context (ctx:list_partial_context) =
  let r = List.map (fun (_,cl) -> List.concat (List.map (fun (_,c) -> collect_pre_pure c) cl))  ctx in
  List.concat r

let collect_rel_list_context ctx = 
  match ctx with
  | FailCtx _ -> []
  | SuccCtx lst -> List.concat (List.map collect_rel lst)

let collect_rel_list_partial_context (ctx:list_partial_context) =
  let r = List.map (fun (_,cl) -> List.concat (List.map (fun (_,c) -> collect_rel c) cl))  ctx in
  List.concat r

let collect_rel_list_partial_context (ctx:list_partial_context) =
  let pr1 = !CF.print_list_partial_context in
  let pr2 = pr_list print_lhs_rhs in
  Debug.no_1 "collect_rel_list_partial_context"  pr1 pr2
      collect_rel_list_partial_context ctx
 
let init_vars ctx infer_vars iv_rel orig_vars = 
  let rec helper ctx = 
    match ctx with
      | Ctx estate -> Ctx {estate with es_infer_vars = infer_vars; es_infer_vars_rel = iv_rel}
      | OCtx (ctx1, ctx2) -> OCtx (helper ctx1, helper ctx2)
  in helper ctx

(* let conv_infer_heap hs = *)
(*   let rec helper hs h = match hs with *)
(*     | [] -> h *)
(*     | x::xs ->  *)
(*       let acc =  *)
(* 	    Star({h_formula_star_h1 = x; *)
(* 	      h_formula_star_h2 = h; *)
(* 	      h_formula_star_pos = no_pos}) *)
(*         in helper xs acc in *)
(*   match hs with *)
(*     | [] -> HTrue  *)
(*     | x::xs -> helper xs x *)

(* let extract_pre_list_context x =  *)
(*   (\* TODO : this has to be implemented by extracting from es_infer_* *\) *)
(*   (\* print_endline (!print_list_context x); *\) *)
(*   None *)

let to_unprimed_data_root aset h =
  let r = h.h_formula_data_node in
  if CP.is_primed r then
    let alias = CP.EMapSV.find_equiv_all r aset in
    let alias = List.filter (CP.is_unprimed) alias in
    (match alias with
      | [] -> h
      | (ur::_) -> {h with h_formula_data_node = ur})
  else h

let to_unprimed_view_root aset h =
  let r = h.h_formula_view_node in
  if CP.is_primed r then
    let alias = CP.EMapSV.find_equiv_all r aset in
    let alias = List.filter (CP.is_unprimed) alias in
    (match alias with
      | [] -> h
      | ur::_ -> {h with h_formula_view_node = ur})
  else h

(* get exactly one root of h_formula *)
let get_args_h_formula aset (h:h_formula) =
  let av = CP.fresh_spec_var_ann () in
  match h with
    | DataNode h -> 
          let h = to_unprimed_data_root aset h in
          let root = h.h_formula_data_node in
          let arg = h.h_formula_data_arguments in
          let new_arg = CP.fresh_spec_vars_prefix "inf" arg in
          if (!Globals.allow_imm) then
            Some (root, arg,new_arg, [av],
            DataNode {h with h_formula_data_arguments=new_arg;
              h_formula_data_imm = mkPolyAnn av})
          else
            Some (root, arg,new_arg, [],
            DataNode {h with h_formula_data_arguments=new_arg})
    | ViewNode h -> 
          let h = to_unprimed_view_root aset h in
          let root = h.h_formula_view_node in
          let arg = h.h_formula_view_arguments in
          let new_arg = CP.fresh_spec_vars_prefix "inf" arg in
          if (!Globals.allow_imm) then
            Some (root, arg,new_arg, [av],
            ViewNode {h with h_formula_view_arguments=new_arg; 
              h_formula_view_imm = mkPolyAnn av} )
          else
            Some (root, arg,new_arg, [],
            ViewNode {h with h_formula_view_arguments=new_arg})
    | _ -> None

(*

  Cformula.h_formula ->
  (Cformula.CP.spec_var * Cformula.CP.spec_var list * CP.spec_var list *
   CP.spec_var list * Cformula.h_formula)
  option

*)

let get_args_h_formula aset (h:h_formula) =
  let pr1 = !print_h_formula in
  let pr2 = pr_option (pr_penta !print_sv !print_svl !print_svl !print_svl pr1) in
  Debug.no_1 "get_args_h_formula" pr1 pr2 (fun _ -> get_args_h_formula aset h) h

let get_alias_formula (f:CF.formula) =
  let (h, p, fl, b, t) = split_components f in
  let eqns = (MCP.ptr_equations_without_null p) in
  eqns

(* let get_alias_formula (f:CF.formula) = *)
(*   Debug.no_1 "get_alias_formula" !print_formula !print_pure_f get_alias_formula f *)

let build_var_aset lst = CP.EMapSV.build_eset lst

let is_elem_of conj conjs =
 (* let filtered = List.filter (fun c -> TP.imply_raw conj c && TP.imply_raw c conj) conjs in *)
  let filtered = List.filter (fun c -> CP.equalFormula conj c) conjs in
  match filtered with
    | [] -> false
    | _ -> true

let is_elem_of conj conjs = 
  let pr = !CP.print_formula in
  Debug.no_1 "is_elem_of" pr pr_no (fun _ -> is_elem_of conj conjs) conj

            (* (b,args,inf_arg,h,new_iv,over_iv,[orig_r]) in *)
            (* (List.exists (CP.eq_spec_var_aset lhs_aset r) *)
            (*    iv,args,inf_arg,h,new_iv,over_iv,[r]) in *)
            (* let args_al = List.map (fun v -> CP.EMapSV.find_equiv_all v rhs_aset) args in *)
(* (\* let _ = print_endline ("LHS aliases: "^(pr_list (pr_pair !print_sv !print_sv) lhs_als)) in *\) *)
(* (\* let _ = print_endline ("RHS aliases: "^(pr_list (pr_pair !print_sv !print_sv) rhs_als)) in *\) *)
(* let _ = print_endline ("root: "^(pr_option (fun (r,_,_,_) -> !print_sv r) rt)) in *)
(* let _ = print_endline ("rhs node: "^(!print_h_formula rhs)) in *)
(* let _ = print_endline ("renamed rhs node: "^(!print_h_formula new_h)) in *)
(* (\* let _ = print_endline ("heap args: "^(!print_svl args)) in *\) *)
(* (\* let _ = print_endline ("heap inf args: "^(!print_svl inf_vars)) in *\) *)
(* (\* let _ = print_endline ("heap arg aliases: "^(pr_list !print_svl args_al)) in *\) *)
(* let _ = print_endline ("root in iv: "^(string_of_bool b)) in *)
(* (\* let _ = print_endline ("RHS exist vars: "^(!print_svl es.es_evars)) in *\) *)
(* (\* let _ = print_endline ("RHS impl vars: "^(!print_svl es.es_gen_impl_vars)) in *\) *)
(* (\* let _ = print_endline ("RHS expl vars: "^(!print_svl es.es_gen_expl_vars)) in *\) *)
(* (\* let _ = print_endline ("imm pure stack: "^(pr_list !print_mix_formula es.es_imm_pure_stk)) in *\) *)

(* let aux_test () = *)
(*       DD.trace_pprint "hello" no_pos *)
(* let aux_test () = *)
(*       Debug.no_1_loop "aux_test" pr_no pr_no aux_test () *)
(* let aux_test2 () = *)
(*       DD.trace_pprint "hello" no_pos *)
(* let aux_test2 () = *)
(*       Debug.no_1_num 13 "aux_test2" pr_no pr_no aux_test2 () *)

let infer_heap_nodes (es:entail_state) (rhs:h_formula) rhs_rest conseq pos = 
  if no_infer es then None
  else 
    let iv = es.es_infer_vars in
    let dead_iv = es.es_infer_vars_dead in
    let lhs_als = get_alias_formula es.es_formula in
    let lhs_aset = build_var_aset lhs_als in
    let rt = get_args_h_formula lhs_aset rhs in
    (* let _ = aux_test() in *)
    (* let _ = aux_test2() in *)
    (*  let rhs_als = get_alias_formula conseq in *)
    (*  let rhs_aset = build_var_aset rhs_als in *) 
    match rt with 
      | None -> None
      | Some (orig_r,args,inf_arg,inf_av,inf_rhs) -> 
            (* let (b,args,inf_vars,new_h,new_iv,iv_alias,r) = match rt with (\* is rt captured by iv *\) *)
            (*   | None -> (false,[],[],HTrue,iv,[],[]) *)
            (*   | Some (orig_r,args,inf_arg,inf_av,h) ->  *)
            let alias = CP.EMapSV.find_equiv_all orig_r lhs_aset in
            let rt_al = [orig_r]@alias in (* set of alias with root of rhs *)
            let over_dead = CP.intersect dead_iv rt_al in
            let iv_alias = CP.intersect iv rt_al in 
            let b = (over_dead!=[] || iv_alias == []) in (* does alias of root intersect with iv? *)
            (* let new_iv = (CP.diff_svl (inf_arg@iv) rt_al) in *)
            (* let alias = if List.mem orig_r iv then [] else alias in *)
            if b then None
            else 
              begin
                let new_iv = inf_av@inf_arg@iv in
                (* Take the alias as the inferred pure *)
                (* let iv_al = CP.intersect iv iv_alias in (\* All relevant vars of interest *\) *)
                (* let iv_al = CP.diff_svl iv_al r in *)
                (* iv_alias certainly has one element *)
                let new_r = List.hd iv_alias in
                (* each heap node may only be instantiated once *)
                (* let new_iv = diff_svl new_iv [new_r] in *)
                (* above cause incompleteness in 3.slk (29) & (30). *)
                let new_h = 
                  if CP.eq_spec_var orig_r new_r 
                  then inf_rhs
                  else 
                    (* replace with new root name *)
                    set_node_var new_r inf_rhs 
                in
                (* let _ = print_endline ("iv_alias:"^(!CP.print_svl iv_alias)) in *)
                (* let _ = print_endline ("orig root:"^(!CP.print_sv orig_r)) in *)
                (* let _ = print_endline ("new root:"^(!CP.print_sv new_r)) in *)
                (* let _ = print_endline ("new hform:"^(!print_h_formula new_h)) in *)
                (* we do not need to add lhs_root=iv into the inf_pure as info is in LHS*)
                (* let new_p = List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 no_pos) (CP.mkTrue no_pos)  *)
                (*   (List.map (fun a -> CP.BForm (CP.mkEq_b (CP.mkVar a no_pos) r no_pos, None)) iv_al) in *)
                (* let new_p = (CP.mkTrue no_pos) in *)
                let lhs_h,_,_,_,_ = CF.split_components es.es_formula in
                (* why is orig_ante being used?????? *)
                (* let _,ante_pure,_,_,_ = CF.split_components es.es_orig_ante in *)
                (* let ante_conjs = CP.list_of_conjs (MCP.pure_of_mix ante_pure) in *)
                (* let new_p_conjs = CP.list_of_conjs new_p in *)
                (* let new_p = List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 no_pos) (CP.mkTrue no_pos) *)
                (*   (List.filter (fun c -> not (is_elem_of c ante_conjs)) new_p_conjs) in *)
                DD.devel_pprint ">>>>>> infer_heap_nodes <<<<<<" pos;
                DD.devel_hprint (add_str "unmatch RHS : " !print_h_formula) rhs pos;
                DD.devel_hprint (add_str "orig inf vars : " !print_svl) iv pos;
                DD.devel_hprint (add_str "inf LHS heap:" !print_h_formula) new_h pos;
                DD.devel_hprint (add_str "new inf vars: " !print_svl) new_iv pos;
                DD.devel_hprint (add_str "dead inf vars: " !print_svl) iv_alias pos;
                (* DD.devel_hprint (add_str "new pure add: " !CP.print_formula) new_p pos; *)
                let r = {
                    match_res_lhs_node = new_h;
                    match_res_lhs_rest = lhs_h;
                    match_res_holes = [];
                    match_res_type = Root;
                    match_res_rhs_node = rhs;
                    match_res_rhs_rest = rhs_rest;
                } in
                let act = M_match r in
                (
                    (* WARNING : any dropping of match action must be followed by pop *)
                    must_action_stk # push act;
                    Some (new_iv,new_h,iv_alias))
              end


(*
type: Cformula.entail_state ->
  Cformula.h_formula ->
  Cformula.h_formula ->
  'a -> (Cformula.CP.spec_var list * Cformula.h_formula) option
*)
let infer_heap_nodes (es:entail_state) (rhs:h_formula) rhs_rest conseq pos = 
  let pr1 = !print_entail_state_short in
  let pr2 = !print_h_formula in
  let pr3 = pr_option (pr_triple !print_svl pr2 !print_svl) in
  Debug.no_2 "infer_heap_nodes" pr1 pr2 pr3
      (fun _ _ -> infer_heap_nodes es rhs rhs_rest conseq pos) es rhs

(* TODO : this procedure needs to be improved *)
(* picks ctr from f that are related to vars *)
(* may involve a weakening process *)
let rec filter_var f vars = 
  match f with
  | CP.Or (f1,f2,l,p) -> 
        CP.Or (filter_var f1 vars, filter_var f2 vars, l, p)
  | _ -> if TP.is_sat_raw f && CP.get_Neg_RelForm f = [] then CP.filter_var (CP.drop_rel_formula f) vars else CP.mkFalse no_pos
(*        let flag = TP.is_sat_raw f                                 *)
(*          try                                                      *)
(*            Omega.is_sat_weaken f "0"                              *)
(*          with _ -> true                                           *)
(*              (* spurious pre inf when set to true; check 2c.slk *)*)
(*        in
        if flag
        then CP.filter_var f vars 
        else CP.mkFalse no_pos*)

let filter_var f vars =
  let pr = !print_pure_f in
  Debug.no_2 "i.filter_var" pr !print_svl pr filter_var f vars 

let simplify_helper f = match f with
  | BForm ((Neq _,_),_) -> f
  | Not _ -> f
  | _ -> TP.simplify_raw f

(* TODO : this simplify could be improved *)
let simplify f vars = TP.simplify_raw (filter_var (TP.simplify_raw f) vars)
let simplify_contra f vars = filter_var f vars

let simplify f vars =
  let pr = !print_pure_f in
  Debug.no_2 "i.simplify" pr !print_svl pr simplify f vars 

let helper fml lhs_rhs_p weaken_flag = 
  let new_fml = CP.mkAnd fml lhs_rhs_p no_pos in
  if TP.is_sat_raw new_fml then (
    if weaken_flag then fml
    else
      let args = CP.fv new_fml in
      let iv = CP.fv fml in
      let quan_var = CP.diff_svl args iv in
      CP.mkExists_with_simpl TP.simplify_raw quan_var new_fml None no_pos)
  else CP.mkFalse no_pos

let rec simplify_disjs pf lhs_rhs weaken_flag =
  match pf with
  | BForm _ -> if CP.isConstFalse pf then pf else helper pf lhs_rhs weaken_flag
  | And _ -> helper pf lhs_rhs weaken_flag
  | Or (f1,f2,l,p) -> mkOr (simplify_disjs f1 lhs_rhs true) (simplify_disjs f2 lhs_rhs true) l p
  | Forall (s,f,l,p) -> Forall (s,simplify_disjs f lhs_rhs weaken_flag,l,p)
  | Exists (s,f,l,p) -> Exists (s,simplify_disjs f lhs_rhs weaken_flag,l,p)
  | _ -> pf

let simplify_disjs pf lhs_rhs = simplify_disjs pf lhs_rhs false

let infer_lhs_contra pre_thus lhs_xpure ivars pos msg =
  (* if ivars==[] then None *)
  (* else *)
  let lhs_xpure_orig = MCP.pure_of_mix lhs_xpure in
  let lhs_xpure = CP.drop_rel_formula lhs_xpure_orig in
  let check_sat = TP.is_sat_raw lhs_xpure in
  if not(check_sat) then None
  else 
    let f = simplify_contra lhs_xpure ivars in
    let vf = CP.fv f in
    let over_v = CP.intersect vf ivars in
    if (over_v ==[]) then None
    else 
      let exists_var = CP.diff_svl vf ivars in
      let f = simplify_helper (CP.mkExists exists_var f None pos) in
      if CP.isConstTrue f || CP.isConstFalse f then None
      else 
        let neg_f = Redlog.negate_formula f in
        (* Thai: Remove disjs contradicting with pre_thus *)
        let new_neg_f = 
          if CP.isConstTrue pre_thus then neg_f
          else simplify_disjs neg_f pre_thus
(*        let b = if CP.isConstTrue pre_thus then false
          else let f = CP.mkAnd pre_thus neg_f no_pos in
               not(TP.is_sat_raw f) *)
        in
        DD.devel_pprint ">>>>>> infer_lhs_contra <<<<<<" pos; 
        DD.devel_hprint (add_str "trigger cond   : " pr_id) msg pos; 
        DD.devel_hprint (add_str "LHS pure       : " !print_formula) lhs_xpure_orig pos; 
        DD.devel_hprint (add_str "ovrlap inf vars: " !print_svl) over_v pos; 
        DD.devel_hprint (add_str "pre infer   : " !print_formula) neg_f pos; 
        DD.devel_hprint (add_str "new pre infer   : " !print_formula) new_neg_f pos; 
        DD.devel_hprint (add_str "pre thus   : " !print_formula) pre_thus pos; 

        if CP.isConstFalse new_neg_f then
          (DD.devel_pprint "contradiction in inferred pre!" pos; 
          None)
        else Some (new_neg_f)

(*        DD.devel_hprint (add_str "contradict?: " string_of_bool) b pos; 
        if b then
          (DD.devel_pprint "contradiction in inferred pre!" pos; 
          None)
        else Some (neg_f)*)

let infer_lhs_contra pre_thus f ivars pos msg =
  let pr = !print_mix_formula in
  let pr2 = !print_pure_f in
  Debug.no_2 "infer_lhs_contra" pr !print_svl (pr_option pr2) 
      (fun _ _ -> infer_lhs_contra pre_thus f ivars pos msg) f ivars

let infer_lhs_contra_estate estate lhs_xpure pos msg =
  if no_infer estate then None
  else
    let ivars = estate.es_infer_vars in
    let p_thus = estate.es_infer_pure_thus in
    let r = infer_lhs_contra p_thus lhs_xpure ivars pos msg in
    match r with
      | None -> None
      | Some pf ->
            (* let prev_inf_h = estate.es_infer_heap in *)
            (* let prev_inf_p = estate.es_infer_pure in *)
            (* let _ = print_endline ("\nprev inf heap:"^(pr_list !print_h_formula prev_inf_h)) in *)
            (* let _ = print_endline ("prev inf pure:"^(pr_list !CP.print_formula prev_inf_p)) in *)
            let new_estate = CF.false_es_with_orig_ante estate estate.es_formula pos in

            Some (new_estate,pf)

let infer_lhs_contra_estate e f pos msg =
  let pr0 = !print_entail_state_short in
  let pr = !print_mix_formula in
  Debug.no_2 "infer_lhs_contra_estate" pr0 pr (pr_option (pr_pair pr0 !CP.print_formula)) (fun _ _ -> infer_lhs_contra_estate e f pos msg) e f

(*
   should this be done by ivars?
   (i) (lhs & rhs contradict)
       lhs & rhs --> false 
       find a lhs to negate to make state false
   (ii) rhs --> lhs (rhs is stronger)
        find a stronger rhs to add to lhs
*)
(* let infer_lhs_rhs_pure lhs_simp rhs_simp ivars (\* evars *\) = *)
(*   if ivars ==[] then None *)
(*   else  *)
(*     let fml = CP.mkAnd lhs_simp rhs_simp no_pos in *)
(*     let check_sat = Omega.is_sat fml "0" in *)
(*     if not(check_sat) then *)
(*       (\* lhs & rhs |- false *\) *)
(*       let f = simplify lhs_simp ivars in *)
(*       let vf = CP.fv f in *)
(*       let over_v = CP.intersect vf ivars in *)
(*       if (over_v ==[]) then None *)
(*       else Some (Redlog.negate_formula f) *)
(*     else  *)
(*       (\* rhs -> lhs *\) *)
(*       None *)

(* let infer_lhs_rhs_pure lhs rhs ivars = *)
(*   let pr = !print_pure_f in *)
(*   Debug.no_3 "infer_lhs_rhs_pure" pr pr !print_svl (pr_option pr) infer_lhs_rhs_pure lhs rhs ivars *)

(* let infer_lhs_rhs_pure_es estate lhs_xpure rhs_xpure pos = *)
(*   let ivars = estate.es_infer_vars in *)
(*   if ivars == [] then None *)
(*   else  *)
(*     let lhs_xpure = MCP.pure_of_mix lhs_xpure in *)
(*     let rhs_xpure = MCP.pure_of_mix rhs_xpure in *)
(*     let lhs_simp = simplify lhs_xpure ivars in *)
(*     let rhs_simp = simplify rhs_xpure ivars in *)
(*     let r = infer_lhs_rhs_pure lhs_simp rhs_simp ivars in *)
(*     match r with *)
(*       | None -> None *)
(*       | Some pf -> *)
(*             let new_estate = *)
(*               {estate with  *)
(*                   es_formula = normalize 0 estate.es_formula (CF.formula_of_pure_formula pf pos) pos; *)
(*                   es_infer_pure = estate.es_infer_pure@[pf]; *)
(*               } in *)
(*             Some new_estate *)

let present_in (orig_ls:CP.formula list) (new_pre:CP.formula) : bool =
  (* not quite needed, it seems *)
  (* let disj_p = CP.split_disjunctions new_pre in *)
  (* List.exists (fun a -> List.exists (CP.equalFormula a) disj_p) orig_ls *)
  List.exists (fun fml -> TP.imply_raw fml new_pre) orig_ls


(* lhs_rel denotes rel on LHS where rel assumption be inferred *)
let infer_pure_m estate lhs_rels lhs_xpure(* _orig *) lhs_xpure0 lhs_wo_heap (rhs_xpure:CP.formula) pos =
  if (no_infer estate) && (lhs_rels==None) then (None,None,[])
  else
    (* let rhs_xpure = MCP.pure_of_mix rhs_xpure in *)
    if not (TP.is_sat_raw rhs_xpure) then 
      (DD.devel_pprint "Cannot infer a precondition: RHS contradiction" pos;
      (None,None,[]))
    else
      (* let lhs_xpure = MCP.pure_of_mix lhs_xpure_orig in *)
      (* let rhs_vars = CP.fv rhs_xpure in *)
      (* below will help greatly reduce the redundant information inferred from state *)
      (* let lhs_xpure = CP.filter_ante lhs_xpure rhs_xpure in *)
      let _ = DD.trace_hprint (add_str "lhs(orig): " !CP.print_formula) lhs_xpure pos in
      let _ = DD.trace_hprint (add_str "rhs(orig): " !CP.print_formula) rhs_xpure pos in
      let lhs_xpure = CP.filter_ante lhs_xpure rhs_xpure in
      let _ = DD.trace_hprint (add_str "lhs (after filter_ante): " !CP.print_formula) lhs_xpure pos in
      let fml = CP.mkAnd lhs_xpure rhs_xpure pos in
      let fml = CP.drop_rel_formula fml in
      let iv_orig = estate.es_infer_vars in
      let iv_lhs_rel = match lhs_rels with
        | None -> []
        | Some f -> List.filter (fun x -> not(is_rel_var x)) (CP.fv f) in
      Debug.trace_hprint (add_str "iv_orig" !CP.print_svl) iv_orig no_pos;
      Debug.trace_hprint (add_str "iv_lhs_rel" !CP.print_svl) iv_lhs_rel no_pos;
      let iv = iv_orig@iv_lhs_rel in
      let check_sat = TP.is_sat_raw fml in
      if not(check_sat) then
        (DD.devel_pprint "LHS-RHS contradiction" pos;
        (* let lhs_xpure0 = MCP.pure_of_mix lhs_xpure0 in *)
        let _ = DD.trace_hprint (add_str "lhs0: " !CP.print_formula) lhs_xpure0 pos in
        let _ = DD.trace_hprint (add_str "rhs: " !CP.print_formula) rhs_xpure pos in
        let lhs_xpure0 = CP.filter_ante lhs_xpure0 rhs_xpure in
        let _ = DD.trace_hprint (add_str "lhs0 (after filter_ante): " !CP.print_formula) lhs_xpure0 pos in
        let lhs_xpure0 = MCP.mix_of_pure lhs_xpure0 in
        (infer_lhs_contra_estate estate lhs_xpure0 pos "ante contradict with conseq",None,[]))
      else
      (*let invariants = List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) estate.es_infer_invs in*)
      (* if check_sat then *)
      (*      let new_p = simplify fml iv in                            *)
      (*      let new_p = simplify (CP.mkAnd new_p invariants pos) iv in*)
      (*      if CP.isConstTrue new_p then None                         *)
      (*      else                                                      *)
      let lhs_wo_heap = MCP.pure_of_mix lhs_wo_heap in
      let lhs_wo_ptr_eqs = MCP.remove_ptr_equations lhs_wo_heap false in
      let vars_lhs = fv lhs_wo_ptr_eqs in (* var on lhs *)
      let vars_rhs = fv (MCP.remove_ptr_equations rhs_xpure false) in (* var on lhs *)
      let lhs_als = MCP.ptr_equations_without_null (MCP.mix_of_pure lhs_xpure) in
      let lhs_aset = build_var_aset lhs_als in
      let total_sub_flag = List.for_all (fun r ->
        let alias = r::(CP.EMapSV.find_equiv_all r lhs_aset) in
        CP.intersect alias iv != []) vars_rhs in
(*      let total_sub_flag =  (CP.diff_svl vars_rhs iv == []) in*)
      Debug.trace_hprint (add_str "total_sub_flag" string_of_bool) total_sub_flag no_pos;
      let vars_rhs = List.concat (List.map (fun r -> r::(CP.EMapSV.find_equiv_all r lhs_aset)) vars_rhs) in
      let vars_overlap =  if total_sub_flag then (CP.intersect_svl vars_lhs vars_rhs) else [] in
      Debug.trace_hprint (add_str "vars overlap" !CP.print_svl) vars_overlap no_pos;
      let args = CP.fv fml in (* var on lhs *)
      let quan_var = CP.diff_svl args iv in
      let quan_var = quan_var@vars_overlap in
      let is_bag_cnt = match !TP.tp with
        | TP.Mona | TP.MonaH -> if TP.is_bag_constraint fml then true else false
        | _ -> false
      in
      let new_p = 
        if is_bag_cnt then mkTrue no_pos
        else
          let lhs_xpure = CP.drop_rel_formula lhs_xpure in
          let new_p = TP.simplify_raw (CP.mkForall quan_var 
            (CP.mkOr (CP.mkNot_s lhs_xpure) rhs_xpure None pos) None pos) in
          let fml2 = TP.simplify_raw (CP.mkExists quan_var fml None no_pos) in
          let new_p2 = TP.simplify_raw (CP.mkAnd new_p fml2 no_pos) in
          let _ = DD.trace_hprint (add_str "lhs_xpure: " !CP.print_formula) lhs_xpure pos  in
          let _ = DD.trace_hprint (add_str "rhs_xpure: " !CP.print_formula) rhs_xpure pos  in
          let _ = DD.trace_hprint (add_str "fml: " !CP.print_formula) fml pos in
          let _ = DD.trace_hprint (add_str "fml2: " !CP.print_formula) fml2 pos in
          let _ = DD.trace_hprint (add_str "new_p2: " !CP.print_formula) new_p2 pos in
          let _ = DD.trace_hprint (add_str "quan_var: " !CP.print_svl) quan_var pos in
          let _ = DD.trace_hprint (add_str "iv: " !CP.print_svl) iv pos in
          let _ = DD.trace_hprint (add_str "new_p1: " !CP.print_formula) new_p pos in
          let new_p = TP.simplify_raw (simplify_disjs new_p fml) in
          let _ = DD.trace_hprint (add_str "new_p2: " !CP.print_formula) new_p pos in
          (* TODO : simplify_raw seems to undo pairwisecheck *)
          let new_p = TP.pairwisecheck_raw new_p in
          let _ = DD.trace_hprint (add_str "new_p2 (pairwisecheck): " !CP.print_formula) new_p pos in
          new_p
      in
      let args = CP.fv new_p in
      let new_p =
        if CP.intersect args iv == [] && quan_var != [] then
          let new_p = if CP.isConstFalse new_p then fml else CP.mkAnd fml new_p pos in
          let _ = DD.trace_hprint (add_str "new_p3: " !CP.print_formula) new_p pos in
          let new_p = simplify new_p iv in
          let _ = DD.trace_hprint (add_str "new_p4: " !CP.print_formula) new_p pos in
          (*let new_p = simplify (CP.mkAnd new_p invariants pos) iv in*)
          let args = CP.fv new_p in
          let quan_var = CP.diff_svl args iv in
          TP.simplify_raw (CP.mkExists quan_var new_p None pos)
        else
          simplify new_p iv
      in
      (* abstract common terms from disj into conjunctive form *)
      if CP.isConstTrue new_p || CP.isConstFalse new_p then 
        begin
            DD.devel_pprint ">>>>>> infer_pure_m <<<<<<" pos;
            DD.devel_pprint "Did not manage to infer a useful precondition" pos;
            DD.devel_hprint (add_str "LHS : " !CP.print_formula) lhs_xpure pos;               
            DD.devel_hprint (add_str "RHS : " !CP.print_formula) rhs_xpure pos;
            (* DD.devel_hprint (add_str "new pure: " !CP.print_formula) new_p pos; *)
            DD.devel_hprint (add_str "new pure: " !CP.print_formula) new_p pos;
            (None,None,[])
        end
      else
        let new_p_good = CP.simplify_disj_new new_p in
        (* remove ctr already present in the orig LHS *)
        let lhs_orig_list = CP.split_conjunctions lhs_xpure in
        let pre_list = CP.split_conjunctions new_p_good in
        let (red_pre,pre_list) = List.partition (present_in lhs_orig_list) pre_list in
        if pre_list==[] then (
          DD.devel_pprint ">>>>>> infer_pure_m <<<<<<" pos;
          DD.devel_pprint "Inferred pure is already in lhs" pos;
          (None,None,[]))
        else 
          let new_p_good = CP.join_conjunctions pre_list in
          (*let pre_thus = estate.es_infer_pure_thus in
          let b = if CP.isConstTrue pre_thus then false
            else let f = CP.mkAnd pre_thus new_p_good no_pos in
              not(TP.is_sat_raw f) 
          in*)
        (* filter away irrelevant constraint for infer_pure *)
        (* let new_p_good = CP.filter_ante new_p rhs_xpure in *)
        (* let _ = print_endline ("new_p:"^(!CP.print_formula new_p)) in *)
        (* let _ = print_endline ("new_p_good:"^(!CP.print_formula new_p_good)) in *)
        (* should not be using es_orig_ante *)
        (* let _,ante_pure,_,_,_ = CF.split_components estate.es_orig_ante in *)
        (* let ante_conjs = CP.list_of_conjs (MCP.pure_of_mix ante_pure) in *)
        (* let new_p_conjs = CP.list_of_conjs new_p_good in *)
        (* below redundant with filter_ante *)
       (* let new_p = List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) *)
       (*    (List.filter (fun c -> not (is_elem_of c ante_conjs)) new_p_conjs) in *)
        (* if CP.isConstTrue new_p || CP.isConstFalse new_p then (None,None) *)
        (* else *)
          begin
            let lhs_fil = CP.filter_ante lhs_xpure rhs_xpure in
            let lhs_simps = CP.simplify_filter_ante TP.simplify_always lhs_xpure rhs_xpure in
            DD.devel_pprint ">>>>>> infer_pure_m <<<<<<" pos;
            DD.devel_pprint ">>>>>> rel assume <<<<<<" pos;
            DD.devel_hprint (add_str "LHS" !CP.print_formula) lhs_xpure pos;               
            DD.devel_hprint (add_str "LHS filter" !CP.print_formula) lhs_fil pos;               
            DD.devel_hprint (add_str "LHS simpl" !CP.print_formula) lhs_simps pos;               
            DD.devel_hprint (add_str "RHS" !CP.print_formula) rhs_xpure pos;
            DD.devel_hprint (add_str "lhs_rels" (pr_opt !CP.print_formula)) lhs_rels pos;
            DD.devel_hprint (add_str "iv_orig" (!CP.print_svl)) iv_orig pos;
            (* DD.devel_hprint (add_str "new pure: " !CP.print_formula) new_p pos; *)
            if red_pre!=[] then DD.devel_hprint (add_str "already in LHS: " (pr_list !CP.print_formula)) red_pre pos;
            DD.devel_hprint (add_str "new pure: " !CP.print_formula) new_p_good pos;
            (*DD.devel_hprint (add_str "contradict?: " string_of_bool) b pos;
            if b then
              (DD.devel_pprint "contradiction in inferred pre!" pos; (None,None))
            else*)
            let ans,rel_ass = 
              let ans =Some new_p_good in
              match lhs_rels with
                | None -> ans,[]
                | Some f ->
                  (* (\* TODO Cristina : can remove duplicates too ; remove x=x*\) *)
                      (* let simplify_conjs f = *)
                      (* let rec simplify_disj_list conjl = *)
		      (* 	let simpl_conjl = List.map *)
		      (* 	  (fun x-> *)
		      (* 	    let disjl = split_disjunctions x in *)
		      (* 	    let simpl_disjl = List.map (fun x-> simplify_conjs x) disjl in *)
		      (* 	    join_disjunctions simpl_disjl) conjl *)
		      (* 	in *)
		      (* 	simpl_conjl *)
		      (* and simplify_conjs f = *)
		      (* 	(\* remove x=x *\) *)
		      (* 	(\* remove duplicated conjuncts *\) *)
		      (* 	let ls = remove_dupl_conj_eq ls in *)
		      (* 	(\* remove x=x inside inner disjuncts *\) *)
		      (* 	(\* let ls = simplify_disj_list ls in *\) *)
                      (*   join_conjunctions ls *)
                      if (CP.diff_svl (CP.fv new_p_good) iv_orig)==[] then ans,[] 
                      else 
                        let vars = stk_vars # get_stk in
                        (* let ra = MCP.pure_ptr_equations lhs_xpure in *)
                        (* let (subs,rest) = CP.simplify_subs ra vars [] in *)
                        (* let nsubs = CP.norm_subs (rest@subs) in *)
                        (* let asubs = rest@nsubs in *)
                        (* Debug.info_hprint (add_str "alias" (pr_list (pr_pair !CP.print_sv !CP.print_sv))) ra no_pos; *)
                        (* Debug.info_hprint (add_str "rest" (pr_list (pr_pair !CP.print_sv !CP.print_sv))) rest no_pos; *)
                        (* Debug.info_hprint (add_str "subs" (pr_list (pr_pair !CP.print_sv !CP.print_sv))) subs no_pos; *)
                        (* Debug.info_hprint (add_str "nsubs" (pr_list (pr_pair !CP.print_sv !CP.print_sv))) nsubs no_pos; *)
                        let vs = List.filter CP.is_rel_var (CP.fv f) in
                        (* (\* this is supposed to be // subs but seem very inefficient *\) *)
                        (* let n_rhs = (CP.subst asubs rhs_xpure) in *)
                        (* let lhs = (CP.subst asubs lhs_xpure) in *)
                        (* let lhs = simplify_conjs lhs in *)
			let (_,n_lhs,n_rhs) = simp_lhs_rhs vars (0,lhs_xpure,rhs_xpure) in
			(* take out of disjunction all common conjuncts *)
			(* let lhs = simplify_disj_new lhs in *)
                        (* Debug.info_hprint (add_str "lhs (simplified)" !print_formula) lhs no_pos;                         *)
			(* let n_lhs = CP.filter_ante lhs n_rhs in *)
                        Debug.info_hprint (add_str "lhs (after filter)" !print_formula) n_lhs no_pos;                        
                        (* ans,[(RelAssume vs,f,new_p_good)] *)
                        ans,[(RelAssume vs,n_lhs,n_rhs)]
            in (None,ans,rel_ass)
          end
              (* Thai: Should check if the precondition overlaps with the orig ante *)
              (* And simplify the pure in the residue *)
              (*           let new_es_formula = normalize 0 estate.es_formula (CF.formula_of_pure_formula new_p pos) pos in *)
              (* (\*          let h, p, fl, b, t = CF.split_components new_es_formula in                                                 *\) *)
              (* (\*          let new_es_formula = Cformula.mkBase h (MCP.mix_of_pure (Omega.simplify (MCP.pure_of_mix p))) t fl b pos in*\) *)
              (*           let args = List.filter (fun v -> if is_substr "inf" (name_of_spec_var v) then true else false) (CP.fv new_p) in *)
              (*           let new_iv = CP.diff_svl iv args in *)
              (*           let new_estate = *)
              (*             {estate with  *)
              (*                 es_formula = new_es_formula; *)
              (*                 (\* es_infer_pure = estate.es_infer_pure@[new_p]; *\) *)
              (*                 es_infer_vars = new_iv *)
              (*             } *)
              (*           in *)
    (* below removed because of ex/bug-3e.slk *)
    (* else *)
    (*   (\* contradiction detected *\) *)
    (*   (infer_lhs_contra_estate estate lhs_xpure_orig pos "ante contradict with conseq",None) *)
(*       let check_sat = TP.is_sat_raw lhs_xpure in *)
(*       if not(check_sat) then None *)
(*       else *)
(*         let lhs_simplified = simplify lhs_xpure iv in *)
(*         let args = CP.fv lhs_simplified in *)
(*         let exists_var = CP.diff_svl args iv in *)
(*         let lhs_simplified = simplify_helper (CP.mkExists exists_var lhs_simplified None pos) in *)
(*         (\*let new_p = simplify_contra (CP.mkAnd (CP.mkNot_s lhs_simplified) invariants pos) iv in*\) *)
(*         let new_p = simplify_contra (CP.mkNot_s lhs_simplified) iv in *)
(*         if CP.isConstFalse new_p || CP.isConstTrue new_p then None *)
(*         else *)
(* (\*          let args = CP.fv new_p in *\) *)
(*           (\* let new_iv = (CP.diff_svl iv args) in *\) *)
(*           let new_estate = *)
(*             {estate with *)
(*                 es_formula = CF.mkFalse (CF.mkNormalFlow ()) pos *)
(*                 (\* ;es_infer_pure = estate.es_infer_pure@[new_p] *\) *)
(*                     (\* ;es_infer_vars = new_iv *\) *)
(*             } *)
(*           in *)
(*           Some (new_estate,new_p) *)
(*
  Cformula.entail_state ->
  MCP.mix_formula (LHS) ->
  MCP.mix_formula (RHS) ->
  Globals.loc -> (Cformula.entail_state * CP.formula) option
*)


let infer_pure_m estate lhs_xpure_orig lhs_xpure0 lhs_wo_heap (rhs_xpure:MCP.mix_formula) pos =
  if (no_infer estate) && (no_infer_rel estate) then 
    (None,None,[])
  else 
    let rhs_xpure = MCP.pure_of_mix rhs_xpure in
    let lhs_xpure0 = MCP.pure_of_mix lhs_xpure0 in
    let lhs_xpure_orig = MCP.pure_of_mix lhs_xpure_orig in
    let cl = CP.filter_ante lhs_xpure_orig rhs_xpure in
    let cl = CP.split_conjunctions cl in
    let ivs = estate.es_infer_vars_rel in
    let (lhs_rel, lhs_wo_rel) = 
      List.partition (fun d -> (CP.get_RelForm d) != [] ) cl in
    let lhs_rel = 
      List.filter (fun d -> (CP.intersect (CP.fv d) ivs) != [] ) lhs_rel in
    let lhs_rels,xp = match lhs_rel with 
      | [] -> None, join_conjunctions lhs_wo_rel
      | _ -> Debug.trace_hprint (add_str "lhs_rels" (pr_list !CP.print_formula)) lhs_rel no_pos;
            let v = join_conjunctions lhs_rel in
            Some (join_conjunctions lhs_rel), join_conjunctions (v::lhs_wo_rel)
    in 
    infer_pure_m estate lhs_rels xp lhs_xpure0 lhs_wo_heap rhs_xpure pos

let infer_pure_m estate lhs_xpure lhs_xpure0 lhs_wo_heap rhs_xpure pos =
  (* let _ = print_endline "WN : inside infer_pure_m" in *)
  let pr1 = !print_mix_formula in 
  let pr2 = !print_entail_state_short in 
  let pr_p = !CP.print_formula in
  let pr_res = pr_triple (pr_option (pr_pair pr2 !print_pure_f)) (pr_option pr_p) (fun l -> (string_of_int (List.length l))) in
  let pr0 es = pr_pair pr2 !CP.print_svl (es,es.es_infer_vars) in
      Debug.no_4 "infer_pure_m" 
          (add_str "estate " pr0) 
          (add_str "lhs xpure " pr1) 
          (add_str "lhs xpure0 " pr1)
          (add_str "rhs xpure " pr1)
          (add_str "(new es,inf pure,rel_ass) " pr_res)
      (fun _ _ _ _ -> infer_pure_m estate lhs_xpure lhs_xpure0 lhs_wo_heap rhs_xpure pos) estate lhs_xpure lhs_xpure0 rhs_xpure   

let remove_contra_disjs f1s f2 =
  let helper c1 c2 = 
    let conjs1 = CP.list_of_conjs c1 in
    let conjs2 = CP.list_of_conjs c2 in
    (Gen.BList.intersect_eq CP.equalFormula conjs1 conjs2) != []
  in 
  let new_f1s = List.filter (fun f -> helper f f2) f1s in
  match new_f1s with
    | [] -> f1s
    | [hd] -> [hd]
    | ls -> f1s
  

let lhs_simplifier lhs_h lhs_p =
  let disjs = CP.list_of_disjs lhs_h in
  let disjs = remove_contra_disjs disjs lhs_p in
  trans_dnf (CP.mkAnd (disj_of_list disjs no_pos) lhs_p no_pos)

(* TODO : proc below seems very inefficient *)
(*let rec simplify_fml pf =                                         *)
(*  let helper fml =                                                *)
(*    let fml = CP.drop_rel_formula fml in                          *)
(*    if TP.is_sat_raw fml then remove_dup_constraints fml          *)
(*    else CP.mkFalse no_pos                                        *)
(*  in                                                              *)
(*  match pf with                                                   *)
(*  | BForm _ -> if CP.isConstFalse pf then pf else helper pf       *)
(*  | And _ -> helper pf                                            *)
(*  | Or (f1,f2,l,p) -> mkOr (simplify_fml f1) (simplify_fml f2) l p*)
(*  | Forall (s,f,l,p) -> Forall (s,simplify_fml f,l,p)             *)
(*  | Exists (s,f,l,p) -> Exists (s,simplify_fml f,l,p)             *)
(*  | _ -> pf                                                       *)

(* a good simplifier is needed here *)
(*let lhs_simplifier lhs_h lhs_p =                                   *)
(*    let lhs = simplify_fml (trans_dnf(mkAnd lhs_h lhs_p no_pos)) in*)
(*    lhs                                                            *)

let lhs_simplifier_tp lhs_h lhs_p =
    (TP.simplify_raw_w_rel (mkAnd lhs_h lhs_p no_pos))

let lhs_simplifier_tp lhs_h lhs_p =
  let pr = !CP.print_formula in
    Debug.no_2 "lhs_simplifier_tp" pr pr pr lhs_simplifier_tp lhs_h lhs_p

(* to filter relevant LHS term for selected relation rel *)
(* requires simplify and should preserve relation and != *)
let rel_filter_assumption is_sat lhs rel =
  (* let (lhs,rel) = CP.assumption_filter_aggressive_incomplete  lhs rel in *)
  let (lhs,rel) = CP.assumption_filter_aggressive is_sat lhs rel in
  (lhs,rel)

(* let rel_filter_assumption lhs rel = *)
(*   let pr = CP.print_formula in *)
(*   Debug.no_2 "rel_filter_assumption" pr pr (fun (r,_) -> pr r) rel_filter_assumption lhs rel  *)

let delete_present_in i_pure compared_pure_list =
  let i_pure_list = CP.split_conjunctions i_pure in
  let i_pure_list = List.filter (fun p -> not (present_in compared_pure_list p)) i_pure_list in
  CP.join_conjunctions i_pure_list

(*let check_rank_dec rank_fml lhs_cond = match rank_fml with
  | BForm (bf,_) ->
    (match bf with
    | (Gt (Func (id1,args1,_), Func (id2,args2,_),_),_) ->
      if id1 = id2 && List.length args1 = List.length args2 then
        let fml = CP.disj_of_list (List.map2 (fun e1 e2 -> CP.mkNeqExp e1 e2 no_pos) args1 args2) no_pos in
        if not(TP.is_sat_raw (CP.mkAnd lhs_cond fml no_pos)) then CP.mkFalse no_pos else rank_fml
      else rank_fml
    | (Lt (Func (id1,args1,_), Func (id2,args2,_),_),_) -> 
      if id1 = id2 && List.length args1 = List.length args2 then
        let fml = CP.disj_of_list (List.map2 (fun e1 e2 -> CP.mkNeqExp e1 e2 no_pos) args1 args2) no_pos in
        if not(TP.is_sat_raw (CP.mkAnd lhs_cond fml no_pos)) then CP.mkFalse no_pos else rank_fml
      else rank_fml
    | _ -> rank_fml)    
  | _ -> rank_fml
    
let check_rank_const rank_fml lhs_cond = match rank_fml with
  | BForm (bf,_) ->
    (match bf with
    | (Eq (Func (id1,args1,_), Func (id2,args2,_),_),_) ->
      if id1 = id2 && List.length args1 = List.length args2 then
        let fml = CP.join_conjunctions (List.map2 (fun e1 e2 -> CP.mkEqExp e1 e2 no_pos) args1 args2) in
        if not(TP.is_sat_raw (CP.mkAnd lhs_cond fml no_pos)) then CP.mkFalse no_pos else CP.mkTrue no_pos
      else CP.mkTrue no_pos
    | _ -> CP.mkTrue no_pos)
  | _ -> CP.mkTrue no_pos*)

(* Assume fml is conjs *)
(*let filter_rank fml lhs_cond =
  let (rank, others) = List.partition (fun p -> CP.is_Rank_Dec p || CP.is_Rank_Const p) (CP.split_conjunctions fml) in
  let (rank_dec, rank_const) = List.partition (fun p -> CP.is_Rank_Dec p) rank in
  let rank_dec = List.map (fun r -> check_rank_dec r lhs_cond) rank_dec in
  let rank_const = List.map (fun r -> check_rank_const r lhs_cond) rank_const in
  CP.join_conjunctions (rank_dec@rank_const@others) *)

let infer_collect_rel is_sat estate xpure_lhs_h1 (* lhs_h *) lhs_p_orig (* lhs_b *) rhs_p rhs_p_br 
    heap_entail_build_mix_formula_check pos =
  (* TODO : need to handle pure_branches in future ? *)
  if no_infer_rel estate then (estate,lhs_p_orig,rhs_p,rhs_p_br) 
  else 
    let ivs = estate.es_infer_vars_rel in
    let rhs_p_n = MCP.pure_of_mix rhs_p in
    (* Eliminate dijs in rhs which cannot be implied by lhs and do not contain relations *)
    (* Suppose rhs_p_n is in DNF *)
    (* Need to assure that later *)
    let rhs_disjs = CP.list_of_disjs rhs_p_n in
    let (rhs_disjs_rel, rhs_disjs_wo_rel) = 
      List.partition (fun d -> CP.get_RelForm d != [] || CP.get_Rank d != []) rhs_disjs in
    let lhs_cond = MCP.pure_of_mix lhs_p_orig in
    let rhs_disjs_wo_rel_new, other_disjs = List.partition (fun d -> TP.imply_raw lhs_cond d) rhs_disjs_wo_rel in
    let other_disjs = List.filter (fun d -> TP.is_sat_raw (CP.mkAnd lhs_cond d no_pos)) other_disjs in
    (* DD.devel_hprint (add_str "LHS pure" !CP.print_formula) (MCP.pure_of_mix lhs_p_orig) pos; *)
    (* DD.devel_hprint (add_str "RHS Disj List" (pr_list !CP.print_formula)) rhs_disjs pos; *)
    let pairs = List.map (fun pure ->
      let rhs_ls = CP.split_conjunctions pure in
      let rels, others = List.partition (fun p -> CP.is_rel_in_vars ivs p || CP.has_func p) rhs_ls in
      let rels = if List.exists (fun p -> CP.is_Rank_Const p) rels then [CP.conj_of_list rels no_pos] else rels in
      rels, others)
      (rhs_disjs_rel @ rhs_disjs_wo_rel_new) in
    let rel_rhs_ls, other_rhs_ls = List.split pairs in
    let rel_rhs = List.concat rel_rhs_ls in
    if rel_rhs==[] then (
      DD.devel_pprint ">>>>>> infer_collect_rel <<<<<<" pos; 
      DD.devel_pprint "no relation in rhs" pos; 
      (estate,lhs_p_orig,rhs_p,rhs_p_br)
    (* DD.devel_hprint (add_str "RHS pure" !CP.print_formula) rhs_p_n_new pos; *)
    (* TODO : need to check if relation occurs in both lhs & rhs of original entailment *)
    (* Check if it is related to being unable to fold rhs_heap *)
    (*      if !unable_to_fold_rhs_heap = false then
            (estate,lhs_p_orig,rhs_p,rhs_p_br)
	    else (
            unable_to_fold_rhs_heap := false;
            let lhs_xpure = MCP.merge_mems xpure_lhs_h1 lhs_p_orig true in
            let evars = estate.es_evars@estate.es_gen_expl_vars@estate.es_ivars in
            let _, new_rhs_p = heap_entail_build_mix_formula_check evars lhs_p_orig rhs_p pos in
            let lhs_p = MCP.pure_of_mix lhs_p_orig in
            let rel_lhs = CP.get_RelForm lhs_p in
            let infer_vars = CP.remove_dups_svl (List.concat (List.map CP.get_rel_args rel_lhs)) in
            let new_estate = {estate with es_infer_vars = infer_vars} in
            let inferred_pure = infer_pure_m new_estate lhs_xpure lhs_xpure lhs_xpure new_rhs_p pos in
            let (estate, lhs_p) = begin
            match inferred_pure with
    (* TODO : how to handle rel_ass ?? *)
            | (None, Some p, rel_ass) ->
            let vl =  estate.es_infer_vars in
            if CP.subset (CP.fv p) vl then (estate, lhs_p)
            else
            (DD.devel_pprint ">>>>>> infer_collect_rel <<<<<<" pos;
            DD.devel_pprint "unable to fold rhs_heap because of relations" pos;
            DD.trace_hprint (add_str "infer pure" !CP.print_formula) p no_pos;
            DD.trace_hprint (add_str "ivars" !CP.print_svl) vl no_pos;
            ({estate with es_assumed_pure = estate.es_assumed_pure @ [p]}, CP.mkAnd lhs_p p pos))
            | _ -> (estate, lhs_p)
            end
            in
            (estate,MCP.mix_of_pure lhs_p,rhs_p,rhs_p_br)
	    )*)
    )
    else 
      (* TODO: Check if inferred rel can imply es_assumed_pure in the end *)

      (*      let lhs_orig = MCP.pure_of_mix lhs_p_orig in
	      DD.devel_hprint (add_str "Assumed pure list:" (pr_list !CP.print_formula)) estate.es_assumed_pure pos;
	      let assumed_pure_list = List.concat (List.map CP.split_conjunctions estate.es_assumed_pure) in
	      let lhs_orig = delete_present_in lhs_orig assumed_pure_list in
	      let lhs_p_orig = MCP.mix_of_pure lhs_orig in
	      let h, p, fl, b, t = split_components estate.es_formula in
	      let p = delete_present_in (MCP.pure_of_mix p) assumed_pure_list in
	      let fml = mkBase h (MCP.mix_of_pure p) t fl b pos in
	      let estate = {estate with es_formula = fml} in*)
      let lhs_p = MCP.pure_of_mix lhs_p_orig in
      let (lhs_p_memo,subs,bvars) = CP.memoise_rel_formula ivs lhs_p in
      (* Begin: To keep vars of rel_form in lhs *)
      let _,rel_lhs = List.split subs in
      let rel_vars = List.concat (List.map CP.fv rel_lhs) in
      (* End  : To keep vars of rel_form in lhs *)

      (*let pr = !CP.print_formula_br in*)
      (* let _ = print_endline (pr rhs_p_br) in *)
      (*let ranks = List.filter CP.has_func rel_rhs in*)
      let rhs_p_2 = CP.disj_of_list ((List.map (fun other_rhs -> CP.join_conjunctions other_rhs) other_rhs_ls)@other_disjs) no_pos in
      let rhs_p_new = MCP.mix_of_pure rhs_p_2 in

      (* Eliminate relations whose recursive calls are not defined *)
      (* e.g. A(x) <- A(t) && other_constraints, *)
      (* where other_constraints are not related to variable t *)
      let lhs_rec_vars = CP.fv lhs_p_memo in
      if CP.intersect lhs_rec_vars rel_vars = [] && rel_lhs != [] then (
        DD.devel_pprint ">>>>>> no recursive def <<<<<<" pos; 
        (estate,lhs_p_orig,rhs_p_new,rhs_p_br))
      else
        let lhs_h = MCP.pure_of_mix xpure_lhs_h1 in
        (* let lhs = lhs_simplifier lhs_h lhs_p_memo in *)
        DD.trace_hprint (add_str "lhs_p:" (!CP.print_formula)) lhs_p pos;
        DD.trace_hprint (add_str "lhs_p_memo:" (!CP.print_formula)) lhs_p_memo pos;
        DD.trace_hprint (add_str "lhs_h (xpure_lhs_h1):" (!CP.print_formula)) lhs_h pos;

        let lhs = lhs_simplifier_tp lhs_h lhs_p_memo in
        DD.trace_hprint (add_str "lhs (after lhs_simplifier):" (!CP.print_formula)) lhs pos;
        let lhs_2 = CP.restore_memo_formula subs bvars lhs in
        DD.trace_hprint (add_str "lhs_2 (b4 filter ass):" (!CP.print_formula)) lhs_2 pos;
        let filter_ass lhs rhs = 
          let (lhs,rhs) = rel_filter_assumption is_sat lhs rhs in
          (simplify_disj_new lhs,rhs) in      
        let pairwise_proc lhs =
          let lst = CP.split_conjunctions lhs in
          (* perform pairwise only for disjuncts *)
          let lst = List.map (fun e -> if CP.is_disjunct e then TP.pairwisecheck e else e) lst in
          CP.join_conjunctions lst
        in
        let wrap_exists (lhs,rhs) =
          let vs_r = CP.fv rhs in
          let vs_l = CP.fv lhs in
          let diff_vs = diff_svl vs_l (vs_r@rel_vars) in
          DD.devel_hprint (add_str "diff_vs" !print_svl) diff_vs pos;
          let new_lhs = CP.wrap_exists_svl lhs diff_vs in
          DD.devel_hprint (add_str "new_lhs (b4 elim_exists)" !CP.print_formula) new_lhs pos;
          let new_lhs = Redlog.elim_exists_with_eq new_lhs in
          DD.devel_hprint (add_str "new_lhs (aft elim_exists)" !CP.print_formula) new_lhs pos;
          let new_lhs = CP.arith_simplify_new new_lhs in
	  (*          (new_lhs,rhs) 
		      in*)
	  (*          let new_lhs = TP.simplify_raw (CP.arith_simplify_new new_lhs) in*)
	  (*          let new_lhs_drop_rel = TP.simplify_raw (CP.drop_rel_formula new_lhs) in*)
	  (*          let new_lhs_drop_rel = pairwise_proc new_lhs_drop_rel in*)
	  (*          let new_lhs = List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 no_pos) new_lhs_drop_rel rel_lhs in*)
          let rel_def_id = CP.get_rel_id_list rhs in
          let rank_bnd_id = CP.get_rank_bnd_id_list rhs in
          let rank_dec_id = CP.get_rank_dec_and_const_id_list rhs in
          let rel_cat = 
            if rel_def_id != [] then CP.RelDefn (List.hd rel_def_id) else 
              if rank_bnd_id != [] then CP.RankBnd (List.hd rank_bnd_id) else
		if rank_dec_id != [] then CP.RankDecr rank_dec_id else
		  report_error pos "Relation belongs to unexpected category"
          in
	  (*          if CP.intersect (CP.fv new_lhs_drop_rel) rel_vars = [] && rel_lhs != [] then 
		      (DD.devel_pprint ">>>>>> no recursive def <<<<<<" pos; [])
		      else*)
          (*if CP.isConstTrue new_lhs then [] else *)[(rel_cat,new_lhs,rhs)] in
        let inf_rel_ls = List.map (filter_ass lhs_2) rel_rhs in
        DD.trace_hprint (add_str "Rel Inferred (b4 pairwise):" (pr_list (fun (x,_) -> !CP.print_formula x))) inf_rel_ls pos;
        let inf_rel_ls = List.map (fun (lhs,rhs) -> (pairwise_proc lhs,rhs)) inf_rel_ls in
        DD.trace_hprint (add_str "Rel Inferred (b4 wrap_exists):" (pr_list print_only_lhs_rhs)) inf_rel_ls pos;
	(*        let inf_rel_ls = List.map wrap_exists inf_rel_ls in*)
        let inf_rel_ls = List.concat (List.map wrap_exists inf_rel_ls) in
        (* TODO: Change corresponding vars for assumed pure *)
        let rel_cat_fml = List.hd rel_rhs in
        let assume_p  = estate.es_assumed_pure in
        let assume_rel_ls = List.map (fun ass_pure -> 
          (CP.RelAssume (CP.get_rel_id_list rel_cat_fml), rel_cat_fml, ass_pure)) assume_p in
        DD.trace_hprint (add_str "Assume Pure :" (pr_list !CP.print_formula)) assume_p pos;
        DD.trace_hprint (add_str "rel_rhs :" (pr_list !CP.print_formula)) rel_rhs pos;
        DD.trace_hprint (add_str "rel_cat_fml :" (!CP.print_formula)) rel_cat_fml pos;
        DD.info_hprint (add_str "Rel Inferred" (pr_list print_lhs_rhs)) inf_rel_ls pos;
        DD.info_hprint (add_str "Rel Assume :" (pr_list (fun (_,a,b)->print_only_lhs_rhs (a,b)))) assume_rel_ls pos;
        let vars = stk_vars # get_stk in
	(* below causes non-linear LHS for relation *)
	(* let inf_rel_ls = List.map (simp_lhs_rhs vars) inf_rel_ls in *)
        (* DD.info_hprint (add_str "Rel Inferred (simplified)" (pr_list print_lhs_rhs)) inf_rel_ls pos; *)
        let estate = { estate with es_infer_rel = inf_rel_ls@(estate.es_infer_rel)@assume_rel_ls } in
        if inf_rel_ls != [] then
          begin
            DD.devel_pprint ">>>>>> infer_collect_rel <<<<<<" pos;
            DD.devel_hprint (add_str "Infer Rel Ids" !print_svl) ivs pos;
            (* DD.devel_hprint (add_str "LHS heap Xpure1:" !print_mix_formula) xpure_lhs_h1 pos; *)
            DD.devel_hprint (add_str "LHS pure" !CP.print_formula) lhs_p pos;
            DD.devel_hprint (add_str "RHS pure" !CP.print_formula) rhs_p_n pos;
            DD.devel_hprint (add_str "RHS Rel List" (pr_list !CP.print_formula)) rel_rhs pos;
          end;
        (estate,lhs_p_orig,rhs_p_new,rhs_p_br)
(*
Given:
infer vars:[n,R]
LHS heap Xpure1: x=null & n=0 | x!=null & 1<=n
LHS pure: x=null & rs=0
RHS pure R(rs,n) & x=null
(1) simplify LHS to:
     x=null & n=0 & rs=0
(2) partition RHS to 
    (a) R(rs,n)
    (b) x=null
(3) for inferred relation R, use filter
    assumption to obtain:
     (n=0 rs=0 --> R(rs,n)) to add to es_infer_rel 
*)


let infer_collect_rel is_sat estate xpure_lhs_h1 (* lhs_h *) lhs_p (* lhs_b *) rhs_p rhs_p_br 
  heap_entail_build_mix_formula_check pos =
  let pr0 = !print_svl in
  let pr1 = !print_mix_formula in
  let pr2 (es,l,r,_) = pr_triple pr1 pr1 (pr_list CP.print_lhs_rhs) (l,r,es.es_infer_rel) in
      Debug.no_4 "infer_collect_rel" pr0 pr1 pr1 pr1 pr2
      (fun _ _ _ _ -> infer_collect_rel is_sat estate xpure_lhs_h1 (* lhs_h *) lhs_p (* lhs_b *) 
      rhs_p rhs_p_br heap_entail_build_mix_formula_check pos) estate.es_infer_vars_rel xpure_lhs_h1 lhs_p rhs_p

let infer_empty_rhs estate lhs_p rhs_p pos =
  estate

(* let infer_empty_rhs_old estate lhs_p rhs_p pos = *)
(*   if no_infer estate then estate *)
(*   else *)
(*     let _ = DD.devel_pprint ("\n inferring_empty_rhs:"^(!print_formula estate.es_formula)^ "\n\n")  pos in *)
(*     let rec filter_var f vars = match f with *)
(*       | CP.Or (f1,f2,l,p) -> CP.Or (filter_var f1 vars, filter_var f2 vars, l, p) *)
(*       | _ -> CP.filter_var f vars *)
(*     in *)
(*     let infer_pure = MCP.pure_of_mix rhs_p in *)
(*     let infer_pure = if CP.isConstTrue infer_pure then infer_pure *)
(*     else CP.mkAnd (MCP.pure_of_mix rhs_p) (MCP.pure_of_mix lhs_p) pos *)
(*     in *)
(*     (\*        print_endline ("PURE: " ^ Cprinter.string_of_pure_formula infer_pure);*\) *)
(*     let infer_pure = Omega.simplify (filter_var infer_pure estate.es_infer_vars) in *)
(*     let pure_part2 = Omega.simplify (List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) *)
(*         (estate.es_infer_pures @ [MCP.pure_of_mix rhs_p])) in *)
(*     (\*        print_endline ("PURE2: " ^ Cprinter.string_of_pure_formula infer_pure);*\) *)
(*     let infer_pure = if Omega.is_sat pure_part2 "0" = false then [CP.mkFalse pos] else [infer_pure] in *)
(*       {estate with es_infer_heap = []; es_infer_pure = infer_pure; *)
(*           es_infer_pures = estate.es_infer_pures @ [(MCP.pure_of_mix rhs_p)]} *)

let infer_empty_rhs2 estate lhs_xpure rhs_p pos =
  estate

(* let infer_empty_rhs2_old estate lhs_xpure rhs_p pos = *)
(*   if no_infer estate then estate *)
(*   else *)
(*     let _ = DD.devel_pprint ("\n inferring_empty_rhs2:"^(!print_formula estate.es_formula)^ "\n\n")  pos in *)
(*     (\* let lhs_xpure,_,_,_ = xpure prog estate.es_formula in *\) *)
(*     let pure_part_aux = Omega.is_sat (CP.mkAnd (MCP.pure_of_mix lhs_xpure) (MCP.pure_of_mix rhs_p) pos) "0" in *)
(*     let rec filter_var_aux f vars = match f with *)
(*       | CP.Or (f1,f2,l,p) -> CP.Or (filter_var_aux f1 vars, filter_var_aux f2 vars, l, p) *)
(*       | _ -> CP.filter_var f vars *)
(*     in *)
(*     let filter_var f vars =  *)
(*       if CP.isConstTrue (Omega.simplify f) then CP.mkTrue pos  *)
(*       else *)
(*         let res = filter_var_aux f vars in *)
(*         if CP.isConstTrue (Omega.simplify res) then CP.mkFalse pos *)
(*         else res *)
(*     in *)
(*     let invs = List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) estate.es_infer_invs in *)
(*     let pure_part =  *)
(*       if pure_part_aux = false then *)
(*         let mkNot purefml =  *)
(*           let conjs = CP.split_conjunctions purefml in *)
(*           let conjs = List.map (fun c -> CP.mkNot_s c) conjs in *)
(*           List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos) conjs *)
(*         in *)
(*         let lhs_pure = CP.mkAnd (mkNot(Omega.simplify  *)
(*             (filter_var (MCP.pure_of_mix lhs_xpure) estate.es_infer_vars))) invs pos in *)
(*         (\*print_endline ("PURE2: " ^ Cprinter.string_of_pure_formula lhs_pure);*\) *)
(*         CP.mkAnd lhs_pure (MCP.pure_of_mix rhs_p) pos *)
(*       else Omega.simplify (CP.mkAnd (CP.mkAnd (MCP.pure_of_mix lhs_xpure) (MCP.pure_of_mix rhs_p) pos) invs pos) *)
(*     in *)
(*     let pure_part = filter_var (Omega.simplify pure_part) estate.es_infer_vars in *)
(*     (\*        print_endline ("PURE: " ^ Cprinter.string_of_mix_formula rhs_p);*\) *)
(*     let pure_part = Omega.simplify pure_part in *)
(*     let pure_part2 = Omega.simplify (CP.mkAnd pure_part  *)
(*         (List.fold_left (fun p1 p2 -> CP.mkAnd p1 p2 pos) (CP.mkTrue pos)  *)
(*             (estate.es_infer_pures @ [MCP.pure_of_mix rhs_p])) pos) in *)
(*     (\*        print_endline ("PURE1: " ^ Cprinter.string_of_pure_formula pure_part);*\) *)
(*     (\*        print_endline ("PURE2: " ^ Cprinter.string_of_pure_formula pure_part2);*\) *)
(*     let pure_part = if (CP.isConstTrue pure_part & pure_part_aux = false)  *)
(*       || Omega.is_sat pure_part2 "0" = false then [CP.mkFalse pos] else [pure_part] in *)
(*     {estate with es_infer_heap = []; es_infer_pure = pure_part; *)
(*         es_infer_pures = estate.es_infer_pures @ [(MCP.pure_of_mix rhs_p)]} *)

(* Calculate the invariant relating to unfolding *)
(*let infer_for_unfold prog estate lhs_node pos =
  if no_infer estate then estate
  else
(*    let _ = DD.devel_pprint ("\n inferring_for_unfold:"^(!print_formula estate.CF.es_formula)^ "\n\n")  pos in*)
    let inv = match lhs_node with
      | ViewNode ({h_formula_view_name = c}) ->
        let vdef = Cast.look_up_view_def pos prog.Cast.prog_view_decls c in
        let i = MCP.pure_of_mix (fst vdef.Cast.view_user_inv) in
        if List.mem i estate.es_infer_invs then estate.es_infer_invs
        else estate.es_infer_invs @ [i]
      | _ -> estate.es_infer_invs
    in {estate with es_infer_invs = inv} *)


(* Calculate the invariant relating to unfolding *)
(*let infer_for_unfold prog estate lhs_node pos =
  let pr es =  pr_list !CP.print_formula es.es_infer_invs in
  let pr2 = !print_h_formula in
  Debug.no_2 "infer_for_unfold" 
      (add_str "es_infer_inv (orig) " pr) 
      (add_str "lhs_node " pr2) 
      (add_str "es_infer_inv (new) " pr)
      (fun _ _ -> infer_for_unfold prog estate lhs_node pos) estate lhs_node*)


(* let infer_for_unfold_old prog estate lhs_node pos = *)
(*   if no_infer estate then estate *)
(*   else *)
(*     let _ = DD.devel_pprint ("\n inferring_for_unfold:"^(!print_formula estate.es_formula)^ "\n\n")  pos in *)
(*     let inv = matchcntha lhs_node with *)
(*       | ViewNode ({h_formula_view_name = c}) -> *)
(*             let vdef = Cast.look_up_view_def pos prog.Cast.prog_view_decls c in *)
(*             let i = MCP.pure_of_mix (fst vdef.Cast.view_user_inv) in *)
(*             if List.mem i estate.es_infer_invs then estate.es_infer_invs *)
(*             else estate.es_infer_invs @ [i] *)
(*       | _ -> estate.es_infer_invs *)
(*     in {estate with es_infer_invs = inv}  *)

