#include "xdebug.cppo"
open Arr_biabduction_extend
open Arr_entailment_with_frame
open Arr_entailment_with_bi_abduction
(* This version early check pure formula in LHS *)
(* This version handle existential in a wrapping manner *)

(* Bi-Abduction *)

                             
       

type norm_pre_condition_base =
  | NormBaseNeg of (Cpure.spec_var list * Cpure.spec_var list * Cpure.formula list)
  | NormBaseImply of (Cpure.spec_var list * Cpure.spec_var list * Cpure.formula list * Cpure.formula list * asegPredplus list * asegPredplus list)
;;

let mkNormBaseNeg uset eset pf =
  NormBaseNeg (uset,eset,pf)
;;

let mkNormBaseImply uset eset lhsp rhsp frame antiframe =
  NormBaseImply (uset,eset,lhsp,rhsp,frame,antiframe)
;;

let str_norm_pre_condition_base norm =
  match norm with
  | NormBaseNeg (uset,eset,pflst)->
     let inners = (str_list !str_pformula pflst)^"=>false)" in
     let s =
       if List.length eset = 0
       then inners
       else "Exists "^(str_list !str_sv eset)^": "^inners
     in
     if List.length uset = 0
     then s
    else "Forall "^(str_list !str_sv uset)^" "^s
                                                 
  | NormBaseImply (uset,eset,lhs_p,rhs_p,frame,antiframe) ->
     let inners = (str_list !str_pformula lhs_p)^"=>"^(str_list !str_pformula rhs_p)^" @"^(str_asegPredplus_lst frame)^" * "^(str_asegPredplus_lst antiframe) in
     let s =
       if List.length eset = 0
       then inners
       else "Exists "^(str_list !str_sv eset)^": "^inners
     in
     if List.length uset = 0
     then s
     else "Forall "^(str_list !str_sv uset)^" "^s
;;
  
type norm_pre_condition =
  | NormOr of (Cpure.spec_var list * Cpure.formula list * norm_pre_condition_base) list
;;
  
let mkNormOr lst =
  NormOr lst
;;

let mkNormOr_base uqset_eq base =
  let neweset,newf = List.split (List.map (fun (v,e) -> (v,mkEq (mkVar v) e)) uqset_eq) in
  mkNormOr [(neweset,[],base)]
;;

let rec str_norm_pre_condition  =
  function
    NormOr lst ->
    str_list_delimeter
      (fun (eset,caselst,base) ->
        let inners =
          (str_list !str_pformula caselst)^"/\\"^(str_norm_pre_condition_base base)
        in
        if List.length eset = 0
        then inners
        else "Exists "^(str_list !str_sv eset)^": "^inners)
      lst
      "\n"
      ""
;;

(* ex U. f1/\f2 *)
let combine_norm nlst clst eset=
  let rec enhance_with_case norm case eset =
    match norm with
    | NormOr lst ->
       (List.map (fun (eset_orig,case_orig,base)-> (eset@eset_orig,case::case_orig,base)) lst)
  in
  try
    mkNormOr (List.concat (List.map2 (fun norm case -> enhance_with_case norm case eset) nlst clst))
  with Invalid_argument _ ->
    failwith "combine_norm: case number not matching"
;;

let simplify_pure_in_norm_pre_condition =
  (function NormOr lst ->
            NormOr (List.map (function (vset,clst,base) ->
                                       (vset,[simplify (mkAndlst clst)],base)) lst))
;;

let simplify_norm_pre_condition norm =
  norm
  (* (simplify_pure_in_norm_pre_condition norm) *)
  (* merge_false_in_norm_pre_condition  *)
;;

