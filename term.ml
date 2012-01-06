module CP = Cpure
module CF = Cformula
module MCP = Mcpure
module DD = Debug
module TP = Tpdispatcher
open Gen.Basic
open Globals
open Cprinter

type phase_trans = int * int

(* Transition on termination annotation with measures (if any) *)
type term_ann_trans = (term_ann * CP.exp list) * (term_ann * CP.exp list)

(* Transition on program location 
 * src: post_pos
 * dst: proving_loc *)
type term_trans_loc = loc * loc 

type term_reason =
  (* The variance is not well-founded *)
  | Not_Decreasing_Measure     
  | Not_Bounded_Measure
  (* The variance is well-founded *)
  | Valid_Measure  
  | Decreasing_Measure
  | Bounded_Measure
  (* Reachability *)
  | Base_Case_Reached
  | Non_Term_Reached
  (* Reason for error *)
  | Invalid_Phase_Trans
  | Variance_Not_Given
  | Invalid_Status_Trans of term_ann_trans

(* The termination can only be determined when 
 * a base case or an infinite loop is reached *)  
type term_status =
  | Term_S of term_reason
  | NonTerm_S of term_reason
  | MayTerm_S of term_reason
  | Unreachable 
  | TermErr of term_reason

(* Location of the transition (from spec to call),
 * Termination Annotation transition,
 * Context and 
 * Its termination status *)
type term_res = term_trans_loc * term_ann_trans option * CF.formula option * term_status

(* Using stack to store term_res *)
let term_res_stk : term_res Gen.stack = new Gen.stack

(* Printing Utilities *)
let pr_phase_trans (trans: phase_trans) =
  let (src, dst) = trans in
  fmt_string "Transition ";
  pr_int src; fmt_string "->"; pr_int dst

let string_of_phase_trans (trans: phase_trans) = 
  poly_string_of_pr pr_phase_trans trans

let pr_term_ann_trans ((ann_s, m_s), (ann_d, m_d)) =
  fmt_open_hbox();
  fmt_string (string_of_term_ann ann_s);
  pr_seq "" pr_formula_exp m_s;
  fmt_string "->";
  fmt_string (string_of_term_ann ann_d);
  pr_seq "" pr_formula_exp m_d;
  fmt_close_box()

let string_of_term_ann_trans = poly_string_of_pr pr_term_ann_trans 

let pr_term_reason = function
  | Not_Decreasing_Measure -> fmt_string "The variance is not well-founded (not decreasing)."
  | Not_Bounded_Measure -> fmt_string "The variance is not well-founded (not bounded)."
  | Valid_Measure -> fmt_string "The given variance is well-founded."
  | Decreasing_Measure -> fmt_string "The variance is decreasing."
  | Bounded_Measure -> fmt_string "The variance is bounded."
  | Base_Case_Reached -> fmt_string "The base case is reached."
  | Non_Term_Reached -> fmt_string "A non-terminating state is reached."
  | Invalid_Phase_Trans -> fmt_string "The phase transition number is invalid."
  | Invalid_Status_Trans trans -> 
      pr_term_ann_trans trans;
      fmt_string " transition is invalid."
  | Variance_Not_Given -> 
      fmt_string "The recursive case needs a given/inferred variance for termination proof."
			
let pr_term_reason_short = function
	| Not_Decreasing_Measure -> fmt_string "not decreasing"
	| Not_Bounded_Measure -> fmt_string "not bounded"
	| _ -> ()

let string_of_term_reason (reason: term_reason) =
  poly_string_of_pr pr_term_reason reason

let pr_term_status = function
  | Term_S reason -> fmt_string "Terminating: "; pr_term_reason reason
  | NonTerm_S reason -> fmt_string "Non-terminating: "; pr_term_reason reason
  | MayTerm_S reason -> fmt_string "May-terminating: "; pr_term_reason reason
  | Unreachable -> fmt_string "Unreachable state."
  | TermErr reason -> fmt_string "Error: "; pr_term_reason reason

