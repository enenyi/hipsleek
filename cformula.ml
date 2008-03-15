(*
  Created 21-Feb-2006

  Formula
*)

open Globals

module Err = Error
module CP = Cpure
module U = Util

type t_formula = (* type constraint *)
	| TypeExact of t_formula_sub_type (* for t = C *)
	| TypeSub of t_formula_sub_type (* for t <: C *)
	| TypeSuper of t_formula_sub_type (* for t < C *)
	| TypeAnd of t_formula_and
	| TypeTrue
	| TypeFalse

and t_formula_sub_type = { t_formula_sub_type_var : CP.spec_var;
						   t_formula_sub_type_type : ident }

and t_formula_and = { t_formula_and_f1 : t_formula;
					  t_formula_and_f2 : t_formula }

type formula =
  | Base of formula_base
  | Or of formula_or
  | Exists of formula_exists

and formula_base = { formula_base_heap : h_formula;
					 formula_base_pure : CP.formula;
					 formula_base_type : t_formula;
					 formula_base_pos : loc }

and formula_or = { formula_or_f1 : formula;
				   formula_or_f2 : formula;
				   formula_or_pos : loc }

and formula_exists = { formula_exists_qvars : CP.spec_var list;
					   formula_exists_heap : h_formula;
					   formula_exists_pure : CP.formula;
					   formula_exists_type : t_formula;
					   formula_exists_pos : loc }
	  
and h_formula = (* heap formula *)
  | Star of h_formula_star
  | DataNode of h_formula_data
  | ViewNode of h_formula_view
  | HTrue
  | HFalse

and h_formula_star = { h_formula_star_h1 : h_formula;
					   h_formula_star_h2 : h_formula;
					   h_formula_star_pos : loc }

and h_formula_data = { h_formula_data_node : CP.spec_var;
					   h_formula_data_name : ident;
					   h_formula_data_arguments : CP.spec_var list;
					   (* first argument: type variable
						  second argument: pointer to the next extension *)
					   h_formula_data_pos : loc }

and h_formula_view = { h_formula_view_node : CP.spec_var;
					   h_formula_view_name : ident;
					   h_formula_view_arguments : CP.spec_var list;
					   h_formula_view_modes : mode list;
					   h_formula_view_coercible : bool;
					   h_formula_view_origins : ident list;
					   (* if this view is generated by a coercion from another view c, 
						  then c is in h_formula_view_origins. Used to avoid loopy coercions *)
					   h_formula_view_pos : loc }

and approx_disj = 
  | ApproxBase of approx_disj_base
  | ApproxOr of approx_disj_or

and approx_formula =
  | ApproxCon of approx_disj
  | ApproxAnd of approx_formula_and
	  
and approx_disj_base = { approx_disj_base_vars : CP.spec_var list;
						 (* list of variables that _must_ point to objects *)
						 approx_disj_base_formula : CP.formula }
	
and approx_disj_or = { approx_disj_or_d1 : approx_disj;
					   approx_disj_or_d2 : approx_disj }

and approx_formula_and = { approx_formula_and_a1 : approx_formula;
						   approx_formula_and_a2 : approx_formula }

(* utility functions *)

let rec formula_of_heap h pos = mkBase h (CP.mkTrue pos) TypeTrue pos

and formula_of_pure p pos = mkBase HTrue p TypeTrue pos

and data_of_h_formula h = match h with
  | DataNode d -> d
  | _ -> failwith ("data_of_h_formula: input is not a data node")

and isConstFalse f = match f with
  | Base ({formula_base_heap = h;
		   formula_base_pure = p}) -> h = HFalse || CP.isConstFalse p
  | _ -> false

