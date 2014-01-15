open Globals
open Gen

module DD = Debug
module CF = Cformula
module CP = Cpure
module MCP = Mcpure
module C = Cast
module I = Iast
module TP = Tpdispatcher

let keep_data_view_hpargs_nodes prog f hd_nodes hv_nodes keep_rootvars keep_hpargs=
  let keep_ptrs = CF.look_up_reachable_ptr_args prog hd_nodes hv_nodes keep_rootvars in
  CF.drop_data_view_hpargs_nodes f CF.check_nbelongsto_dnode CF.check_nbelongsto_vnode
    CF.check_neq_hpargs keep_ptrs keep_ptrs keep_hpargs

let keep_data_view_hpargs_nodes prog f hd_nodes hv_nodes keep_rootvars keep_hpargs=
  let pr1 = Cprinter.prtt_string_of_formula in
  let pr2 = pr_list (pr_pair !CP.print_sv !CP.print_svl) in
  Debug.no_3 "keep_data_view_hpargs_nodes" pr1 !CP.print_svl pr2 pr1
      (fun _ _ _ -> keep_data_view_hpargs_nodes prog f hd_nodes hv_nodes keep_rootvars keep_hpargs)
      f keep_rootvars keep_hpargs

let obtain_reachable_formula prog f roots=
  let (h ,mf,_,_,_) = CF.split_components f in
  let hds, hvs, hrs = CF.get_hp_rel_h_formula h in
  let eqsets = (MCP.ptr_equations_without_null mf) in
  let reach_ptrs= CF.look_up_reachable_ptrs_w_alias_helper prog hds hvs eqsets roots in
  let hpargs = List.map (fun (hp,eargs,_) -> (hp, List.concat (List.map CP.afv eargs))) hrs in
  let sel_hpargs = List.filter (fun (_,args) -> CP.diff_svl args reach_ptrs = []) hpargs in
  let reach_f = keep_data_view_hpargs_nodes prog f hds hvs reach_ptrs sel_hpargs in
  reach_f

let obtain_reachable_formula prog f roots=
  let pr1 = !CF.print_formula in
  let pr2 = !CP.print_svl in
  Debug.no_2 "obtain_reachable_formula" pr1 pr2 pr1
      (fun _ _ -> obtain_reachable_formula prog f roots)
      f roots

(*
(i) build emap for LHS/RHS 
  - eqnull -> make closure. do not subst
  - cycle nodes: DO NOT subst
  - inside one preds, do not subst
(ii) common free vars for both LHS/RHS
(iii) subs both sides to use smallest common vars
        lhs     |- P(v* )
*)

let cmp_fn sv1 sv2 = let n= String.compare (CP.name_of_spec_var sv1) (CP.name_of_spec_var sv2) in
  if n=0 then
    if CP.primed_of_spec_var sv1 = Unprimed then -1 else 1
  else n
let build_subst_comm_x args prog_vars emap comm_svl=
  (* let find_comm_eq ls_eq sv= *)
  (*   if List.exists (fun svl -> CP.mem_svl sv svl) ls_eq then ls_eq else *)
  (*     let com_eq_svl = CP.EMapSV.find_equiv_all sv emap in *)
  (*     if com_eq_svl = [] then ls_eq else *)
  (*       ls_eq@[com_eq_svl] *)
  (* in *)
  let build_subst subst evars=
    let inter1 = CP.intersect_svl evars prog_vars in
    let keep_sv = if inter1 <> [] then
      List.hd (List.sort cmp_fn inter1)
    else
      let inter2 = CP.intersect_svl evars args in
      if inter2 <> [] then
        List.hd (List.sort cmp_fn inter2)
      else
        let evars1 = List.sort cmp_fn evars in
        List.hd evars1
    in
    let new_ss = List.fold_left (fun r sv -> if CP.eq_spec_var keep_sv sv then r else r@[(sv, keep_sv)]) [] evars in
    subst@new_ss
  in
  let epart0 = CP.EMapSV.partition emap in
  (* let ls_com_eq_svl = List.fold_left find_comm_eq [] comm_svl in *)
  let ls_com_eq_svl, ls_non_com_eq_svl = List.partition (fun svl ->
      CP.intersect_svl svl comm_svl <> []
  ) epart0 in
  let ss1 =  if ls_com_eq_svl = [] then [] else
    List.fold_left build_subst [] ls_com_eq_svl
  in
  let ss2 = if ls_non_com_eq_svl = [] then [] else
    List.fold_left build_subst [] ls_non_com_eq_svl
  in
  (ss1@ss2)