let pr_term_status_short = function
  | Term_S _ -> fmt_string "(OK)"
  | Unreachable -> fmt_string "(UNR)"
  | MayTerm_S r -> 
      fmt_string "(ERR: ";
      pr_term_reason_short r;
      fmt_string ")"
  | _ -> fmt_string "(ERR)"

let string_of_term_status = poly_string_of_pr pr_term_status

let pr_term_ctx (ctx: CF.formula) =
  let h_f, p_f, _, _, _ = CF.split_components ctx in
  begin
    fmt_string "Current context";
    fmt_print_newline ();
    pr_wrap_test "heap: " CF.is_true pr_h_formula h_f;
    pr_wrap_test "pure: " MCP.isConstMTrue pr_mix_formula p_f;
    fmt_print_newline ();
  end 

let string_of_term_ctx = poly_string_of_pr pr_term_ctx

let pr_term_trans_loc (src, dst) =
  let fname = src.start_pos.Lexing.pos_fname in
  let src_line = src.start_pos.Lexing.pos_lnum in
  let dst_line = dst.start_pos.Lexing.pos_lnum in
  (* fmt_string (fname ^ " "); *)
  fmt_string ("(" ^ (string_of_int src_line) ^ ")");
  fmt_string ("->");
  fmt_string ("(" ^ (string_of_int dst_line) ^ ")")

let pr_term_res pr_ctx (pos, ann_trans, ctx, status) =
  pr_term_trans_loc pos;
  fmt_string " ";
  pr_term_status_short status;
  fmt_string " ";
  (match ann_trans with
  | None -> ()
  | Some trans -> pr_term_ann_trans trans);
  (match ctx with
  | None -> ();
  | Some c -> if pr_ctx then (fmt_string ": "; pr_term_ctx c) else (););
  (*
  if pr_ctx then fmt_string ">>>>> " else fmt_string ": ";
  pr_term_status status;
  *)
  if pr_ctx then fmt_print_newline () else ()

let string_of_term_res = poly_string_of_pr (pr_term_res false)

let pr_term_res_stk stk =
  let stk =
    let (err, ok) = List.partition (fun (_, _, _, status) ->
      match status with
      | Term_S _
      | Unreachable -> false
      | _ -> true
    ) stk in
    if (!Globals.term_verbosity == 0) then err@ok
    else err
  in 
  List.iter (fun r -> 
    pr_term_res !Debug.devel_debug_on r; 
    fmt_print_newline ();) stk