and isConstTrue f = match f with
  | Base ({formula_base_heap = HTrue;
		   formula_base_pure = p}) -> CP.isConstTrue p 
	  (* don't need to care about formula_base_type  *)
  | _ -> false

and is_complex_heap (h : h_formula) : bool = match h with
  | HTrue | HFalse -> false
  | _ -> true

and is_coercible (h : h_formula) : bool = match h with
  | ViewNode ({h_formula_view_coercible = c}) -> c
  | _ -> false

(*
  perform simplification incrementally
*)
and mkAndType f1 f2 = match f1 with
  | TypeTrue -> f2
  | TypeFalse -> TypeFalse
  | _ -> begin
	  match f2 with
		| TypeTrue -> f1
		| TypeFalse -> TypeFalse
		| _ -> TypeAnd ({t_formula_and_f1 = f1; t_formula_and_f2 = f2})
	end

and mkTrue pos = Base ({formula_base_heap = HTrue; 
						formula_base_pure = CP.mkTrue pos; 
						formula_base_type = TypeTrue; 
						formula_base_pos = pos})

and mkFalse pos = Base ({formula_base_heap = HFalse; 
						 formula_base_pure = CP.mkFalse pos; 
						 formula_base_type = TypeFalse;
						 formula_base_pos = pos})

and mkOr f1 f2 pos =
  if isConstTrue f1 || isConstTrue f2 then
	mkTrue pos
  else if isConstFalse f1 then f2
  else if isConstFalse f2 then f1
  else Or ({formula_or_f1 = f1; formula_or_f2 = f2; formula_or_pos = pos})

and mkBase (h : h_formula) (p : CP.formula) (t : t_formula) (pos : loc) = 
  if CP.isConstFalse p || h = HFalse then 
	mkFalse pos
  else 
	Base ({formula_base_heap = h; 
		   formula_base_pure = p; 
		   formula_base_type = t;
		   formula_base_pos = pos})
	  
and mkStarH (f1 : h_formula) (f2 : h_formula) (pos : loc) = match f1 with
  | HFalse -> HFalse
  | HTrue -> f2
  | _ -> match f2 with
	  | HFalse -> HFalse
	  | HTrue -> f1
	  | _ -> Star ({h_formula_star_h1 = f1; 
					h_formula_star_h2 = f2; 
					h_formula_star_pos = pos})

let rec mkStar (f1 : formula) (f2 : formula) (pos : loc) =
  let h1, p1, t1 = split_components f1 in
  let h2, p2, t2 = split_components f2 in
  let h = mkStarH h1 h2 pos in
  let p = CP.mkAnd p1 p2 pos in
  let t = mkAndType t1 t2 in
	mkBase h p t pos

and mkExists (svs : CP.spec_var list) (h : h_formula) (p : CP.formula) (t : t_formula) (pos : loc) =
  let tmp = Base ({formula_base_heap = h; 
				   formula_base_pure = p; 
				   formula_base_type = t;
				   formula_base_pos = pos}) in
  let fvars = fv tmp in
  let qvars = U.intersect svs fvars in (* used only these for the quantified formula *)
	if U.empty qvars then
	  tmp
	else
	  Exists ({formula_exists_qvars = qvars; 
			   formula_exists_heap =  h; 
			   formula_exists_pure = p;
			   formula_exists_type = t;
			   formula_exists_pos = pos})

and is_view (h : h_formula) = match h with
  | ViewNode _ -> true
  | _ -> false

and is_data (h : h_formula) = match h with
  | DataNode _ -> true
  | _ -> false

and get_node_name (h : h_formula) = match h with
  | ViewNode ({h_formula_view_name = c}) 
  | DataNode ({h_formula_data_name = c}) -> c
  | _ -> failwith ("get_node_name: invalid argument")

and get_view_origins (h : h_formula) = match h with
  | ViewNode ({h_formula_view_origins = origs}) -> origs
  | _ -> failwith ("get_view_origins: not a view")

and get_view_modes (h : h_formula) = match h with
  | ViewNode ({h_formula_view_modes = modes}) -> modes
  | _ -> failwith ("get_view_modes: not a view")

and h_add_origins (h : h_formula) origs = match h with
  | Star ({h_formula_star_h1 = h1;
		   h_formula_star_h2 = h2;
		   h_formula_star_pos = pos}) ->
	  Star ({h_formula_star_h1 = h_add_origins h1 origs;
			 h_formula_star_h2 = h_add_origins h2 origs;
			 h_formula_star_pos = pos})
  | ViewNode vn -> ViewNode {vn with h_formula_view_origins = origs @ vn.h_formula_view_origins}
  | _ -> h

and add_origins (f : formula) origs = match f with
  | Or ({formula_or_f1 = f1;
		 formula_or_f2 = f2;
		 formula_or_pos = pos}) -> 
	  Or ({formula_or_f1 = add_origins f1 origs;
		 formula_or_f2 = add_origins f2 origs ;
		 formula_or_pos = pos})
  | Base b -> Base ({b with formula_base_heap = h_add_origins b.formula_base_heap origs})
  | Exists e -> Exists ({e with formula_exists_heap = h_add_origins e.formula_exists_heap origs})

and no_change (svars : CP.spec_var list) (pos : loc) : CP.formula = match svars with
  | sv :: rest ->
	  let f = CP.mkEqVar (CP.to_primed sv) (CP.to_unprimed sv) pos in
	  let restf = no_change rest pos in
		CP.mkAnd f restf pos
  | [] -> CP.mkTrue pos

and pos_of_formula (f : formula) : loc = match f with
  | Base ({formula_base_pos = pos}) -> pos
  | Or ({formula_or_pos = pos}) -> pos
  | Exists ({formula_exists_pos = pos}) -> pos


and fv (f : formula) : CP.spec_var list = match f with
  | Or ({formula_or_f1 = f1; 
		 formula_or_f2 = f2}) -> Util.remove_dups (fv f1 @ fv f2)
  | Base ({formula_base_heap = h; 
		   formula_base_pure = p;
		   formula_base_type = t}) -> 
	  Util.remove_dups (h_fv h @ CP.fv p)
	  (* Util.remove_dups (h_fv h @ CP.fv p @ t_fv t) *)
  | Exists ({formula_exists_qvars = qvars; 
			 formula_exists_heap = h; 
			 formula_exists_pure = p; 
			 formula_exists_type = t;
			 formula_exists_pos = pos}) -> 
	  let fvars = fv (Base ({formula_base_heap = h; 
							 formula_base_pure = p; 
							 formula_base_type = t;
							 formula_base_pos = pos})) in
	  let res = CP.difference fvars qvars in
		res

and t_fv (t : t_formula) : CP.spec_var list = match t with
  | TypeAnd ({t_formula_and_f1 = f1; t_formula_and_f2 = f2}) ->
	  Util.remove_dups (t_fv f1 @ t_fv f2)
  | TypeExact ({t_formula_sub_type_var = v})
  | TypeSuper ({t_formula_sub_type_var = v})
  | TypeSub ({t_formula_sub_type_var = v}) -> [v]
  | TypeTrue | TypeFalse -> []

and h_fv (h : h_formula) : CP.spec_var list = match h with
  | Star ({h_formula_star_h1 = h1; 
		   h_formula_star_h2 = h2; 
		   h_formula_star_pos = pos}) -> Util.remove_dups (h_fv h1 @ h_fv h2)
  | DataNode ({h_formula_data_node = v; 
			   h_formula_data_arguments = vs0}) ->
	  let vs = List.tl (List.tl vs0) in
		if List.mem v vs then vs else v :: vs
  | ViewNode ({h_formula_view_node = v; 
			   h_formula_view_arguments = vs}) -> if List.mem v vs then vs else v :: vs
  | HTrue | HFalse -> []

and top_level_vars (h : h_formula) : CP.spec_var list = match h with
  | Star ({h_formula_star_h1 = h1; 
		   h_formula_star_h2 = h2}) -> (top_level_vars h1) @ (top_level_vars h2)
  | DataNode ({h_formula_data_node = v}) 
  | ViewNode ({h_formula_view_node = v}) -> [v]
  | HTrue | HFalse -> []

and get_formula_pos (f : formula) = match f with
  | Base ({formula_base_pos = p}) -> p
  | Or ({formula_or_pos = p}) -> p
  | Exists ({formula_exists_pos = p}) -> p 


(* substitution *)

and subst_avoid_capture (fr : CP.spec_var list) (t : CP.spec_var list) (f : formula) =
  let fresh_fr = CP.fresh_spec_vars fr in
  let st1 = List.combine fr fresh_fr in
  let st2 = List.combine fresh_fr t in
  let f1 = subst st1 f in
  let f2 = subst st2 f1 in
	f2

(*
and subst_var_list_avoid_capture fr t svs = 
  let fresh_fr = fresh_spec_vars fr in
  let st1 = List.combine fr fresh_fr in
  let st2 = List.combine fresh_fr t in
  let svs1 = subst_var_list st1 svs in
  let svs2 = subst_var_list st2 svs1 in
	svs2

and subst_var_list sst (svs : spec_var list) = match svs with
  | [] -> []
  | sv :: rest ->
      let new_vars = subst_var_list sst rest in
      let new_sv = match List.filter (fun st -> fst st = sv) sst with
		| [(fr, t)] -> t
		| _ -> sv in
		new_sv :: new_vars
*)

and subst sst (f : formula) = match sst with
  | s :: rest -> subst rest (apply_one s f)
  | [] -> f 
      
and subst_var (fr, t) (o : CP.spec_var) = if CP.eq_spec_var fr o then t else o

and apply_one ((fr, t) as s : (CP.spec_var * CP.spec_var)) (f : formula) = match f with
  | Or ({formula_or_f1 = f1; formula_or_f2 = f2; formula_or_pos = pos}) -> 
      Or ({formula_or_f1 = apply_one s f1; formula_or_f2 =  apply_one s f2; formula_or_pos = pos})
  | Base ({formula_base_heap = h; 
		   formula_base_pure = p; 
		   formula_base_type = t;
		   formula_base_pos = pos}) -> 
      Base ({formula_base_heap = h_apply_one s h; 
			 formula_base_pure = CP.apply_one s p; 
			 formula_base_type = t_apply_one s t;
			 formula_base_pos = pos})
  | Exists ({formula_exists_qvars = qsv; 
			 formula_exists_heap = qh; 
			 formula_exists_pure = qp; 
			 formula_exists_type = tconstr;
			 formula_exists_pos = pos}) -> 
	  if List.mem (CP.name_of_spec_var fr) (List.map CP.name_of_spec_var qsv) then f 
	  else Exists ({formula_exists_qvars = qsv; 
					formula_exists_heap =  h_apply_one s qh; 
					formula_exists_pure = CP.apply_one s qp; 
					formula_exists_type = t_apply_one s tconstr;
					formula_exists_pos = pos})
		

and t_apply_one ((fr, t) as s : (CP.spec_var * CP.spec_var)) (f : t_formula) = match f with
  | TypeExact ({t_formula_sub_type_var = tv;
				t_formula_sub_type_type = c}) ->
	  if CP.eq_spec_var tv fr then
		TypeExact ({t_formula_sub_type_var = t;
				   t_formula_sub_type_type = c})
	  else
		f
  | TypeSub  ({t_formula_sub_type_var = tv;
				t_formula_sub_type_type = c}) ->
	  if CP.eq_spec_var tv fr then
		TypeSub ({t_formula_sub_type_var = t;
				 t_formula_sub_type_type = c})
	  else
		f
  | TypeSuper  ({t_formula_sub_type_var = tv;
				 t_formula_sub_type_type = c}) ->
	  if CP.eq_spec_var tv fr then
		TypeSuper ({t_formula_sub_type_var = t;
					t_formula_sub_type_type = c})
	  else
		f
  | TypeAnd ({t_formula_and_f1 = f1;
			  t_formula_and_f2 = f2}) ->
	  TypeAnd ({t_formula_and_f1 = t_apply_one s f1;
				t_formula_and_f2 = t_apply_one s f2})
  | TypeTrue | TypeFalse -> f

and h_apply_one ((fr, t) as s : (CP.spec_var * CP.spec_var)) (f : h_formula) = match f with
  | Star ({h_formula_star_h1 = f1; 
		   h_formula_star_h2 = f2; 
		   h_formula_star_pos = pos}) -> 
      Star ({h_formula_star_h1 = h_apply_one s f1; 
			 h_formula_star_h2 = h_apply_one s f2; 
			 h_formula_star_pos = pos})
  | ViewNode ({h_formula_view_node = x; 
			   h_formula_view_name = c; 
			   h_formula_view_arguments = svs; 
			   h_formula_view_modes = modes;
			   h_formula_view_coercible = coble;
			   h_formula_view_origins = orgs;
			   h_formula_view_pos = pos}) -> 
      ViewNode ({h_formula_view_node = subst_var s x; 
				 h_formula_view_name = c; 
				 h_formula_view_arguments = List.map (subst_var s) svs;
				 h_formula_view_modes = modes;
				 h_formula_view_coercible = coble;
				 h_formula_view_origins = orgs;
				 h_formula_view_pos = pos})
  | DataNode ({h_formula_data_node = x; 
			   h_formula_data_name = c; 
			   h_formula_data_arguments = svs; 
			   h_formula_data_pos = pos}) -> 
      DataNode ({h_formula_data_node = subst_var s x; 
				 h_formula_data_name = c; 
				 h_formula_data_arguments = List.map (subst_var s) svs;
				 h_formula_data_pos = pos})
  | HTrue -> f
  | HFalse -> f

(* normalization *)

(* normalizes ( \/ (EX v* . /\ ) ) * ( \/ (EX v* . /\ ) ) *)
and normalize (f1 : formula) (f2 : formula) (pos : loc) = match f1 with
  | Or ({formula_or_f1 = o11; formula_or_f2 = o12; formula_or_pos = _}) ->
      let eo1 = normalize o11 f2 pos in
      let eo2 = normalize o12 f2 pos in
		mkOr eo1 eo2 pos
  | _ -> begin
      match f2 with
		| Or ({formula_or_f1 = o21; formula_or_f2 = o22; formula_or_pos = _}) ->
			let eo1 = normalize f1 o21 pos in
			let eo2 = normalize f1 o22 pos in
			  mkOr eo1 eo2 pos
		| _ -> begin
			let rf1 = rename_bound_vars f1 in
			let rf2 = rename_bound_vars f2 in
			let qvars1, base1 = split_quantifiers rf1 in
			let qvars2, base2 = split_quantifiers rf2 in
			let new_base = mkStar base1 base2 pos in
			let new_h, new_p, new_t = split_components new_base in
			let resform = mkExists (qvars1 @ qvars2) new_h new_p new_t pos in (* qvars[1|2] are fresh vars, hence no duplications *)
			  resform
		  end
    end

(* split a conjunction into heap constraints, pure pointer constraints, *)
(* and Presburger constraints *)
and split_components (f : formula) = match f with
  | Base ({formula_base_heap = h; 
		   formula_base_pure = p; 
		   formula_base_type = t}) -> (h, p, t)
  | Exists ({formula_exists_pos = pos}) -> 
      Err.report_error {Err.error_loc = pos;
						Err.error_text = "split_components: don't expect EXISTS"}
  | Or ({formula_or_pos = pos}) -> 
      Err.report_error {Err.error_loc = pos;
						Err.error_text = "split_components: don't expect OR"}

and split_quantifiers (f : formula) : (CP.spec_var list * formula) = match f with
  | Exists ({formula_exists_qvars = qvars; 
			 formula_exists_heap =  h; 
			 formula_exists_pure = p; 
			 formula_exists_type = t;
			 formula_exists_pos = pos}) -> 
      (qvars, mkBase h p t pos)
  | Base _ -> ([], f)
  | _ -> failwith ("split_quantifiers: invalid argument")

and add_quantifiers (qvars : CP.spec_var list) (f : formula) : formula = match f with
  | Base ({formula_base_heap = h; 
		   formula_base_pure = p; 
		   formula_base_type = t; 
		   formula_base_pos = pos}) -> mkExists qvars h p t pos
  | Exists ({formula_exists_qvars = qvs; 
			 formula_exists_heap = h; 
			 formula_exists_pure = p; 
			 formula_exists_type = t;
			 formula_exists_pos = pos}) -> 
	  let new_qvars = U.remove_dups (qvs @ qvars) in
		mkExists new_qvars h p t pos
  | _ -> failwith ("add_quantifiers: invalid argument")

and push_exists (qvars : CP.spec_var list) (f : formula) = match f with
  | Or ({formula_or_f1 = f1; formula_or_f2 = f2; formula_or_pos = pos}) -> 
	  let new_f1 = push_exists qvars f1 in
	  let new_f2 = push_exists qvars f2 in
	  let resform = mkOr new_f1 new_f2 pos in
		resform
  | _ -> add_quantifiers qvars f

and rename_bound_vars (f : formula) = match f with
  | Or ({formula_or_f1 = f1; formula_or_f2 = f2; formula_or_pos = pos}) ->
	  let rf1 = rename_bound_vars f1 in
	  let rf2 = rename_bound_vars f2 in
	  let resform = mkOr rf1 rf2 pos in
		resform
  | Base _ -> f
  | Exists _ ->
	  let qvars, base_f = split_quantifiers f in
	  let new_qvars = CP.fresh_spec_vars qvars in
	  let rho = List.combine qvars new_qvars in
	  let new_base_f = subst rho base_f in
	  let resform = add_quantifiers new_qvars new_base_f in
		resform


(* composition operator: it suffices to define composition in terms of  *)
(* the * operator, as the & operator is just a special case when one of *)
(* the term is pure                                                     *)

and compose_formula (delta : formula) (phi : formula) (x : CP.spec_var list) (pos : loc) =
  let rs = CP.fresh_spec_vars x in
  let rho1 = List.combine (List.map CP.to_unprimed x) rs in
  let rho2 = List.combine (List.map CP.to_primed x) rs in
  let new_delta = subst rho2 delta in
  let new_phi = subst rho1 phi in
  let new_f = normalize new_delta new_phi pos in
  let resform = push_exists rs new_f in
	resform


(*
  Other utilities.
*)

and disj_count (f0 : formula) = match f0 with
  | Or ({formula_or_f1 = f1;
		 formula_or_f2 = f2}) ->
	  let c1 = disj_count f1 in
	  let c2 = disj_count f2 in
		1 + c1 + c2

  | _ -> 1

(* context functions *)

type entail_state = {
  es_formula : formula; (* can be any formula *)
  es_heap : h_formula; (* consumed nodes *)
  es_pure : CP.formula;
  es_evars : CP.spec_var list;
  es_ante_evars : CP.spec_var list;
  es_pp_subst : (CP.spec_var * CP.spec_var) list;
  es_arith_subst : (CP.spec_var * CP.exp) list
}

and context = 
  | Ctx of entail_state
  | OCtx of (context * context) (* disjunctive context *)


let empty_es pos = {
  es_formula = mkTrue pos;
  es_heap = HTrue;
  es_pure = CP.mkTrue pos;
  es_evars = [];
  es_ante_evars = [];
  es_pp_subst = [];
  es_arith_subst = []
}

let empty_ctx pos = Ctx (empty_es pos)

let false_ctx pos = Ctx ({(empty_es pos) with es_formula = mkFalse pos})

let true_ctx pos = Ctx ({(empty_es pos) with es_formula = mkTrue pos})

let isFalseCtx ctx = match ctx with
  | Ctx es -> isConstFalse es.es_formula
  | _ -> false

let isTrueCtx ctx = match ctx with
  | Ctx es -> isConstTrue es.es_formula
  | _ -> false

let rec build_context ctx f pos = match f with
  | Base _ | Exists _ -> 
	  let es = estate_of_context ctx pos in
		Ctx ({es with es_formula = f})
  | Or ({formula_or_f1 = f1; formula_or_f2 = f2; formula_or_pos = _}) -> 
	  let c1 = build_context ctx f1 pos in
	  let c2 = build_context ctx f2 pos in
		or_context c1 c2

and set_context_formula (ctx : context) (f : formula) : context = match ctx with
  | Ctx es -> begin
	  match f with
		| Or ({formula_or_f1 = f1; formula_or_f2 = f2; formula_or_pos = pos}) ->
			let cf1 = set_context_formula ctx f1 in
			let cf2 = set_context_formula ctx f2 in
			  OCtx (cf1, cf2)
		| _ -> Ctx {es with es_formula = f}
	end
  | OCtx (c1, c2) ->
	  let nc1 = set_context_formula c1 f in
	  let nc2 = set_context_formula c2 f in
		OCtx (nc1, nc2)

(*
  to be used in the type-checker. After every entailment, the history of consumed nodes
  must be cleared.
*)
and clear_entailment_history (ctx : context) : context = match ctx with
  | Ctx es -> (* Ctx {es with es_heap = HTrue} *)
	  Ctx {(empty_es no_pos) with es_formula = es.es_formula }
  | OCtx (c1, c2) ->
	  let nc1 = clear_entailment_history c1 in
	  let nc2 = clear_entailment_history c2 in
	  let res = OCtx (nc1, nc2) in
		res

and clear_entailment_history_list (ctx : context list) : context list = 
  List.map (fun c -> clear_entailment_history c) ctx

and or_context_list (cl10 : context list) (cl20 : context list) : context list = 
  let rec helper cl1 cl2 = match cl1 with
	| c1 :: rest ->
		let tmp1 = or_context_list rest cl2 in
		let tmp2 = List.map (or_context c1) cl2 in
		  tmp2 @ tmp1 
	| [] -> []
  in
	if Util.empty cl20 then
	  []
	else
	  let tmp = helper cl10 cl20 in
		tmp
			
and or_context c1 c2 = match c1 with
  | Ctx {es_formula = Base ({formula_base_heap = HFalse; 
							 formula_base_pure = _; 
							 formula_base_pos = _})} -> c2
  | Ctx {es_formula = Base ({formula_base_heap = HTrue; 
							 formula_base_pure = CP.BForm (CP.BConst (true, _)); 
							 formula_base_pos = _})} -> c1
  | _ -> match c2 with 
	  | Ctx {es_formula = Base ({formula_base_heap = HFalse; 
								 formula_base_pure = _; 
								 formula_base_pos = _})} -> c1
	  | Ctx {es_formula = Base ({formula_base_heap = HTrue; 
								 formula_base_pure =  CP.BForm (CP.BConst (true, _)); 
								 formula_base_pos = _})} -> c2
	  | _ -> OCtx (c1, c2)

and estate_of_context (ctx : context) (pos : loc) = match ctx with
  | Ctx es -> es
  | _ -> Err.report_error {Err.error_loc = pos;
						   Err.error_text = "estate_of_context: disjunctive context"}

(* simplication and manipulation *)

and push_exists_context (qvars : CP.spec_var list) (ctx : context) : context = match ctx with
  | Ctx es -> Ctx {es with es_formula = push_exists qvars es.es_formula}
  | OCtx (c1, c2) -> OCtx (push_exists_context qvars c1, push_exists_context qvars c2)

and compose_context_formula (ctx : context) (phi : formula) (x : CP.spec_var list) (pos : loc) : context = match ctx with
  | Ctx es -> begin
	  match phi with
		| Or ({formula_or_f1 = phi1; formula_or_f2 =  phi2; formula_or_pos = _}) ->
			let new_c1 = compose_context_formula ctx phi1 x pos in
			let new_c2 = compose_context_formula ctx phi2 x pos in
			let res = OCtx (new_c1, new_c2) in
			  res
		| _ -> Ctx {es with es_formula = compose_formula es.es_formula phi x pos}
	end
  | OCtx (c1, c2) -> 
	  let new_c1 = compose_context_formula c1 phi x pos in
	  let new_c2 = compose_context_formula c2 phi x pos in
	  let res = OCtx (new_c1, new_c2) in
		res

and normalize_context_formula (ctx : context) (f : formula) (pos : loc) : context = match ctx with
  | Ctx es -> Ctx {es with es_formula = normalize es.es_formula f pos}
  | OCtx (c1, c2) ->
	  let nc1 = normalize_context_formula c1 f pos in
	  let nc2 = normalize_context_formula c2 f pos in
	  let res = OCtx (nc1, nc2) in
		res

and formula_of_context ctx0 = match ctx0 with
  | OCtx (c1, c2) ->
	  let f1 = formula_of_context c1 in
	  let f2 = formula_of_context c2 in
		mkOr f1 f2 no_pos
  | Ctx es -> es.es_formula

and disj_count_ctx (ctx0 : context) = match ctx0 with
  | OCtx (c1, c2) ->
	  let t1 = disj_count_ctx c1 in
	  let t2 = disj_count_ctx c2 in
		1 + t1 + t2
  | Ctx es -> disj_count es.es_formula

and find_type_var (tc : h_formula) (v : ident) : CP.spec_var option = match tc with
  | Star ({h_formula_star_h1 = h1;
		   h_formula_star_h2 = h2}) -> begin
	  let tmp1 = find_type_var h1 v in
		match tmp1 with
		  | Some _ -> tmp1
		  | None -> find_type_var h2 v
	end
  | DataNode ({h_formula_data_arguments = args}) -> Some (List.hd args)
  | ViewNode _ | HTrue | HFalse -> None

(* order nodes in topological order *)

module Node = struct
  type t = h_formula
  let compare = compare
  let hash = Hashtbl.hash
  let equal = (=)
end

module NG = Graph.Imperative.Digraph.Concrete(Node)
module TopoNG = Graph.Topological.Make(NG)

(*
  return the same formula with nodes rearranged in topological
  order based on the points-to relation of the heap nodes.
*)
(*
let topologize_formula (h0 : h_formula) : h_formula =
  let g = NG.create () in
*)