let build_subst_comm args prog_vars emap comm_svl=
  let pr1 = CP.EMapSV.string_of in
  let pr2 =  !CP.print_svl in
  let pr3 = pr_list (pr_pair !CP.print_sv !CP.print_sv ) in
  Debug.no_4 "SAU.build_subst_comm" pr2 pr2 pr1 pr2 pr3
      (fun _ _ _ _ ->  build_subst_comm_x args prog_vars emap comm_svl)
      args prog_vars emap comm_svl

let expose_expl_closure_eq_null_x lhs_b lhs_args emap0=
  let rec find_equiv_all eparts sv all_parts=
    match eparts with
      | [] -> [],all_parts
      | ls::rest -> if CP.mem_svl sv ls then (ls,all_parts@rest) else
          find_equiv_all rest sv (all_parts@[ls])
  in
  let look_up_eq_null (epart, ls_null_args, ls_expl_eqs, ss) sv=
    (* let eq_nulls,rem_parts = find_equiv_all epart sv [] in *)
    let eq_nulls,rem_parts = find_equiv_all epart sv [] in
    let eq_null_args = CP.intersect_svl eq_nulls lhs_args in
    if List.length eq_null_args > 1 then
      let eq_null_args1 = (List.sort cmp_fn eq_null_args) in
      let keep_sv = List.hd eq_null_args1 in
      let ss2 = List.fold_left (fun ss1 sv ->
          if CP.eq_spec_var keep_sv sv then ss1
          else ss1@[(sv, keep_sv)]
      ) [] eq_nulls
      in
      let ss3 = List.map (fun sv -> (sv, keep_sv) ) (List.tl eq_null_args1) in
      (rem_parts, ls_null_args@eq_null_args, ls_expl_eqs@ss3,ss@ss2)
    else (epart, ls_null_args, ls_expl_eqs, ss)
  in
  let eq_null_svl = CP.remove_dups_svl (MCP.get_null_ptrs lhs_b.CF.formula_base_pure) in
  let epart0 = CP.EMapSV.partition emap0 in
  let rem_parts, eq_null_args, expl_eq_args, ss = List.fold_left look_up_eq_null (epart0, [],[],[]) eq_null_svl in
  let cls_e_null = List.map (fun sv -> CP.mkNull sv no_pos) eq_null_args in
  (* let expl_eq_ps = List.map (fun (sv1,sv2) -> CP.mkEqVar sv1 sv2 no_pos) expl_eq_args in *)
  (CP.EMapSV.un_partition rem_parts, (* expl_eq_ps@ *)cls_e_null, ss)


let expose_expl_closure_eq_null lhs_b lhs_args emap=
  let pr1 = CP.EMapSV.string_of in
  let pr2 = pr_list !CP.print_formula in
  let pr3 = pr_list (pr_pair !CP.print_sv !CP.print_sv ) in
  Debug.no_1 "SAU.expose_expl_closure_eq_null" pr1 (pr_triple pr1 pr2 pr3)
      (fun _ -> expose_expl_closure_eq_null_x lhs_b lhs_args emap) emap