let array_entailment_biabduction_norm lhs rhs =
  let mkUsetandVsetprime set vset =
    let uset = List.filter (fun item -> List.exists (fun item1 -> is_same_sv item item1) set)  vset in
    let vsetprime = List.filter (fun item -> not (List.exists (fun item1 -> is_same_sv item item1) uset)) vset in
    (uset,vsetprime)
  in

  let print_and_return f indent =
    let () =
      print_endline_verbose (print_indent indent ("=>"^(str_biabFormula f)))
    in
    f
  in

  (* input: heap formulas, output: a pure formula with sorted information  *)  
  let get_sorted_puref_general arrPredlst =
    let rec helper lst lastm flst =
      match lst with
      | [] -> mkAndlst flst
      | h::tail ->
         ( match h with
           | AsegNE_p (t,m) ->
              helper tail (mkVar m) ([mkLte lastm (mkVar t);mkLtSv t m]@flst)
           | Pointsto_p (t,v) ->
              helper tail (incOne (mkVar t)) ((mkLte lastm (mkVar t))::flst)
           | Aseg_p (t,m) ->
              mkOr
                (helper tail lastm ((mkEqSv t m)::flst))
                (helper tail (mkVar m) ([mkLte lastm (mkVar t);mkLtSv t m]@flst))
           | _ -> failwith "get_sorted_puref: Invalid input" )
    in

    let rec helper_entry arrPredlst flst =
      match arrPredlst with
      | [] -> mkAndlst flst
      | h::tail ->
         ( match h with
           | AsegNE_p (t,m) ->
              helper tail (mkVar m) ((mkLtSv t m)::flst)
           | Pointsto_p (t,v) ->
              helper tail (incOne (mkVar t)) flst
           | Aseg_p (t,m) ->
              mkOr
                (helper_entry tail ((mkEqSv t m)::flst))
                (helper tail (mkVar m) ((mkLtSv t m)::flst))
           | _ -> failwith "get_sorted_puref: Invalid input" )
    in
    helper_entry arrPredlst []
  in

  let helper_sv_to_exp uqset_eq sv =
    try
      let nu,ne=
        List.find (fun (u,e) -> is_same_sv u sv) uqset_eq
      in
      ne
    with Not_found ->
      mkVar sv
  in

  let rec helper orig_lhs_p ((lhs_p,lhs_h) as lhs) ((rhs_p,rhs_h) as rhs) vset uqset uqset_eq frame antiframe indent =
    
    let current_sv_to_exp = helper_sv_to_exp uqset_eq in
    let mkEqSv a b = mkEq (current_sv_to_exp a) (current_sv_to_exp b) in
    let mkLtSv a b = mkLt (current_sv_to_exp a) (current_sv_to_exp b) in
    let mkLteSv a b = mkLte (current_sv_to_exp a) (current_sv_to_exp b) in
    let mkGtSv a b = mkGt (current_sv_to_exp a) (current_sv_to_exp b) in
    let mkGteSv a b = mkGte (current_sv_to_exp a) (current_sv_to_exp b) in
    let norm_uqset = List.filter (fun v -> (List.exists (fun (nv,_) -> is_same_sv nv v) uqset_eq)) uqset in
    let uqset_eq_f = mkAndlst (List.map (fun (v,e) -> mkEq (mkVar v) e) uqset_eq) in
    
    let () =
      print_endline_verbose (""^(print_indent indent ((str_asegplusF lhs)^" |- "^(str_asegplusF rhs))))      
    in
    if not(isSat (mkAndlst (lhs_p@rhs_p)))
    then
      let norm = mkNormOr_base uqset_eq (mkNormBaseNeg norm_uqset vset orig_lhs_p) in
      (print_and_return (mkBExists (vset, (mkBBaseNeg lhs_p))) indent,norm)
    else
      match lhs_h, rhs_h with
      | (Aseg_p (la,lb))::ltail, _ ->
         let (uset,vsetprime) = mkUsetandVsetprime [la;lb] vset in
         let case1 = mkEqSv la lb in
         let case2 = mkLtSv la lb in
         let (f1,norm1) = helper orig_lhs_p (case1::lhs_p,ltail) rhs vsetprime uqset uqset_eq frame antiframe (indent+1) in
         let (f2,norm2) = helper orig_lhs_p (case2::lhs_p,(mkAsegNE_p la lb)::ltail) rhs vsetprime uqset uqset_eq frame antiframe (indent+1) in
         (print_and_return (mkBExists (uset,mkBAnd [f1;f2])) indent, combine_norm [norm1;norm2] [case1;case2] uset)
           
      | _ ,(Aseg_p (a,b))::rtail ->
         if false
         then
           failwith "TO BE IMPLEMENTED"
                    (* let (f1,norm1) = helper orig_lhs_p lhs ((mkEqSv a b)::rhs_p,rtail) vset frame antiframe (indent+1) in *)
                    (* let (f2,norm2) = helper orig_lhs_p lhs ((mkLtSv a b)::rhs_p,(mkAsegNE_p a b)::rtail) vset frame antiframe (indent+1) in *)
                    (* (print_and_return (BOr [f1;f2]) indent,mkNormOr [] [norm1;norm2]) *)
         else           
           let (uset,vsetprime) = mkUsetandVsetprime [a;b] vset in
           let case1 = mkEqSv a b in
           let case2 = mkLtSv a b in
           let case3 = mkGtSv a b in
           let (f1,norm1) = helper orig_lhs_p (case1::lhs_p,lhs_h) (rhs_p,rtail) vsetprime uqset uqset_eq frame antiframe (indent+1) in
           let (f2,norm2) = helper orig_lhs_p (case2::lhs_p,lhs_h) (rhs_p,(mkAsegNE_p a b)::rtail) vsetprime uqset uqset_eq frame antiframe (indent+1) in
           let (f3,norm3) = helper orig_lhs_p (case3::lhs_p,lhs_h) rhs vsetprime uqset uqset_eq frame antiframe (indent+1) in
           (print_and_return (mkBExists (uset,mkBAnd [f1;f2;f3])) indent,combine_norm [norm1;norm2;norm3] [case1;case2;case3] uset)

      | [], [] ->
         let frame = List.rev frame in
         let antiframe = List.rev antiframe in
         let norm = mkNormOr_base uqset_eq (mkNormBaseImply norm_uqset vset (uqset_eq_f::orig_lhs_p) rhs_p frame antiframe) in
         (print_and_return (mkBExists (vset, BBaseImply (lhs_p,rhs_p,frame,antiframe))) indent,norm)
      (* | [], (Aseg_p (ra,rb))::rtail -> *)
         
           
      | [], _ ->
         if !Globals.array_entailment
         then
           let norm = mkNormOr_base uqset_eq (mkNormBaseNeg norm_uqset vset orig_lhs_p) in
           (print_and_return (mkBExists (vset, (mkBBaseNeg lhs_p))) indent,norm)
         else
           let (f,norm) = helper orig_lhs_p lhs (rhs_p,[]) vset uqset uqset_eq frame (rhs_h@antiframe) (indent+1) in
           (print_and_return f indent,norm)

      | _, [] ->
         if !Globals.array_entailment
         then
           let norm = mkNormOr_base uqset_eq (mkNormBaseNeg norm_uqset vset orig_lhs_p) in
           (print_and_return (mkBExists (vset, (mkBBaseNeg lhs_p))) indent,norm)
         else
           let (f,norm) = helper orig_lhs_p (lhs_p,[]) rhs vset uqset uqset_eq (lhs_h@frame) antiframe (indent+1) in
           (print_and_return f indent,norm)
           
      | lh::ltail, rh::rtail ->
         ( match lh, rh with
           | Aseg_p _, _              
             | _, Aseg_p _->
              failwith "Aseg_p: Invalid cases"
                       
           | Pointsto_p (ls,lv),Pointsto_p (rs,rv) ->
              if is_same_sv ls rs
              then
                let f,norm = helper orig_lhs_p (lhs_p, ltail) ((mkEqSv lv rv)::rhs_p, rtail) vset uqset uqset_eq frame antiframe (indent+1) in
                (print_and_return f indent,norm)
              else
                let (uset,vsetprime) = mkUsetandVsetprime [ls;rs] vset in
                let case1 = mkEqSv ls rs in
                let case2 = mkLtSv ls rs in
                let case3 = mkGtSv ls rs in
                let f1,norm1 = helper orig_lhs_p (case1::lhs_p, lhs_h) (rhs_p, (mkPointsto_p ls rv)::rtail) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                let f2,norm2 = helper orig_lhs_p (case2::lhs_p, ltail) rhs vsetprime uqset uqset_eq (lh::frame) antiframe (indent+1) in
                let f3,norm3 = helper orig_lhs_p (case3::lhs_p, lhs_h) (rhs_p,rtail) vsetprime uqset uqset_eq frame (rh::antiframe) (indent+1) in
                (print_and_return (mkBExists (uset, mkBAnd [f1;f2;f3])) indent,combine_norm [norm1;norm2;norm3] [case1;case2;case3] uset)

           | AsegNE_p (la,lb), AsegNE_p (ra,rb) ->              
              if is_same_sv la ra
              then
                let (uset,vsetprime) = mkUsetandVsetprime [lb;rb] vset in
                let case1 = mkGtSv rb lb in
                let case2 = mkLteSv rb lb in
                let f1,norm1 = helper orig_lhs_p (case1::lhs_p,ltail) (rhs_p, (mkAsegNE_p lb rb)::rtail) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                let f2,norm2 = helper orig_lhs_p (case2::lhs_p,(mkAseg_p rb lb)::ltail) (rhs_p, rtail) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                (print_and_return (mkBExists (uset, mkBAnd [f1;f2])) indent,combine_norm [norm1;norm2] [case1;case2] uset)
              else
                let (uset,vsetprime) = mkUsetandVsetprime [la;ra] vset in
                let case1 = (mkEqSv la ra) in
                let case2 = (mkLtSv la ra) in
                let case3 = (mkGtSv la ra) in
                let f1,norm1 = helper orig_lhs_p (case1::lhs_p, lhs_h) (rhs_p, (mkAsegNE_p la rb)::rtail) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                let f2,norm2 = helper orig_lhs_p (case2::lhs_p, lhs_h) (rhs_p, (mkGap_p la ra)::rhs_h) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                let f3,norm3 = helper orig_lhs_p (case3::lhs_p, (mkGap_p ra la)::lhs_h) (rhs_p, rhs_h) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                (print_and_return (mkBExists (uset, mkBAnd [f1;f2;f3])) indent,combine_norm [norm1;norm2;norm3] [case1;case2;case3] uset)
                  
           | AsegNE_p (la,lb), Gap_p (ra,rb) ->
              if is_same_sv la ra
              then
                let (uset,vsetprime) = mkUsetandVsetprime [lb;rb] vset in
                let case1 = (mkLtSv lb rb) in
                let case2 = (mkGteSv lb rb) in
                let f1,norm1 = helper orig_lhs_p (case1::lhs_p, ltail) (rhs_p, rtail) vsetprime uqset uqset_eq (lh::frame) antiframe (indent+1) in
                let f2,norm2 = helper orig_lhs_p (case2::lhs_p, (Aseg_p (rb,lb))::ltail) (rhs_p, rtail) vsetprime uqset uqset_eq ((mkAsegNE_p la rb)::frame) antiframe (indent+1) in
                (print_and_return (mkBExists (uset, mkBAnd [f1;f2])) indent,combine_norm [norm1;norm2] [case1;case2] uset)
              else
                failwith "AsegNE v.s Gap: Not aligned"

           | Gap_p (la,lb), AsegNE_p (ra,rb)->
              if is_same_sv la ra
              then
                let (uset,vsetprime) = mkUsetandVsetprime [lb;rb] vset in
                let case1 = (mkGtSv lb rb) in
                let case2 = (mkLteSv lb rb) in
                let f1,norm1 = helper orig_lhs_p (case1::lhs_p, ltail) (rhs_p, rtail) vsetprime uqset uqset_eq frame ((mkAsegNE_p la rb)::antiframe) (indent+1) in
                let f2,norm2 = helper orig_lhs_p (case2::lhs_p, (Aseg_p (rb,lb))::ltail) (rhs_p, rtail) vsetprime uqset uqset_eq frame ((mkAsegNE_p la lb)::antiframe) (indent+1) in
                (print_and_return (mkBExists (uset, mkBAnd [f1;f2])) indent,combine_norm [norm1;norm2] [case1;case2] uset)
              else
                failwith "AsegNE v.s Gap: Not aligned"                                                  

           | Pointsto_p (ls,lv), Gap_p (ra,rb) ->
              if is_same_sv ls ra
              then
                let f,norm = helper orig_lhs_p (lhs_p,ltail) (rhs_p,rtail) vset uqset uqset_eq (lh::frame) antiframe (indent+1) in
                (print_and_return f indent,norm)
              else
                failwith "Pointsto_p v.s Gap: Not aligned"

           | Gap_p (la,lb), Pointsto_p (rs,rv) ->
              if is_same_sv la rs
              then
                let f,norm = helper orig_lhs_p (lhs_p,ltail) (rhs_p,rtail) vset uqset uqset_eq frame (rh::antiframe) (indent+1) in
                (print_and_return f indent,norm)
              else
                failwith "Gap v.s Pointsto_p: Not aligned"

           | AsegNE_p (la,lb), Pointsto_p (rs,rv) ->
              if is_same_sv la rs
              then
                let subst_case_var (NormOr lst) subs =
                  NormOr
                    (List.map
                       (fun (eset,clst,base)->
                         (eset,List.map (Cpure.subs_var_with_exp subs) clst,base))
                       lst
                    )
                in
                let fresh_c = global_get_new_var () in (* c=la+1 *)
                let fresh_u = global_get_new_var () in
                let c_exp = incOne (mkVar la) in                
                let eq_c_exp = mkEq (mkVar fresh_c) c_exp in
                let subst = [(fresh_c,c_exp)]in
                let f,norm = helper orig_lhs_p (eq_c_exp::lhs_p,([mkPointsto_p la fresh_u; mkAseg_p fresh_c lb]@ltail))
                                    (rhs_p,rhs_h) (vset) ([fresh_u;fresh_c]@uqset) ((fresh_c,c_exp)::uqset_eq) frame antiframe (indent+1) in
                (print_and_return (mkBForall ([fresh_u;fresh_c],f)) indent,subst_case_var norm subst)
              else
                let (uset,vsetprime) = mkUsetandVsetprime [la;rs] vset in
                let case1 = (mkEqSv la rs) in
                let case2 = (mkLtSv la rs) in
                let case3 = (mkGtSv la rs) in
                let f1,norm1 = helper orig_lhs_p (case1::lhs_p, lhs_h) (rhs_p, (mkPointsto_p la rv)::rtail) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                let f2,norm2 = helper orig_lhs_p (case2::lhs_p, lhs_h) (rhs_p, (mkGap_p la rs)::rhs_h) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                let f3,norm3 = helper orig_lhs_p (case3::lhs_p, (mkGap_p rs la)::lhs_h) (rhs_p, rhs_h) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                (print_and_return (mkBExists (uset, mkBAnd [f1;f2;f3])) indent,combine_norm [norm1;norm2;norm3] [case1;case2;case3] uset)

           | Pointsto_p (ls,lv),AsegNE_p (ra,rb) ->
              if is_same_sv ls ra
              then
                let fresh_c = global_get_new_var () in
                let fresh_u = global_get_new_var () in
                let f,norm = (helper orig_lhs_p lhs
                                     ((mkEq (mkVar fresh_c) (incOne (mkVar ra)))::rhs_p,([mkPointsto_p ra fresh_u; mkAseg_p fresh_c rb]@rtail))
                                     ([fresh_c;fresh_u]@vset) uqset uqset_eq
                                     frame antiframe (indent+1))
                in
                (print_and_return f indent,norm)
              else
                let (uset,vsetprime) = mkUsetandVsetprime [ls;ra] vset in
                let case1 = (mkEqSv ls ra) in
                let case2 = (mkLtSv ls ra) in
                let case3 = (mkGtSv ls ra) in
                let f1,norm1 = helper orig_lhs_p (case1::lhs_p, lhs_h) (rhs_p, (mkAsegNE_p ls rb)::rtail) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                let f2,norm2 = helper orig_lhs_p (case2::lhs_p, lhs_h) (rhs_p, (mkGap_p ls ra)::rhs_h) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                let f3,norm3 = helper orig_lhs_p (case3::lhs_p, (mkGap_p ra ls)::lhs_h) (rhs_p, rhs_h) vsetprime uqset uqset_eq frame antiframe (indent+1) in
                (print_and_return (mkBExists (uset, BAnd [f1;f2;f3])) indent,combine_norm [norm1;norm2;norm3] [case1;case2;case3] uset)

           | Gap_p _, Gap_p _ ->
              failwith "Gap_p vs Gap_p: Invalid case"
         )
  in
  (* Both LHS and RHS are given some order *)
  let helper_entry (lhs_e,lhs_p,lhs_h) (rhs_e,rhs_p,rhs_h) =
    let new_lhs_p = (get_sorted_puref_general lhs_h)::lhs_p in
    let orig_rhs_p = (get_sorted_puref_general rhs_h)::rhs_p in
    let f,norm = helper lhs_p (new_lhs_p,lhs_h) (orig_rhs_p,rhs_h) rhs_e [] [] [] [] 0 in
    (mkBForall (lhs_e,f),norm,mkAndlst lhs_p)
  in

  let get_sat_perm orig_pure hlst =
    List.fold_left
      (fun r perm ->
        let perm_pure = get_sorted_puref_general perm in
        if isSat (mkAndlst (perm_pure::orig_pure))
        then (perm_pure,perm)::r
        else r)
      [] (generic_get_permutation hlst)
  in

  (* LHS is given some order *)
  let helper_lhs_sorted (lhs_e,lhs_p,lhs_h) (rhs_e,rhs_p,rhs_h) =
    let rhs_perm = generic_get_permutation rhs_h in
    match (List.map
             (fun item ->
               helper_entry (lhs_e,lhs_p,lhs_h) (rhs_e,rhs_p,item))
             rhs_perm ) with
    | [h] -> h
    | h::tail ->
       (List.fold_left
          (fun (rf,NormOr rnorm,rlhsp) (nf,NormOr nnorm,nlhsp) ->
            (mkBOr [rf;nf], NormOr (rnorm@nnorm),rlhsp)))
         h tail
    | [] -> failwith "helper_lhs_sorted: Empty output"
  in


  (* Neither side is given any order *)
  let helper_lhs_unsorted (lhs_e,lhs_p,lhs_h) (rhs_e,rhs_p,rhs_h) =
    let lhs_p = (get_segment_pure lhs_h)@lhs_p in                                           
    let disjoint_lhs_pure = get_disjoint_pure lhs_h in
    let (lhs_perm_pure,lhs_perm) = List.split (get_sat_perm lhs_p lhs_h) in
    let (flst,normlst,lhs_p_lst) = split_list_3
                                     (List.map
                                        (fun item ->
                                          helper_lhs_sorted (lhs_e,lhs_p,item)
                                                            (rhs_e,rhs_p,rhs_h))
                                        lhs_perm)
    in
    (mkBAnd flst,combine_norm normlst lhs_perm_pure [],mkAndlst (disjoint_lhs_pure::lhs_p))
  in
  let transAnte = new arrPredTransformer_orig lhs in
  let transConseq = new arrPredTransformer_orig rhs in
  helper_lhs_unsorted (aPredF_to_asegF (transAnte#formula_to_general_formula)) (aPredF_to_asegF (transConseq#formula_to_general_formula))
;;


(* norm: normalized pre-condition, in the form of (Exists V0:forall V1:Exists V2: f*)
let extract_anti_frame_and_frame norm =
  let neg_to_pure eset clst base base_uset base_eset pflst =
    (mkExists eset
              (mkAndlst
                 (clst@
                    [(mkForall base_uset
                               (mkExists base_eset
                                         (mkNot
                                            (mkAndlst pflst))))])))
  in

  let extract_helper lst =    
    let rec merge_result imply_lst_after_removed_uv =
      let merge_helper (eset,lhs_p,rhs_p,afpure,antiframe,frame) lst =
        let (to_merge,rest)=
          List.partition
            (fun ((neset,_,_,_,nantiframe,nframe) as item) ->
              (compare_sv_lst eset neset) && (compare_asegPredplus_lst frame nframe) && (compare_asegPredplus_lst antiframe nantiframe))
            lst
        in
        ((fun (eset,lhs_p,rhs_p,pure,antiframe,frame) ->
          (eset,lhs_p,rhs_p,simplify_p pure,antiframe,frame))
           (List.fold_left
              (fun (reset,rlhs_p,rrhs_p,rpure,rantiframe,rframe) (neset,nlhs_p,nrhs_p,npure,nantiframe,nframe) ->
                (reset,rlhs_p,rrhs_p,mkOr rpure npure,rantiframe,rframe))
              (eset,lhs_p,rhs_p,afpure,antiframe,frame) to_merge),
         rest)
      in
      match imply_lst_after_removed_uv with
      | h::tail ->
         let (newh,rest) = merge_helper h tail in
         newh::(merge_result rest)
      | [] -> []
    in
    
    let remove_uv eset clst (iuset,ieset,lhs_p,rhs_p,frame,antiframe) =
      let inner_pure =
        (mkForall
           iuset
           (mkExists
              ieset
              (mkImply (mkAndlst lhs_p) (mkAndlst rhs_p))))
      in
      if isSat inner_pure && true
      then
        let anti_frame_pure =
          (* let f = get_gist (mkExists iuset (mkAndlst (clst@rhs_p))) (mkAndlst lhs_p) in *)
          let f = (mkExists iuset (mkAndlst (clst@rhs_p))) in
          f
        in
        Some (eset@ieset,lhs_p,rhs_p,anti_frame_pure,frame,antiframe)
      else
        None
    in

    let remove_aseg pure hlst =
      List.rev
        (List.fold_left
           (fun r item ->
             match item with
             | Aseg_p (a,b) ->
                if isValid (mkImply pure (mkEqSv a b))
                then r
                else item::r
             | _ -> item ::r)
           [] hlst)
    in
        
    let norm_imply_to_antiframe_frame (eset,lhs_p,rhs_p,afpure,frame,antiframe) =
      let state_pure = simplify (mkAndlst (afpure::lhs_p)) in
      let norm_af = (eset,afpure,remove_aseg state_pure antiframe) in
      let frame_pure = state_pure in
      let norm_f = (eset,frame_pure,remove_aseg state_pure frame) in
      (norm_af,norm_f)
    in
    
    let (imply,neg) =
      List.fold_left
        (fun (ir,nr) (eset,clst,base) ->
          match base with
          | NormBaseNeg (iuset,ieset,pf)-> (ir,(mkOr (neg_to_pure eset clst base iuset ieset pf) nr))
          | NormBaseImply (iuset,ieset,lhs_p,rhs_p,frame,antiframe) ->
             ( match remove_uv eset clst (iuset,ieset,lhs_p,rhs_p,frame,antiframe) with
               | Some norm_imply ->
                  (norm_imply::ir,nr)
               | None -> (ir,nr)
             )
        )
        ([],mkFalse ()) lst
    in
    (List.map norm_imply_to_antiframe_frame (merge_result imply),neg)
  in
  match norm with
  | NormOr lst ->
     extract_helper lst
;;

      

(* From asegPlus to h_formula *)
let arrPredPlus_to_h_formula hflst =  
  let one_arrPredPlus_to_h_formula p =
    let basePtr = mkSV "base" in
    match p with
    | AsegNE_p (s,e) ->
       mkViewNode basePtr "AsegNE" [s;e]
    | Aseg_p (s,e) ->
       mkViewNode basePtr "Aseg" [s;e]
    | Pointsto_p (s,v) ->
       mkViewNode basePtr "Elem" [s;v]
    | _ -> failwith "arrPredPlus_to_h_formula: TO BE IMPLEMENTED"
  in
  let construct_h_formula plst =
    match (List.map one_arrPredPlus_to_h_formula plst) with
    | h::tail -> Some (List.fold_left (fun r itemh -> mkStarH itemh r) h tail)
    | [] -> None
  in
  construct_h_formula hflst
;;


let construct_context_lst aflst neg =
  let construct_helper_imply ((aeset,apf,ahlst),(feset,fpf,phlst)) =
    let es = mkEmptyes () in
    let h_antiframe_lst =
      match arrPredPlus_to_h_formula ahlst with
      | Some nh -> [nh]
      | None -> []
    in
    let h_frame =
      match arrPredPlus_to_h_formula phlst with
      | Some nh -> nh
      | None -> HEmp
    in
    let () = y_tinfo_pp ("h_frame:"^(!Cformula.print_h_formula h_frame)) in
    let state =
      if List.length feset = 0
      then
        construct_base h_frame fpf
      else
        construct_exists h_frame fpf feset
    in
    let infer_pure = simplify (mkExists aeset apf) in
    mkCtx
      {es with
        es_formula = state ;
        es_infer_heap = h_antiframe_lst;
        es_infer_pure = [infer_pure];
      }
  in
  let construct_helper_neg pf =
    let es = mkEmptyes () in
    mkCtx
      {es with
        es_formula = construct_false ();
        es_infer_pure = [pf];
      }
  in
  let imply_ctx = List.map construct_helper_imply aflst in
  let neg_ctx = construct_helper_neg neg in
  if !Globals.array_entailment_frame
  then imply_ctx
  else
    if List.length imply_ctx > 0 && isFalse neg
    then imply_ctx
    else
      if List.length imply_ctx > 0
      then neg_ctx::imply_ctx
      else
        [neg_ctx]
;;

let merge_context_lst_for_frame clst lhs_p =
  match clst with
  | (Cformula.Ctx h)::tail ->
     let ctx =
       let (infer_f,state_f) =
         List.fold_left
           (fun (infer_f,state_f) item ->
             match item with
             | Cformula.Ctx es ->
                (mkOr infer_f (mkAndlst es.es_infer_pure),mkCformulaOr state_f es.es_formula)
             | _ -> failwith "merge_context_lst_for_frame: TO BE IMPLEMENTED")
           (mkAndlst h.Cformula.es_infer_pure,h.Cformula.es_formula) tail
       in
       let infer_f =  infer_f in
       let () = y_binfo_pp ("check frame "^(!str_pformula infer_f)) in
       let () = y_binfo_pp ("check frame "^(!str_pformula lhs_p)) in
       if isValid (simplify (mkImply lhs_p infer_f))
       then
         let () = y_binfo_pp ("check frame VALID") in
         let es = mkEmptyes () in
         (* Cformula.SuccCtx [Ctx {es with es_formula = state_f}] *)
         mkSuccCtx clst(* [(mkOCtx clst)] *)
       else
         mkEmptyFailCtx ()
     in
     let () = y_tinfo_pp ("List context: " ^(!Cformula.print_list_context ctx)) in
     ctx
  | _ -> mkEmptyFailCtx ()
;;
                        
  
let valid_classical_entailment lhs implylst neg =
  isValid
    (mkImply
       lhs
       (List.fold_left
          (fun r ((aeset,afpure,antiframe),(eset,fpure,frame)) ->
            if List.length frame = 0 && List.length antiframe = 0
            then mkOr (mkExists aeset afpure) r
            else failwith "valid_classical_entailment: Invalid input")
          neg implylst))
;;


  

let drop_antiframe implylst =
  List.filter
    (fun ((aeset,afp,antiframe),(eset,fp,frame)) ->
      List.length antiframe = 0 (* && isValid (mkExists aeset afp) *))
    implylst
;;

let array_entailment_biabduction_get_norm lhs rhs =
  let () = print_endline_verbose ("=========== input LHS formula ==============") in
  let () = print_endline_verbose (!str_cformula lhs) in
  let () = print_endline_verbose ("=========== input RHS formula ==============") in
  let () = print_endline_verbose (!str_cformula rhs) in

  let (f,norm,lhs_p) = array_entailment_biabduction_norm lhs rhs in
  let () = print_endline_verbose ("=========== formatted pre-condition ==============") in
  let () = print_endline_verbose (str_pre_condition f) in
  let () = print_endline_verbose ("=========== Normalized pre-condition ==============") in
  let () = print_endline_verbose (str_norm_pre_condition norm) in
  (* let () = print_endline_verbose ("=========== Simplified Normalized pre-condition ==============") in *)
  let simp_norm = simplify_norm_pre_condition norm in
  (f,simp_norm,lhs_p)
;;

let array_entailment_classical_entailment_interface lhs rhs =
  let (f,simp_norm,lhs_p) = array_entailment_biabduction_get_norm lhs rhs in
  let (implylst,neg) = extract_anti_frame_and_frame simp_norm in
  
  (* if valid_classical_entailment (mkTrue ()) implylst neg *)
  if check_validity f
  then
    mkEmptySuccCtx ()
  else
    mkEmptyFailCtx ()
;;
  
let array_entailment_biabduction_interface lhs rhs =
  let (f,simp_norm,_) = array_entailment_biabduction_get_norm lhs rhs in
  let (implylst,neg) = extract_anti_frame_and_frame simp_norm in
  mkSuccCtx (construct_context_lst implylst neg)
(* (true, mkEmptySuccCtx (),[]) *)
;;

let array_entailment_frame_interface lhs rhs =
  let (f,simp_norm,lhs_p) = array_entailment_biabduction_get_norm lhs rhs in
  let (implylst,neg) = extract_anti_frame_and_frame simp_norm in
  let dropped_implylst = construct_context_lst (drop_antiframe implylst) (mkTrue ()) in
  let list_ctx = merge_context_lst_for_frame dropped_implylst lhs_p in
  list_ctx
  (* (true, mkSuccCtx (construct_context_lst (drop_antiframe implylst) neg), []) *)
(* (true, mkEmptySuccCtx (),[]) *)
;;  

  