let term_check_output stk =
  fmt_string "\nTermination checking result:\n";
  pr_term_res_stk (stk # get_stk);
  fmt_print_newline ()
 
(* End of Printing Utilities *)

(* To find a LexVar formula *)
exception LexVar_Not_found;;
exception Invalid_Phase_Num;;

let find_lexvar_b_formula (bf: CP.b_formula) : (term_ann * CP.exp list * CP.exp list) =
  let (pf, _) = bf in
  match pf with
  | CP.LexVar (t_ann, el, il, _) -> (t_ann, el, il)
  | _ -> raise LexVar_Not_found

let rec find_lexvar_formula (f: CP.formula) : (term_ann * CP.exp list * CP.exp list) =
  match f with
  | CP.BForm (bf, _) -> find_lexvar_b_formula bf
  | CP.And (f1, f2, _) ->
      (try find_lexvar_formula f1
      with _ -> find_lexvar_formula f2)
  | _ -> raise LexVar_Not_found

(* To syntactically simplify LexVar formula *) 
(* (false,[]) means not decreasing *)
let rec syn_simplify_lexvar bnd_measures =
  match bnd_measures with
  (* 2 measures are identical, 
   * so that they are not decreasing *)
  | [] -> (false, [])   
  | (s,d)::rest -> 
      if (CP.eqExp s d) then syn_simplify_lexvar rest
      else if (CP.is_gt CP.eq_spec_var s d) then (true, [])
      else if (CP.is_lt CP.eq_spec_var s d) then (false, [])
      else (true, bnd_measures) 

let find_lexvar_es (es: CF.entail_state) : 
  (term_ann * CP.exp list * CP.exp list) =
  match es.CF.es_var_measures with
  | None -> raise LexVar_Not_found
  | Some (t_ann, el, il) -> (t_ann, el, il)

(* Normalize the longer LexVar prior to the shorter one *)
let norm_term_measures_by_length src dst =
  let sl = List.length src in
  let dl = List.length dst in
  if dl==0 && sl>0 then None
  else
    if (sl = dl) then Some (src, dst)
    else if (sl > dl) then
      Some (Gen.BList.take dl src, dst)
    else Some (src, Gen.BList.take sl dst)

let strip_lexvar_mix_formula (mf: MCP.mix_formula) =
  let mf_p = MCP.pure_of_mix mf in
  let mf_ls = CP.split_conjunctions mf_p in
  let (lexvar, other_p) = List.partition (CP.is_lexvar) mf_ls in
  (lexvar, CP.join_conjunctions other_p)

(* Termination: The boundedness checking for HIP has been done before *)  
let check_term_measures estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p src_lv dst_lv t_ann_trans pos =
  let ans  = norm_term_measures_by_length src_lv dst_lv in
  let term_pos = (post_pos # get, proving_loc # get) in
  match ans with
      (* From primitive calls - 
       * Do not need to add messages to stack *)
    | None -> (estate, lhs_p, rhs_p, None)     
    | Some (src_lv, dst_lv) ->
        (* TODO : Let us assume Term[] is for base-case
           and primitives. In the case of non-primitive,
           it will be converted to Term[call] using
           the call hierarchy. No need for Term[-1]
           and some code dealing with primitives below *)
        let orig_ante = estate.CF.es_formula in
        (* [s1,s2] |- [d1,d2] -> [(s1,d1), (s2,d2)] *)
        let bnd_measures = List.map2 (fun s d -> (s, d)) src_lv dst_lv in
        (* [(0,0), (s2,d2)] -> [(s2,d2)] *)
        let res, bnd_measures = syn_simplify_lexvar bnd_measures in
        if bnd_measures = [] then 
          let t_ann, ml, il = find_lexvar_es estate in
          (* Residue of the termination,
           * The termination checking result - For HIP (stored in term_res_stk)
           * The stack of error - For SLEEK *)
          let term_measures, term_res, term_stack =
            if res then (* The measures are decreasing *)
              Some (t_ann, ml, il), (* Residue of termination *)
              (term_pos, t_ann_trans, Some orig_ante, Term_S Valid_Measure),
              estate.CF.es_var_stack
            else 
              Some (Fail TermErr_May, ml, il),
              (term_pos, t_ann_trans, Some orig_ante, MayTerm_S Not_Decreasing_Measure),
              (string_of_term_res (term_pos, t_ann_trans, None, TermErr Not_Decreasing_Measure))::estate.CF.es_var_stack 
          in
          let n_estate = { estate with
            CF.es_var_measures = term_measures;
            CF.es_var_stack = term_stack 
          } in
          term_res_stk # push term_res;
          (n_estate, lhs_p, rhs_p, None)
        else
          (* [(s1,d1), (s2,d2)] -> [[(s1,d1)], [(s1,d1),(s2,d2)]]*)
          let lst_measures = List.fold_right (fun bm res ->
            [bm]::(List.map (fun e -> bm::e) res)) bnd_measures [] in
          (* [(s1,d1),(s2,d2)] -> s1=d1 & s2>d2 *)
          let lex_formula measure = snd (List.fold_right (fun (s,d) (flag,res) ->
            let f = 
		          if flag then CP.BForm ((CP.mkGt s d pos, None), None) (* s>d *)
			        else CP.BForm ((CP.mkEq s d pos, None), None) in (* s=d *)
                (false, CP.mkAnd f res pos)) measure (true, CP.mkTrue pos)) in
          let rank_formula = List.fold_left (fun acc m ->
            CP.mkOr acc (lex_formula m) None pos) (CP.mkFalse pos) lst_measures in
          let lhs = MCP.pure_of_mix (MCP.merge_mems lhs_p xpure_lhs_h1 true) in
          let entail_res, _, _ = TP.imply lhs rank_formula "" false None in 
          begin
            (* print_endline ">>>>>> trans_lexvar_rhs <<<<<<" ; *)
            (* print_endline ("Transformed RHS: " ^ (Cprinter.string_of_mix_formula rhs_p)) ; *)
            DD.devel_zprint (lazy (">>>>>> [term.ml][trans_lexvar_rhs] <<<<<<")) pos;
            DD.devel_zprint (lazy ("Transformed RHS: " ^ (Cprinter.string_of_mix_formula rhs_p))) pos;
            DD.devel_zprint (lazy ("LHS (lhs_p): " ^ (Cprinter.string_of_mix_formula lhs_p))) pos;
            DD.devel_zprint (lazy ("LHS (xpure 0): " ^ (Cprinter.string_of_mix_formula xpure_lhs_h0))) pos;
            DD.devel_zprint (lazy ("LHS (xpure 1): " ^ (Cprinter.string_of_mix_formula xpure_lhs_h1))) pos;
            DD.devel_zprint (lazy ("Wellfoundedness checking: " ^ (string_of_bool entail_res))) pos;
          end;
          let t_ann, ml, il = find_lexvar_es estate in
          let term_measures, term_res, term_stack, rank_formula =
            if entail_res then (* Decreasing *) 
              Some (t_ann, ml, il), 
              (term_pos, t_ann_trans, Some orig_ante, Term_S Valid_Measure),
              estate.CF.es_var_stack, 
              None
            else
              if estate.CF.es_infer_vars = [] then (* No inference *)
                Some (Fail TermErr_May, ml, il),
                (term_pos, t_ann_trans, Some orig_ante, MayTerm_S Not_Decreasing_Measure),
                (string_of_term_res (term_pos, t_ann_trans, None, TermErr Not_Decreasing_Measure))::estate.CF.es_var_stack,
                None
              else
                (* Inference: the es_var_measures will be
                 * changed based on the result of inference 
                 * The term_res_stk and es_var_stack 
                 * should be updated based on this result: 
                 * MayTerm_S -> Term_S *)
								(* Assumming Inference will be successed *)
                Some (t_ann, ml, il),
                (term_pos, t_ann_trans, Some orig_ante, Term_S Valid_Measure),
                estate.CF.es_var_stack, 
                Some rank_formula  
          in 
          let n_estate = { estate with
            CF.es_var_measures = term_measures;
            CF.es_var_stack = term_stack; 
          } in
          term_res_stk # push term_res;
          (n_estate, lhs_p, rhs_p, rank_formula)

(* To handle LexVar formula *)
(* Remember to remove LexVar in RHS *)
let check_term_rhs estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p pos =
  try
    begin
      let _ = DD.trace_hprint (add_str "es: " !CF.print_entail_state) estate pos in
      let term_pos = (post_pos # get, proving_loc # get) in
      let conseq = MCP.pure_of_mix rhs_p in
      let t_ann_d, dst_lv, _ = find_lexvar_formula conseq in (* [d1,d2] *)
      let t_ann_s, src_lv, src_il = find_lexvar_es estate in
      let t_ann_trans = ((t_ann_s, src_lv), (t_ann_d, dst_lv)) in
      let t_ann_trans_opt = Some t_ann_trans in
      let _, rhs_p = strip_lexvar_mix_formula rhs_p in
      let rhs_p = MCP.mix_of_pure rhs_p in
      match (t_ann_s, t_ann_d) with
      | (Term, Term)
      | (Fail TermErr_May, Term) ->
          (* Check wellfoundedness of the transition *)
          check_term_measures estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p
            src_lv dst_lv t_ann_trans_opt pos
      | (Term, _) ->
          let term_res = (term_pos, t_ann_trans_opt, Some estate.CF.es_formula,
            TermErr (Invalid_Status_Trans t_ann_trans)) in
          term_res_stk # push term_res;
          let term_measures = match t_ann_d with
            | Loop -> Some (Fail TermErr_Must, src_lv, src_il)
            | MayLoop -> Some (Fail TermErr_May, src_lv, src_il)
          in 
          let n_estate = {estate with 
            CF.es_var_measures = term_measures;
            CF.es_var_stack = (string_of_term_res term_res)::estate.CF.es_var_stack
          } in
          (n_estate, lhs_p, rhs_p, None)
      | (Loop, _) ->
          let term_measures = Some (Loop, [], []) 
            (*
            match t_ann_d with
            | Loop _ -> Some (Loop Loop_RHS, [], [])
            | _ -> Some (Loop Loop_LHS, [], [])
            *)
          in 
          let n_estate = {estate with CF.es_var_measures = term_measures} in
          (n_estate, lhs_p, rhs_p, None)
      | (MayLoop, _) ->
          let term_measures = Some (MayLoop, [], []) 
            (*
            match t_ann_d with
            | Loop _ -> Some (Loop Loop_RHS, [], [])
            | _ -> Some (MayLoop, [], [])
            *)
          in 
          let n_estate = {estate with CF.es_var_measures = term_measures} in
          (n_estate, lhs_p, rhs_p, None)
      (*
      | (Fail _, _) -> 
          let term_res = (pos, None, TermErr (Invalid_Status_Trans (t_ann_s, t_ann_d))) in
          let n_estate = {estate with 
            CF.es_var_measures = Some (Fail, [], []);
            CF.es_var_stack = (string_of_term_res term_res)::estate.CF.es_var_stack
          } in
          (n_estate, lhs_p, rhs_p)
      *)
    end
  with _ -> (estate, lhs_p, rhs_p, None)

let check_term_rhs estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p pos =
  let pr = !CF.print_mix_formula in
  let pr2 = !CF.print_entail_state in
   Debug.no_3 "trans_lexvar_rhs" pr2 pr pr
    (fun (es, lhs, rhs, _) -> pr_triple pr2 pr pr (es, lhs, rhs))  
      (fun _ _ _ -> check_term_rhs estate lhs_p xpure_lhs_h0 xpure_lhs_h1 rhs_p pos) estate lhs_p rhs_p

let strip_lexvar_lhs (ctx: CF.context) : CF.context =
  let es_strip_lexvar_lhs (es: CF.entail_state) : CF.context =
    let _, pure_f, _, _, _ = CF.split_components es.CF.es_formula in
    let (lexvar, other_p) = strip_lexvar_mix_formula pure_f in
    (* Using transform_formula to update the pure part of es_f *)
    let f_e_f _ = None in
    let f_f _ = None in
    let f_h_f e = Some e in
    let f_m mp = Some (MCP.memoise_add_pure_N_m (MCP.mkMTrue_no_mix no_pos) other_p) in
    let f_a _ = None in
    let f_p_f pf = Some other_p in
    let f_b _ = None in
    let f_e _ = None in
    match lexvar with
    | [] -> CF.Ctx es
    | lv::[] -> 
        let t_ann, ml, il = find_lexvar_formula lv in 
        CF.Ctx { es with 
          CF.es_formula = CF.transform_formula (f_e_f, f_f, f_h_f, (f_m, f_a, f_p_f, f_b, f_e)) es.CF.es_formula;
          CF.es_var_measures = Some (t_ann, ml, il); 
        }
    | _ -> report_error no_pos "[term.ml][strip_lexvar_lhs]: More than one LexVar to be stripped." 
  in CF.transform_context es_strip_lexvar_lhs ctx

let strip_lexvar_lhs (ctx: CF.context) : CF.context =
  let pr = Cprinter.string_of_context in
  Debug.no_1 "strip_lexvar_lhs" pr pr strip_lexvar_lhs ctx

(* End of LexVar handling *) 


(* HIP: Collecting information for termination proof *)
let report_term_error (ctx: CF.formula) (reason: term_reason) pos : term_res =
  let err = (pos, None, Some ctx, TermErr reason) in
  term_res_stk # push err;
  err

let add_unreachable_res (ctx: CF.list_failesc_context) pos : term_res =
  let _ = 
    begin
      DD.devel_zprint (lazy (">>>>>> [term.ml][add_unreachable_res] <<<<<<")) pos;
      DD.devel_hprint (add_str "Context: " Cprinter.string_of_list_failesc_context) ctx pos
    end
  in
  let term_pos = (post_pos # get, proving_loc # get) in
  let succ_ctx = CF.succ_context_of_list_failesc_context ctx in
  let orig_ante_l = List.concat (List.map CF.collect_orig_ante succ_ctx) in
  let orig_ante = CF.formula_of_disjuncts orig_ante_l in
  let term_res = (term_pos, None, Some orig_ante, Unreachable) in
  term_res_stk # push term_res;
  term_res

let get_phase_num (measure: CF.ext_variance_formula) : int =
  let phase_num = fst (List.nth measure.CF.formula_var_measures 1) in
  if (CP.is_num phase_num) then CP.to_int_const phase_num CP.Floor 
  else raise Invalid_Phase_Num 
(*  
let check_reachable_term_measure f (ctx: CF.context) (measure: CF.ext_variance_formula) pos : term_res =
  let orig_ante = CF.formula_of_context ctx in
  try
    let phase_num = get_phase_num measure in
    let term_res =
      if (phase_num < 0) then
        (pos, orig_ante, NonTerm Non_Term_Reached)
      else if (phase_num = 0) then
        (pos, orig_ante, Term Base_Case_Reached)
      else
        let lv = CF.lexvar_of_evariance measure in 
        match lv with
        | None -> report_term_error orig_ante Variance_Not_Given pos
        | Some m -> 
            let lv = CF.formula_of_pure_formula m pos in
            let res = f ctx lv pos in (* check decreasing *)
            if (CF.isFailCtx res) then (pos, orig_ante, MayTerm Not_Decrease_Measure)
            else
              (* The default lower bound is zero *)
              let zero = List.map (fun _ -> CP.mkIConst 0 pos) measure.CF.formula_var_measures in       
              let bnd = CF.formula_of_pure_formula (CP.mkPure (CP.mkLexVar zero [] pos)) pos in
              let res = f ctx bnd pos in (* check boundedness *)
              if (CF.isFailCtx res) then (pos, orig_ante, MayTerm Not_Bounded_Measure)
              else (pos, orig_ante, Term Valid_Measure)
    in term_res_stk # push term_res; term_res
  with 
  | Invalid_Phase_Num
  | Failure "nth" -> report_term_error orig_ante Invalid_Phase_Trans pos
*)
(*
let check_reachable_term_measure f (ctx: CF.context) (measure: CF.ext_variance_formula) pos : term_res =
  let orig_ante = CF.formula_of_context ctx in
  let lv = CF.lexvar_of_evariance measure in
  match lv with
  | None -> report_term_error orig_ante Variance_Not_Given pos
  | Some m -> 
      let lv = CF.formula_of_pure_formula m pos in
      let res = f ctx lv pos in (* check decreasing *)
      let term_res =
        if (CF.isFailCtx res) then 
          (pos, Some orig_ante, MayTerm_S Not_Decreasing_Measure)
        else
          (* The default lower bound is zero *)
          let zero = List.map (fun _ -> CP.mkIConst 0 pos) measure.CF.formula_var_measures in       
          let bnd = CF.formula_of_pure_formula (CP.mkPure (CP.mkLexVar Term zero [] pos)) pos in
          let res = f ctx bnd pos in (* check boundedness *)
          if (CF.isFailCtx res) then (pos, Some orig_ante, MayTerm_S Not_Bounded_Measure)
          else (pos, Some orig_ante, Term_S Valid_Measure)
      in term_res_stk # push term_res; 
      term_res 

let check_term_measure f (ctx: CF.context) (measure: CF.ext_variance_formula) pos : term_res =
  if (CF.isAnyFalseCtx ctx) then
    let orig_ante = CF.formula_of_disjuncts (CF.collect_orig_ante ctx) in
    let term_res = (pos, Some orig_ante, Unreachable) in
    term_res_stk # push term_res;
    term_res
  else
    check_reachable_term_measure f ctx measure pos
*)