(*
  - cycle nodes: DO NOT subst
  - inside one preds, do not subst

for each ls_eqs, if it contains at least two vars of the same group,
  - we remove this ls_eqs
  - add equality in lhs
 input:
  - emap: global emap (no r_qemap)
  - groups of args of unknown preds + args + data nodes
 output:
  - triple of (remain emap, equalifty formula to be added to lhs, ss for pure of lhs
  rhs
*)
let expose_expl_eqs_x emap0 prog_vars vars_grps0=
  (*move root to behind, donot loss it*)
  let roots = List.fold_left (fun roots0 args -> match args with
    | r::_ -> roots0@[r]
    | _ -> roots0
  ) [] vars_grps0 in
  let all_vars = List.concat vars_grps0 in
  let process_one_ls_eq ls_eqs =
    let ls_eq_args = List.fold_left (fun r args ->
        let inter = CP.intersect_svl args ls_eqs in
        if List.length inter > 1 then r@[inter] else r
        ) [] vars_grps0 in
    let ls_eq_args1 = List.sort (fun ls1 ls2 -> List.length ls2 - List.length ls1) ls_eq_args in
    let ls_eq_args2 = Gen.BList.remove_dups_eq (Gen.BList.subset_eq CP.eq_spec_var) ls_eq_args1 in
    if ls_eq_args2=[] then (false,[],[])
    else
      (* let _ = Debug.info_hprint (add_str  "ls_eq_args2 " (pr_list !CP.print_svl)) ls_eq_args2 no_pos in *)
      (*explicit equalities*)
      let expl_eqs, link_svl = List.fold_left (fun (r, keep_svl) ls ->
          let ls1 = List.sort cmp_fn ls in
          (* let inter = CP.intersect_svl roots ls1 in *)
          let keep_sv = (* if inter <> [] then List.hd inter else *) List.hd ls1 in
          (r@(List.map (fun sv -> (sv, keep_sv)) (List.tl ls1)), keep_svl@[keep_sv])
      ) ([],[]) ls_eq_args2
      in
      (*link among grps*)
      let link_expl_eqs = if link_svl = [] then [] else
        let link_svl1 = List.sort cmp_fn link_svl in
        let fst_sv = List.hd link_svl1 in
        List.map (fun sv -> (sv, fst_sv)) (List.tl link_svl1)
      in
      (*subst for others*)
      let keep_sv =
        let _ = Debug.ninfo_hprint (add_str  "link_svl" !CP.print_svl) link_svl no_pos in
        let inters1 = CP.intersect_svl (prog_vars) link_svl in
        let _ = Debug.ninfo_hprint (add_str  "inters1" !CP.print_svl) inters1 no_pos in
        if inters1 != [] then List.hd inters1 else
          (* let inters0 = CP.intersect_svl roots link_svl in *)
          (* let _ = Debug.info_hprint (add_str  "inters0" !CP.print_svl) inters0 no_pos in *)
          (* if inters0 != [] then List.hd (inters0) else *)
            let inters = CP.intersect_svl all_vars link_svl in
            let _ = Debug.ninfo_hprint (add_str  "inters" !CP.print_svl) inters no_pos in
          if inters = [] then List.hd (List.sort cmp_fn link_svl)
          else List.hd inters
      in
      (* let _ = Debug.info_hprint (add_str  "keep_sv " !CP.print_sv) keep_sv no_pos in *)
      (* let _ = Debug.info_hprint (add_str  "ls_eqs " !CP.print_svl) ls_eqs no_pos in *)
      let ss2 = List.fold_left (fun ss1 sv ->
          if CP.eq_spec_var keep_sv sv then ss1
          else ss1@[(sv, keep_sv)]
      ) [] ls_eqs
      in
      (true, expl_eqs@link_expl_eqs,ss2)
  in
  let epart0 = CP.EMapSV.partition emap0 in
  let rem_eparts, ls_eq_args, expl_eq_args,sst = List.fold_left (fun (r_eparts, r_eq_args, r_eqs, r_ss) ls_eqs->
      let b, n_eqs, n_ss = process_one_ls_eq ls_eqs in
      if b then
        (r_eparts, r_eq_args@[ls_eqs], r_eqs@n_eqs, r_ss@n_ss)
      else (r_eparts@[ls_eqs], r_eq_args, r_eqs, r_ss)
  ) ([],[],[],[]) epart0 in
  let expl_eq_ps = List.map (fun (sv1,sv2) -> CP.mkEqVar sv1 sv2 no_pos) expl_eq_args in
  (CP.EMapSV.un_partition rem_eparts, ls_eq_args, expl_eq_ps ,sst)

let expose_expl_eqs emap prog_vars vars_grps=
  let pr1 = pr_list_ln !CP.print_svl in
  let pr2 = CP.EMapSV.string_of in
  let pr3 = pr_list (pr_pair !CP.print_sv !CP.print_sv ) in
  let pr4 = pr_quad pr2 pr1 (pr_list !CP.print_formula) pr3 in
  Debug.no_2 "SAU.expose_expl_eqs" pr2 pr1 pr4
      (fun _ _ -> expose_expl_eqs_x emap prog_vars vars_grps)
      emap vars_grps

let h_subst ss ls_eq_args0 hf0=
  let rec is_expl_eqs ls_eq_args svl =
    match ls_eq_args with
      | [] -> false
      | eqs::rest ->
            if List.length (CP.intersect_svl eqs svl) > 1 then true else
              is_expl_eqs rest svl
  in
  match hf0 with
    | CF.DataNode dn ->
          let svl = dn.CF.h_formula_data_node::dn.CF.h_formula_data_arguments in
          if is_expl_eqs ls_eq_args0 svl then hf0 else
            let hf1 = CF.h_subst ss hf0 in
            hf1
    | CF.ViewNode vn ->
          let svl = vn.CF.h_formula_view_node::vn.CF.h_formula_view_arguments in
          if is_expl_eqs ls_eq_args0 svl then hf0 else
            let hf1 = CF.h_subst ss hf0 in
            hf1
    | CF.HRel (hp, eargs, pos) ->
          let svl = List.fold_left List.append [] (List.map CP.afv eargs) in
          let _ = Debug.ninfo_hprint (add_str  "svl " !CP.print_svl) svl no_pos in
          if is_expl_eqs ls_eq_args0 svl then hf0 else
            let hf1 = CF.h_subst ss hf0 in
            hf1
    | _ -> hf0


let smart_subst_new_x lhs_b rhs_b hpargs l_emap r_emap r_qemap unk_svl prog_vars=
  let largs= CF.h_fv lhs_b.CF.formula_base_heap in
  let rargs= CF.h_fv rhs_b.CF.formula_base_heap in
  let all_args = CP.remove_dups_svl (largs@rargs) in
  (*---------------------------------------*)
  let lsvl = CF.fv (CF.Base lhs_b) in
  let rsvl = (CF.fv (CF.Base rhs_b))@(CP.EMapSV.get_elems r_emap)@(CP.EMapSV.get_elems r_qemap) in
  let comm_svl = CP.intersect_svl lsvl rsvl in
  let lhs_b1, rhs_b1, prog_vars =
    if comm_svl = [] then
      (lhs_b, rhs_b, prog_vars)
    else
      let l_emap1, null_ps, null_sst = expose_expl_closure_eq_null lhs_b all_args l_emap in
      let emap0 = CP.EMapSV.merge_eset l_emap r_emap in
      let vars_grps = (CF.get_data_node_ptrs_group_hf lhs_b.CF.formula_base_heap)@(CF.get_data_node_ptrs_group_hf rhs_b.CF.formula_base_heap)@
        (List.map snd hpargs)
      in
      let emap0a, ls_eq_args, expl_eqs_ps, eq_sst = expose_expl_eqs emap0 prog_vars vars_grps in
      (* let _ = Debug.info_hprint (add_str  "ls_eq_args " (pr_list !CP.print_svl)) ls_eq_args no_pos in *)
      let emap1 = CP.EMapSV.merge_eset emap0a r_qemap in
      let ss = build_subst_comm all_args prog_vars emap1 comm_svl in
      let pr_ss = pr_list (pr_pair !CP.print_sv !CP.print_sv) in
      (* let _ = Debug.info_hprint (add_str  "ss " (pr_ss)) ss no_pos in *)
      (*LHS*)
      let lhs_b1 = CF.subst_b ss lhs_b in
      let lhs_pure1 = MCP.pure_of_mix lhs_b1.CF.formula_base_pure in
      let lhs_pure2 = CP.subst (null_sst@eq_sst) lhs_pure1 in
      let lpos = CF.pos_of_formula (CF.Base lhs_b1) in
      let lhs_pure_w_expl = CP.conj_of_list (lhs_pure2::(null_ps@expl_eqs_ps)) lpos in
      let lhs_b2 = {lhs_b1 with CF.formula_base_pure = MCP.mix_of_pure
              (CP.remove_redundant lhs_pure_w_expl);
          CF.formula_base_heap = CF.trans_heap_hf (h_subst (null_sst@eq_sst) ls_eq_args) lhs_b1.CF.formula_base_heap;
      } in
      (*RHS*)
      let rhs_b1 = CF.subst_b ss rhs_b in
      (* let _ = Debug.info_hprint (add_str  "rhs_b1 " Cprinter.prtt_string_of_formula) (CF.Base rhs_b1) no_pos in *)
      let rhs_b2 = {rhs_b1 with CF.formula_base_pure = MCP.mix_of_pure
              (CP.remove_redundant (MCP.pure_of_mix rhs_b1.CF.formula_base_pure));
          CF.formula_base_heap = CF.trans_heap_hf (h_subst (null_sst@eq_sst) ls_eq_args) rhs_b1.CF.formula_base_heap;
      } in
      (lhs_b2, rhs_b2, CP.subst_var_list (ss@null_sst@eq_sst) prog_vars)
  in
  (lhs_b1, rhs_b1, prog_vars)

let smart_subst_new lhs_b rhs_b hpargs l_emap r_emap r_qemap unk_svl prog_vars=
  let pr1 = Cprinter.string_of_formula_base in
  let pr2 = !CP.print_svl in
  let pr3 = CP.EMapSV.string_of in
  let pr4 = pr_list (pr_pair !CP.print_sv !CP.print_svl) in
  Debug.no_7 "smart_subst_new" pr1 pr1 pr4 pr2 pr3 pr3 pr3 (pr_triple pr1 pr1 pr2)
      (fun _ _ _ _ _ _ _-> smart_subst_new_x lhs_b rhs_b hpargs l_emap r_emap r_qemap unk_svl prog_vars)
      lhs_b rhs_b hpargs prog_vars l_emap r_emap r_qemap

let check_inconsistency hf mixf=
  let new_mf = CF.xpure_for_hnodes hf in
  let cmb_mf = MCP.merge_mems new_mf mixf true in
  not (TP.is_sat_raw cmb_mf)

let check_inconsistency_f f0 pure_f=
  let p = MCP.mix_of_pure (CF.get_pure pure_f) in
  let rec helper f=
    match f with
      | CF.Base fb -> check_inconsistency fb.CF.formula_base_heap p
      | CF.Or orf -> (helper orf.CF.formula_or_f1) && (helper orf.CF.formula_or_f2)
      | CF.Exists fe ->
        (*may not correct*)
          check_inconsistency fe.CF.formula_exists_heap p
  in
  helper f0

let rec is_unsat_x f0=
  let rec helper f=
    match f with
      | CF.Base fb -> check_inconsistency fb.CF.formula_base_heap fb.CF.formula_base_pure
      | CF.Or orf -> (helper orf.CF.formula_or_f1) || (helper orf.CF.formula_or_f2)
      | CF.Exists fe ->
        (*may not correct*)
          check_inconsistency fe.CF.formula_exists_heap fe.CF.formula_exists_pure
  in
  helper f0

and is_unsat f=
  let pr1 = Cprinter.prtt_string_of_formula in
  let pr2 = string_of_bool in
  Debug.no_1 "is_unsat" pr1 pr2
      (fun _ -> is_unsat_x f) f

let check_separation_unsat f0=
  let rec helper f=
    match  f with
      | CF.Base fb -> let hds, hvs, _ (*hvs, hrs*) = CF.get_hp_rel_h_formula fb.CF.formula_base_heap in
        let d_ptrs = List.map (fun dn -> dn.CF.h_formula_data_node) hds in
        let v_ptrs = List.map (fun vn -> vn.CF.h_formula_view_node) hvs in
        if CP.intersect_svl d_ptrs v_ptrs = [] then
          let p = (MCP.pure_of_mix fb.CF.formula_base_pure) in
          if (CP.isConstTrue p) then false else
            let null_svl = MCP.get_null_ptrs fb.CF.formula_base_pure in
            let nNull_svl = (* CP.get_neq_null_svl p *)[] in
            if (null_svl = []) && nNull_svl =[] then false else
              (CP.intersect_svl null_svl nNull_svl !=[]) || (CP.intersect_svl (d_ptrs@v_ptrs) (null_svl@nNull_svl) !=[])
        else true
      | CF.Or orf -> (helper orf.CF.formula_or_f1) && (helper orf.CF.formula_or_f2)
      | CF.Exists _ ->
            let _,base = CF.split_quantifiers f in
          helper base
  in
  helper f0

let check_separation_unsat f0=
  let pr1 =  Cprinter.prtt_string_of_formula in
  let pr2 = string_of_bool in
  Debug.no_1 "check_separation_unsat" pr1 pr2
      (fun _ -> check_separation_unsat f0)
      f0

(*
  res = -1: NO cyclic - not syn lemma
  res = 0: syn Left lemma
  res = 1: syn Right lemma
*)
let need_cycle_checkpoint_x prog lvnode lhs rvnode rhs=
  if not !Globals.lemma_syn || (check_separation_unsat rhs) || (check_separation_unsat lhs) then -1 else
    (*check root has unfold information information??*)
    let null_neq_svl = (CF.get_neqNull lhs)@(CF.get_null_svl lhs) in
    (* if CP.mem_svl lvnode.CF.h_formula_view_node null_neq_svl then -1 else *)
      let _, l_reach_dns,l_reach_vns = CF.look_up_reachable_ptrs_w_alias prog lhs [lvnode.CF.h_formula_view_node] 3 in
      let _, r_reach_dns,r_reach_vns = CF.look_up_reachable_ptrs_w_alias prog rhs [rvnode.CF.h_formula_view_node] 3 in
      let lnlength = List.length l_reach_dns in
      let lvlength = List.length l_reach_vns in
      let rnlength = List.length r_reach_dns in
      let rvlength = List.length r_reach_vns in
      if lvlength = rvlength then
        if (lnlength != rnlength) then 0 else
          let lview_names = List.map (fun v -> v.CF.h_formula_view_name) l_reach_vns in
          let rview_names = List.map (fun v -> v.CF.h_formula_view_name) r_reach_vns in
          if Gen.BList.difference_eq (fun s1 s2 -> String.compare s1 s2=0) lview_names rview_names != [] then
            1
          else
            -1
      else
        if (lvlength > rvlength) then 0 else -1

let need_cycle_checkpoint prog lvnode lhs rvnode rhs=
  let pr1 = Cprinter.prtt_string_of_formula in
  Debug.no_2 "need_cycle_checkpoint" pr1 pr1 string_of_int
      (fun _ _ -> need_cycle_checkpoint_x prog lvnode lhs rvnode rhs)
      lhs rhs

let need_cycle_checkpoint_fold_x prog ldnode lhs rvnode rhs=
  if not !Globals.lemma_syn || (check_separation_unsat rhs) || (check_separation_unsat lhs) then -1 else
    let _, l_reach_dns,l_reach_vns = CF.look_up_reachable_ptrs_w_alias prog lhs [ldnode.CF.h_formula_data_node] 3 in
    let _, r_reach_dns,r_reach_vns = CF.look_up_reachable_ptrs_w_alias prog rhs [rvnode.CF.h_formula_view_node] 3 in
    (* let lnlength = List.length l_reach_dns in *)
    let lview_names = List.map (fun v -> v.CF.h_formula_view_name) l_reach_vns in
    (* let rnlength = List.length r_reach_dns in *)
    let rview_names = List.map (fun v -> v.CF.h_formula_view_name) r_reach_vns in
    if Gen.BList.difference_eq (fun s1 s2 -> String.compare s1 s2=0) lview_names rview_names != [] then
      1
    else -1

let need_cycle_checkpoint_fold prog ldnode lhs rvnode rhs=
  let pr1 = Cprinter.prtt_string_of_formula in
  Debug.no_2 "need_cycle_checkpoint_fold" pr1 pr1 string_of_int
      (fun _ _ -> need_cycle_checkpoint_fold_x prog ldnode lhs rvnode rhs)
      lhs rhs

let need_cycle_checkpoint_unfold_x prog lvnode lhs rdnode rhs=
  if not !Globals.lemma_syn || (check_separation_unsat rhs) || (check_separation_unsat lhs)  then -1 else
    let _, l_reach_dns,l_reach_vns = CF.look_up_reachable_ptrs_w_alias prog lhs [lvnode.CF.h_formula_view_node] 3 in
    let _, r_reach_dns,r_reach_vns = CF.look_up_reachable_ptrs_w_alias prog rhs [rdnode.CF.h_formula_data_node] 3 in
    (* let lnlength = List.length l_reach_dns in *)
    let lview_names = List.map (fun v -> v.CF.h_formula_view_name) l_reach_vns in
    (* let rnlength = List.length r_reach_dns in *)
    let rview_names = List.map (fun v -> v.CF.h_formula_view_name) r_reach_vns in
    if Gen.BList.difference_eq (fun s1 s2 -> String.compare s1 s2=0) lview_names rview_names != [] then
      0
    else -1

let need_cycle_checkpoint_unfold prog lvnode lhs rdnode rhs=
  let pr1 = Cprinter.prtt_string_of_formula in
  Debug.no_2 "need_cycle_checkpoint_unfold" pr1 pr1 string_of_int
      (fun _ _ -> need_cycle_checkpoint_unfold_x prog lvnode lhs rdnode rhs)
      lhs rhs

let get_shortest_length_base_x fs vname=
  let find_dnode_of_base r f=
    let hds, hvs, _ = CF.get_hp_rel_formula f in
    if List.for_all (fun hv -> String.compare vname hv.CF.h_formula_view_name !=0 ) hvs then
      r@[(hds)]
    else r
  in
  let process_one shortest dns=
    let dn = List.length dns in
    if dn < shortest then dn else shortest
  in
  let base_fs = List.fold_left find_dnode_of_base [] fs in
  match base_fs with
    | [] -> 0
    | dns::rest ->
          let ini = List.length dns in
          List.fold_left process_one ini rest

let get_shortest_length_base fs view_name=
  let pr1 = pr_list !CF.print_formula in
  Debug.no_2 "get_shortest_length_base" pr1 pr_id string_of_int
      (fun _ _ -> get_shortest_length_base_x fs view_name)
      fs view_name
