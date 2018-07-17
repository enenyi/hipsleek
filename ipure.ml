#include "xdebug.cppo"
(*
  Created 19-Feb-2006

  Input pure constraints, including arithmetic and pure pointer
*)

open Globals
open Gen.Basic
open VarGen
open Label
include Ipure_D

let print_formula = ref (fun (c:formula) -> "cpure printer has not been initialized")
let print_b_formula = ref (fun (c:b_formula) -> "cpure printer has not been initialized")
let print_formula_exp = ref (fun (c:exp) -> "cpure printer has not been initialized")
let print_id = ref (fun (c:(ident*primed)) -> "cpure printer has not been initialized")
let print_exp = print_formula_exp

module Exp_Pure =
struct
  type e = formula
  let comb x y = And (x,y,no_pos)
  let string_of = !print_formula
  let ref_string_of = print_formula
end;;

module Label_Pure = LabelExpr(LO)(Exp_Pure);; 

let linking_exp_list = ref (Hashtbl.create 100)
let () = let zero = IConst (0, no_pos)
  in Hashtbl.add !linking_exp_list zero 0


(* free variables *)

let rec fv (f : formula) : (ident * primed) list = match f with 
  | BForm (b,_) -> bfv b
  | And (p1, p2, _) -> combine_pvars p1 p2
  | AndList b -> Gen.BList.remove_dups_eq (=) (Gen.fold_l_snd fv b)
  | Or (p1, p2, _,_) -> combine_pvars p1 p2
  | Not (nf, _,_) -> fv nf
  | Forall (qid, qf, _,_) -> remove_qvar qid qf
  | Exists (qid, qf, _,_) -> remove_qvar qid qf

and combine_pvars p1 p2 = 
  let fv1 = fv p1 in
  let fv2 = fv p2 in
  Gen.BList.remove_dups_eq (=) (fv1 @ fv2)

and remove_qvar qid qf =
  let qfv = fv qf in
  Gen.BList.remove_elem_eq (=) qid qfv


and bfv (bf : b_formula) =
  let (pf,_) = bf in
  pfv pf

and pfv (pf: p_formula)=
  match pf with
  | XPure ({xpure_view_node = vn ;
            xpure_view_name = vname;
            xpure_view_arguments = args})  ->  [] (*TODO*)
  | Frm (sv,p) -> [sv]
  | BConst _ -> []
  | BVar (bv, _) -> [bv]
  | Lt (a1, a2, _) | Lte (a1, a2, _) 
  | Gt (a1, a2, _) | Gte (a1, a2, _) 
  | SubAnn (a1, a2, _) 
  | Eq (a1, a2, _) 
  | Neq (a1, a2, _) -> combine_avars a1 a2
  | EqMax (a1, a2, a3, _) -> 
    let fv1 = afv a1 in
    let fv2 = afv a2 in
    let fv3 = afv a3 in
    Gen.BList.remove_dups_eq (=) (fv1 @ fv2 @ fv3)
  | EqMin (a1, a2, a3, _) ->
    let fv1 = afv a1 in
    let fv2 = afv a2 in
    let fv3 = afv a3 in
    Gen.BList.remove_dups_eq (=) (fv1 @ fv2 @ fv3)
  | BagIn (v, a, _) -> 
    let fv = afv a in
    Gen.BList.remove_dups_eq (=) ([v] @ fv)
  | BagNotIn (v, a, _) -> 
    let fv = afv a in
    Gen.BList.remove_dups_eq (=) ([v] @ fv)	
  | BagSub (a1, a2, _) -> combine_avars a1 a2
  | BagMax (sv1, sv2, _) -> Gen.BList.remove_dups_eq (=) ([sv1] @ [sv2])
  | BagMin (sv1, sv2, _) -> Gen.BList.remove_dups_eq (=) ([sv1] @ [sv2])
  (*   | VarPerm (ct,ls,_) ->                         *)
  (*     ls                                           *)
  (* let ls1 = List.map (fun v -> (v,Unprimed)) ls in *)
  (* ls1                                              *)
  | ListIn (a1, a2, _) -> 
    let fv1 = afv a1 in
    let fv2 = afv a2 in
    Gen.BList.remove_dups_eq (=) (fv1 @ fv2)
  | ListNotIn (a1, a2, _) -> 
    let fv1 = afv a1 in
    let fv2 = afv a2 in
    Gen.BList.remove_dups_eq (=) (fv1 @ fv2)
  | ListAllN (a1, a2, _) ->
    let fv1 = afv a1 in
    let fv2 = afv a2 in
    Gen.BList.remove_dups_eq (=) (fv1 @ fv2)
  | ListPerm (a1, a2, _) ->
    let fv1 = afv a1 in
    let fv2 = afv a2 in
    Gen.BList.remove_dups_eq (=) (fv1 @ fv2)
  | RelForm (_,args,_) -> (* An Hoa *)
    let args_fv = List.concat (List.map afv args) in
    Gen.BList.remove_dups_eq (=) args_fv
  | ImmRel (rel, _ , _) -> pfv rel
  | LexVar (_, args1, args2, _) ->
    let args_fv = List.concat (List.map afv (args1@args2)) in
    Gen.BList.remove_dups_eq (=) args_fv


and combine_avars (a1 : exp) (a2 : exp) : (ident * primed) list = 
  let fv1 = afv a1 in
  let fv2 = afv a2 in
  Gen.BList.remove_dups_eq (=) (fv1 @ fv2)

and afv (af : exp) : (ident * primed) list = match af with
  | Level (sv, _) -> [sv]
  | Var (sv, _) ->
    let id = fst sv in
    if (id.[0] = '#') then [] else [sv]
  | Null _ 
  | AConst _ 
  | IConst _ 
  | Tsconst _ 
  | InfConst _
  | NegInfConst _
  | FConst _ -> []
  | Bptriple ((ec,et,ea),_) -> Gen.BList.remove_dups_eq (=) ((afv ec) @ (afv et) @ (afv ea))
  | Tup2 ((e1,e2),_) -> Gen.BList.remove_dups_eq (=) ((afv e1) @ (afv e2))
  | Ann_Exp (e,_,_) -> afv e
  | Add (a1, a2, _) -> combine_avars a1 a2
  | Subtract (a1, a2, _) -> combine_avars a1 a2
  | Mult (a1, a2, _) | Div (a1, a2, _) -> combine_avars a1 a2
  | Max (a1, a2, _) -> combine_avars a1 a2
  | Min (a1, a2, _) -> combine_avars a1 a2
  | TypeCast (_, a, _) -> afv a
  | BagDiff (a1,a2,_) ->  combine_avars a1 a2
  | Bag(d,_)
  | BagIntersect (d,_)
  | BagUnion (d,_) ->  Gen.BList.remove_dups_eq (=) (List.fold_left (fun a c-> a@(afv c)) [] d)
  | List (d, _)
  | ListAppend (d, _) -> Gen.BList.remove_dups_eq (=) (List.fold_left (fun a c -> a@(afv c)) [] d)
  | ListCons (a1, a2, _) ->
    let fv1 = afv a1 in
    let fv2 = afv a2 in
    Gen.BList.remove_dups_eq (=) (fv1 @ fv2)  
  | ListHead (a, _)
  | ListTail (a, _)
  | ListLength (a, _)
  | ListReverse (a, _) -> afv a
  | Func (a, i, _) -> 
    let ifv = List.flatten (List.map afv i) in
    Gen.BList.remove_dups_eq (=) ((a,Unprimed) :: ifv)
  | ArrayAt (a, i, _) -> 
    let ifv = List.flatten (List.map afv i) in
    Gen.BList.remove_dups_eq (=) (a :: ifv) (* An Hoa *)
  | BExpr f1 -> fv f1
  | Template t -> 
    (List.concat (List.map afv t.templ_args)) 
(* @ (List.concat (List.map afv t.templ_unks)) *)

and is_max_min a = match a with
  | Max _ | Min _ -> true
  | _ -> false

and is_null (e : exp) : bool = match e with
  | Null _ -> true
  | _ -> false

and is_var (e : exp) : bool = match e with
  | Var _ -> true
  | _ -> false

and is_bag (e : exp) : bool = match e with
  | Bag _
  | BagUnion _
  | BagIntersect _
  | BagDiff _ -> true
  | _ -> false

and is_integer e =
  match e with
  | IConst _ -> true
  | Add (e1, e2, _) | Subtract (e1, e2, _) | Mult (e1, e2, _)
  | Max (e1, e2, _) | Min (e1, e2, _) ->
    is_integer e1 && is_integer e2
  | _ -> false

and is_list (e : exp) : bool = match e with
  | List _
  | ListCons _
  | ListTail _
  | ListAppend _
  | ListReverse _ -> true
  | _ -> false

and name_of_var (e : exp) : ident = match e with
  | Var ((v, p), pos) -> v
  | _ -> failwith ("parameter to name_of_var is not a variable")

and isConstTrue p = match p with
  | BForm ((BConst (true, pos), _), _) -> true
  | _ -> false

and isConstFalse p = match p with
  | BForm ((BConst (false, pos), _), _) -> true
  | _ -> false

(* smart constructor *)
and mkXPure id cl pos = 
  XPure {
    xpure_view_node = None;
    xpure_view_name = id;
    xpure_view_arguments = cl;
    xpure_view_remaining_branches = None;
    xpure_view_pos = pos;
  }

and mkAdd a1 a2 pos = Add (a1, a2, pos)

and mkSubtract a1 a2 pos = Subtract (a1, a2, pos)

and mkMult a1 a2 pos = Mult (a1, a2, pos)

and mkAnnExp a1 t pos = Ann_Exp (a1, t, pos)

and mkDiv a1 a2 pos = Div (a1, a2, pos)

and mkMax a1 a2 pos = Max (a1, a2, pos)

and mkMin a1 a2 pos = Min (a1, a2, pos)

and mkTypeCast t a pos = TypeCast (t, a, pos)

and mkTemplate id args pos = Template {
    templ_id = id;
    templ_args = args;
    templ_unks = [];
    templ_body = None; (* Need to fill in trans_exp *)
    templ_pos = pos;
  }

and mkUtAnn nid sid is_pre fname cond args pos = 
  let uid = {
    tu_id = nid;
    tu_sid = sid;
    tu_fname = fname;
    tu_args = args;
    tu_cond = cond;
    tu_pos = pos;
  } in
  if is_pre then TermU uid
  else TermR uid 

and mkUimmAnn is_pre cond = 
  if is_pre then PreImm cond
  else PostImm cond

and mkBVar (v, p) pos = BVar ((v, p), pos)

and mkLt a1 a2 pos = 
  if is_max_min a1 || is_max_min a2 then 
    failwith ("max/min can only be used in equality")  
  else 
    Lt (a1, a2, pos)

and mkLte a1 a2 pos = 
  if is_max_min a1 || is_max_min a2 then 
    failwith ("max/min can only be used in equality")  
  else 
    Lte (a1, a2, pos)

and mkGt a1 a2 pos = 
  if is_max_min a1 || is_max_min a2 then 
    failwith ("max/min can only be used in equality")  
  else 
    Gt (a1, a2, pos)

and mkGte a1 a2 pos = 
  if is_max_min a1 || is_max_min a2 then 
    failwith ("max/min can only be used in equality")  
  else 
    Gte (a1, a2, pos)

and mkSubAnn a1 a2 pos = 
  if is_max_min a1 || is_max_min a2 then 
    failwith ("max/min can only be used in equality")  
  else 
    SubAnn (a1, a2, pos)

and mkNeq a1 a2 pos = 
  if is_max_min a1 || is_max_min a2 then 
    failwith ("max/min can only be used in equality")  
  else 
    Neq (a1, a2, pos)

and mkEq a1 a2 pos = 
  if is_max_min a1 && is_max_min a2 then
    failwith ("max/min can only appear in one side of an equation")
  else if is_max_min a1 then
    match a1 with
    | Min (a11, a12, _) -> EqMin (a2, a11, a12, pos)
    | Max (a11, a12, _) -> EqMax (a2, a11, a12, pos)
    | _ -> failwith ("Presburger.mkAEq: something really bad has happened")
  else if is_max_min a2 then 
    match a2 with
    | Min (a21, a22, _) -> EqMin (a1, a21, a22, pos)
    | Max (a21, a22, _) -> EqMax (a1, a21, a22, pos)
    | _ -> failwith ("Presburger.mkAEq: something really bad has happened")
  else 
    Eq (a1, a2, pos)

(* and mkBExpr e f= *)
(*   BExpr pf *)

and mkAnd_x f1 f2 pos = match f1 with
  | BForm ((BConst (false, _), _), _) -> f1
  | BForm ((BConst (true, _), _), _) -> f2
  | _ -> match f2 with
    | BForm ((BConst (false, _), _), _) -> f2
    | BForm ((BConst (true, _), _), _) -> f1
    | _ ->
      match f1,f2 with 
      | AndList b1, AndList b2 -> mkAndList (Label_Pure.merge b1 b2)
      | AndList b, f -> mkAndList (Label_Pure.merge b [(LO.unlabelled,f)])
      | f, AndList b -> mkAndList (Label_Pure.merge b [(LO.unlabelled,f)])
      | _ -> And (f1, f2, pos) (* it's ok not to check for disjs containing AndList, this will be solved later, during the translation to cpure *)
(* if no_andl f1 && no_andl f2 then And (f1, f2, pos)  *)
(*      else report_error no_pos "Ipure: unhandled/unexpected mkAnd with andList case" *)

and mkAnd f1 f2 pos = 
  let pr = !print_formula in
  (* Debug.no_2 "mkAnd" pr pr pr *) (fun _ _ -> mkAnd_x f1 f2 pos) f1 f2

and mkAndList b = (*print_string "ipure_list_gen\n";*) AndList b

and no_andl  = function
  | BForm _ | And _ | Not _ | Forall _ | Exists _  -> true
  | Or (f1,f2,_,_) -> no_andl f1 && no_andl f2
  | AndList _ -> false 

and mkOr f1 f2 lbl pos = match f1 with
  | BForm ((BConst (false, _), _), _) -> f2
  | BForm ((BConst (true, _), _), _) -> f1
  | _ -> match f2 with
    | BForm ((BConst (false, _), _), _) -> f1
    | BForm ((BConst (true, _), _), _) -> f2
    | _ -> Or (f1, f2, lbl, pos)

and mkEqVarExp (v1 : (ident * primed)) (v2 : (ident * primed)) pos =
  let e1 = Var (v1,pos) in
  let e2 = Var (v2,pos) in
  mkEqExp e1 e2 pos

and mkEqExp (ae1 : exp) (ae2 : exp) pos = match (ae1, ae2) with
  | (Var v1, Var v2) ->
    if v1 = v2 then
      mkTrue pos
    else
      BForm ((Eq (ae1, ae2, pos), None), None)
  | _ ->  BForm ((Eq (ae1, ae2, pos), None), None)

and mkNeqExp (ae1 : exp) (ae2 : exp) pos = match (ae1, ae2) with
  | (Var v1, Var v2) ->
    if v1 = v2 then
      mkFalse pos
    else
      BForm ((Neq (ae1, ae2, pos), None), None)
  | _ ->  BForm ((Neq (ae1, ae2, pos), None), None)

and mkNot f lbl pos = Not (f, lbl, pos)

and mkTrue pos = BForm ((BConst (true, pos), None), None)

and mkFalse pos = BForm ((BConst (false, pos), None) , None)

and mkExists (vs : (ident * primed) list) (f : formula) lbl pos = match vs with
  | [] -> f
  | v :: rest -> 
    let ef = mkExists rest f lbl pos in
    if List.mem v (fv ef) then
      Exists (v, ef,lbl,  pos)
    else
      ef

and mkForall (vs : (ident * primed) list) (f : formula) lbl pos = match vs with
  | [] -> f
  | v :: rest -> 
    let ef = mkForall rest f lbl pos in
    if List.mem v (fv ef) then
      Forall (v, ef, lbl, pos)
    else
      ef

(* build relation from list of expressions, for example a,b,c < d,e, f *)
and build_relation relop alist10 alist20 pos = 
  let rec helper1 ae alist = 
    let a = List.hd alist in
    let rest = List.tl alist in
    let tmp = BForm ((relop ae a pos),None) in
    if Gen.is_empty rest then
      tmp
    else
      let tmp1 = helper1 ae rest in
      let tmp2 = mkAnd tmp tmp1 pos in
      tmp2 in
  let rec helper2 alist1 alist2 =
    let a = List.hd alist1 in
    let rest = List.tl alist1 in
    let tmp = helper1 a alist2 in
    if Gen.is_empty rest then
      tmp
    else
      let tmp1 = helper2 rest alist2 in
      let tmp2 = mkAnd tmp tmp1 pos in
      tmp2 in
  if List.length alist10 = 0 || List.length alist20 = 0 then
    failwith ("build_relation: zero-length list")
  else begin
    helper2 alist10 alist20
  end

(* An Hoa *)
and pos_of_formula (f : formula) = match f with 
  | BForm ((pf,_),_) -> pos_of_pf pf
  | And (_,_,p) | Or (_,_,_,p) | Not (_,_,p)
  | Forall (_,_,_,p) -> p | Exists (_,_,_,p) -> p
  | AndList l -> match l with | x::_ -> pos_of_formula (snd x) | _-> no_pos


and pos_of_pf pf=
  begin match pf with
    | Frm (_, p) -> p
    | BConst (_,p) | BVar (_,p)
    | Lt (_,_,p) | Lte (_,_,p) | Gt (_,_,p) | Gte (_,_,p) | SubAnn (_,_,p) | Eq (_,_,p) | Neq (_,_,p)
    | EqMax (_,_,_,p) | EqMin (_,_,_,p) 
    | BagIn (_,_,p) | BagNotIn (_,_,p) | BagSub (_,_,p) | BagMin (_,_,p) | BagMax (_,_,p)	
    | ListIn (_,_,p) | ListNotIn (_,_,p) | ListAllN (_,_,p) | ListPerm (_,_,p)
    | RelForm (_,_,p)  | LexVar (_,_,_,p) | ImmRel (_,_,p) -> p
    (* | VarPerm (_,_,p) -> p *)
    | XPure xp ->  xp.xpure_view_pos
  end

and pos_of_exp (e : exp) = match e with
  | Null p 
  | Var (_, p) 
  | Level (_, p) 
  | IConst (_, p) 
  | FConst (_, p) 
  | Tsconst (_, p)
  | Bptriple (_, p)
  | Tup2 (_, p)
  | InfConst (_, p)
  | NegInfConst (_, p)
  | AConst (_, p) -> p
  | Ann_Exp (e,_,p) -> p
  | Add (_, _, p) -> p
  | Subtract (_, _, p) -> p
  | Mult (_, _, p) -> p
  | Div (_, _, p) -> p
  | Max (_, _, p) -> p
  | Min (_, _, p) -> p
  | TypeCast (_, _, p) -> p
  | Bag (_, p) -> p
  | BagUnion (_, p) -> p
  | BagIntersect (_, p) -> p
  | BagDiff (_, _, p) -> p
  | List (_, p) -> p
  | ListAppend (_, p) -> p
  | ListCons (_, _, p) -> p
  | ListHead (_, p) -> p
  | ListTail (_, p) -> p
  | ListLength (_, p) -> p
  | ListReverse (_, p) -> p
  | Func (_, _, p) -> p
  | ArrayAt (_ ,_ , p) -> p (* An Hoa *)
  | BExpr f1 -> pos_of_formula f1
  | Template t -> t.templ_pos


and fresh_old_name (s: string):string =
  let fn s = 
    let l = String.length s in
    try  
      let c = (String.rindex s '_') in
      (* let () = x_ninfo_hp (add_str "string" pr_id) s no_pos in *)
      (* let () = x_binfo_hp (add_str "pos _ " string_of_int) c no_pos in *)
      (* let () = x_binfo_hp (add_str "pos len " string_of_int) l no_pos in *)
      let trail = String.sub s (c+1) (l-c-1) in
      (* let () = x_binfo_hp (add_str "trail" pr_id) trail no_pos in *)
      let (_:int64) = Int64.of_string trail in
      c
    with  _ -> l 
  in
  let ri = fn s in
  let n = ((String.sub s 0 ri) ^ (fresh_trailer ())) in
  n


and fresh_var (sv : (ident*primed)):(ident*primed) =
  let old_name = fst sv in
  let name = fresh_old_name old_name in
  (name, Unprimed) (* fresh names are unprimed *)

and fresh_vars (svs : (ident*primed) list):(ident*primed) list = List.map fresh_var svs

and eq_var (f: (ident*primed))(t:(ident*primed)):bool = 
  ((String.compare (fst f) (fst t))==0) &&(snd f)==(snd t) 

and eq_ann (a1 :  ann) (a2 : ann) : bool =
  match a1, a2 with
  | ConstAnn ha1, ConstAnn ha2 -> ha1 == ha2
  | PolyAnn (sv1,_), PolyAnn (sv2,_) -> eq_var sv1 sv2
  | _ -> false

(* andreeac TODOIMM use wrapper below, use emap for spec eq *)
and eq_ann_list (a1 :  ann list) (a2 : ann list) : bool =
  List.fold_left (fun acc (a1,a2) -> acc &&(eq_ann a1 a2)) true (List.combine a1 a2)

and subst sst (f : formula) = match sst with
  | s :: rest -> subst rest (apply_one s f)
  | [] -> f 

and apply_one (fr, t) f = match f with
  | BForm (bf,lbl) -> BForm (b_apply_one (fr, t) bf, lbl)
  | AndList b -> AndList (Gen.map_l_snd (apply_one (fr,t)) b)
  | And (p1, p2, pos) -> And (apply_one (fr, t) p1,
                              apply_one (fr, t) p2, pos)
  | Or (p1, p2, lbl, pos) -> Or (apply_one (fr, t) p1,
                                 apply_one (fr, t) p2, lbl, pos)
  | Not (p, lbl, pos) -> Not (apply_one (fr, t) p, lbl, pos)
  | Forall (v, qf, lbl, pos) ->
    if eq_var v fr then f
    else if eq_var v t then
      let fresh_v = fresh_var v in
      Forall (fresh_v, apply_one (fr, t) (apply_one (v, fresh_v) qf), lbl, pos)
    else Forall (v, apply_one (fr, t) qf, lbl, pos)
  | Exists (v, qf, lbl, pos) ->
    if eq_var v fr then f
    else if eq_var v t then
      let fresh_v = fresh_var v in
      Exists (fresh_v, apply_one (fr, t) (apply_one (v, fresh_v) qf), lbl, pos)
    else Exists (v, apply_one (fr, t) qf, lbl, pos)

and b_apply_one ((fr, t) as p) bf =
  let (pf,il) = bf in
  let npf = p_apply_one p pf
  (* match pf with *)
  (*   | XPure ({xpure_view_node = vn ; *)
  (*       	      xpure_view_arguments = args} as xp)  ->  *)
  (*       let fr,_ = fr in *)
  (*       let t,_ = t in *)
  (*       let new_vn = *)
  (*         match vn with *)
  (*           | None -> None *)
  (*           | Some v -> *)
  (*               let new_v = (if v=fr then t else v) in *)
  (*               Some new_v *)
  (*       in *)
  (*       let new_args = List.map (fun v -> if v=fr then t else v) args in *)
  (*       XPure ({ xp with xpure_view_node = new_vn ; *)
  (*       	    xpure_view_arguments = new_args}) *)
  (* | BConst _ -> pf *)
  (* | Frm (bv, pos) -> BVar (v_apply_one p bv, pos) *)
  (* | BVar (bv, pos) -> BVar (v_apply_one p bv, pos) *)
  (* | Lt (a1, a2, pos) -> Lt (e_apply_one (fr, t) a1, *)
  (*       						e_apply_one (fr, t) a2, pos) *)
  (* | Lte (a1, a2, pos) -> Lte (e_apply_one (fr, t) a1, *)
  (*       						  e_apply_one (fr, t) a2, pos) *)
  (* | Gt (a1, a2, pos) -> Gt (e_apply_one (fr, t) a1, *)
  (*       						e_apply_one (fr, t) a2, pos) *)
  (* | Gte (a1, a2, pos) -> Gte (e_apply_one (fr, t) a1, *)
  (*       						  e_apply_one (fr, t) a2, pos) *)
  (* | SubAnn (a1, a2, pos) -> SubAnn (e_apply_one (fr, t) a1, *)
  (*       						  e_apply_one (fr, t) a2, pos) *)
  (* | Eq (a1, a2, pos) -> Eq (e_apply_one (fr, t) a1, *)
  (*       						e_apply_one (fr, t) a2, pos) *)
  (* | Neq (a1, a2, pos) -> Neq (e_apply_one (fr, t) a1, *)
  (*       						  e_apply_one (fr, t) a2, pos) *)
  (* | EqMax (a1, a2, a3, pos) -> EqMax (e_apply_one (fr, t) a1, *)
  (*       								  e_apply_one (fr, t) a2, *)
  (*       								  e_apply_one (fr, t) a3, pos) *)
  (* | EqMin (a1, a2, a3, pos) -> EqMin (e_apply_one (fr, t) a1, *)
  (*       								  e_apply_one (fr, t) a2, *)
  (*       								  e_apply_one (fr, t) a3, pos) *)
  (* | BagIn (v, a1, pos) -> BagIn (v_apply_one p v, e_apply_one (fr, t) a1, pos) *)
  (* | BagNotIn (v, a1, pos) -> BagNotIn (v_apply_one p v, e_apply_one (fr, t) a1, pos) *)
  (*       (\* is it ok?... can i have a set of boolean values?... don't think so... *\) *)
  (* | BagSub (a1, a2, pos) -> BagSub (e_apply_one (fr, t) a1, e_apply_one (fr, t) a2, pos) *)
  (* | BagMax (v1, v2, pos) -> BagMax (v_apply_one p v1, v_apply_one p v2, pos) *)
  (* | BagMin (v1, v2, pos) -> BagMin (v_apply_one p v1, v_apply_one p v2, pos) *)
  (* | VarPerm (ct,ls,pos) -> (\*TO CHECK*\) *)
  (*     let func v = v_apply_one p v in *)
  (*     let ls1 = List.map func ls in *)
  (*     VarPerm (ct,ls1,pos) *)
  (* | ListIn (a1, a2, pos) -> ListIn (e_apply_one (fr, t) a1, e_apply_one (fr, t) a2, pos) *)
  (* | ListNotIn (a1, a2, pos) -> ListNotIn (e_apply_one (fr, t) a1, e_apply_one (fr, t) a2, pos) *)
  (* | ListAllN (a1, a2, pos) -> ListAllN (e_apply_one (fr, t) a1, e_apply_one (fr, t) a2, pos) *)
  (* | ListPerm (a1, a2, pos) -> ListPerm (e_apply_one (fr, t) a1, e_apply_one (fr, t) a2, pos) *)
  (* | RelForm (r, args, pos) ->  *)
  (*         (\* An Hoa : apply to every arguments, alternatively, use e_apply_one_list *\) *)
  (*         RelForm (r, (List.map (fun x -> e_apply_one (fr, t) x) args), pos) *)
  (* | LexVar (t_ann, args1, args2, pos) ->  *)
  (*       let args1 = List.map (fun x -> e_apply_one (fr, t) x) args1 in *)
  (*       let args2 = List.map (fun x -> e_apply_one (fr, t) x) args2 in *)
  (*         LexVar (t_ann, args1,args2,pos) *)
  in (npf,il)

and p_apply_one ((fr, t) as p) pf =
  match pf with
  | XPure ({xpure_view_node = vn ;
            xpure_view_arguments = args} as xp)  -> 
    let fr,_ = fr in
    let t,_ = t in
    let new_vn =
      match vn with
      | None -> None
      | Some v ->
        let new_v = (if v=fr then t else v) in
        Some new_v
    in
    let new_args = List.map (fun v -> if v=fr then t else v) args in
    XPure ({ xp with xpure_view_node = new_vn ;
                     xpure_view_arguments = new_args})
  | BConst _ -> pf
  | Frm (bv, pos) -> BVar (v_apply_one p bv, pos)
  | BVar (bv, pos) -> BVar (v_apply_one p bv, pos)
  | Lt (a1, a2, pos) -> Lt (e_apply_one (fr, t) a1,
                            e_apply_one (fr, t) a2, pos)
  | Lte (a1, a2, pos) -> Lte (e_apply_one (fr, t) a1,
                              e_apply_one (fr, t) a2, pos)
  | Gt (a1, a2, pos) -> Gt (e_apply_one (fr, t) a1,
                            e_apply_one (fr, t) a2, pos)
  | Gte (a1, a2, pos) -> Gte (e_apply_one (fr, t) a1,
                              e_apply_one (fr, t) a2, pos)
  | SubAnn (a1, a2, pos) -> SubAnn (e_apply_one (fr, t) a1,
                                    e_apply_one (fr, t) a2, pos)
  | Eq (a1, a2, pos) -> Eq (e_apply_one (fr, t) a1,
                            e_apply_one (fr, t) a2, pos)
  | Neq (a1, a2, pos) -> Neq (e_apply_one (fr, t) a1,
                              e_apply_one (fr, t) a2, pos)
  | EqMax (a1, a2, a3, pos) -> EqMax (e_apply_one (fr, t) a1,
                                      e_apply_one (fr, t) a2,
                                      e_apply_one (fr, t) a3, pos)
  | EqMin (a1, a2, a3, pos) -> EqMin (e_apply_one (fr, t) a1,
                                      e_apply_one (fr, t) a2,
                                      e_apply_one (fr, t) a3, pos)
  | BagIn (v, a1, pos) -> BagIn (v_apply_one p v, e_apply_one (fr, t) a1, pos)
  | BagNotIn (v, a1, pos) -> BagNotIn (v_apply_one p v, e_apply_one (fr, t) a1, pos)
  (* is it ok?... can i have a set of boolean values?... don't think so... *)
  | BagSub (a1, a2, pos) -> BagSub (e_apply_one (fr, t) a1, e_apply_one (fr, t) a2, pos)
  | BagMax (v1, v2, pos) -> BagMax (v_apply_one p v1, v_apply_one p v2, pos)
  | BagMin (v1, v2, pos) -> BagMin (v_apply_one p v1, v_apply_one p v2, pos)
  (* | VarPerm (ct,ls,pos) -> (*TO CHECK*) *)
  (*     let func v = v_apply_one p v in   *)
  (*     let ls1 = List.map func ls in     *)
  (*     VarPerm (ct,ls1,pos)              *)
  | ListIn (a1, a2, pos) -> ListIn (e_apply_one (fr, t) a1, e_apply_one (fr, t) a2, pos)
  | ListNotIn (a1, a2, pos) -> ListNotIn (e_apply_one (fr, t) a1, e_apply_one (fr, t) a2, pos)
  | ListAllN (a1, a2, pos) -> ListAllN (e_apply_one (fr, t) a1, e_apply_one (fr, t) a2, pos)
  | ListPerm (a1, a2, pos) -> ListPerm (e_apply_one (fr, t) a1, e_apply_one (fr, t) a2, pos)
  | RelForm (r, args, pos) -> 
    (* An Hoa : apply to every arguments, alternatively, use e_apply_one_list *)
    RelForm (r, (List.map (fun x -> e_apply_one (fr, t) x) args), pos)
  | ImmRel (r, cond, pos) -> 
    (* An Hoa : apply to every arguments, alternatively, use e_apply_one_list *)
    ImmRel (p_apply_one p r, cond, pos)
  | LexVar (t_ann, args1, args2, pos) -> 
    let args1 = List.map (fun x -> e_apply_one (fr, t) x) args1 in
    let args2 = List.map (fun x -> e_apply_one (fr, t) x) args2 in
    LexVar (t_ann, args1,args2,pos)

and subst_exp sst (e: exp) : exp =
  match sst with
  | s :: rest -> subst_exp rest (e_apply_one s e)
  | [] -> e 

and e_apply_one ((fr, t) as p) e = match e with
  | Null _ 
  | IConst _ 
  | FConst _ 
  | Tsconst _
  | InfConst _
  | NegInfConst _
  | AConst _ -> e
  | Bptriple ((ec,et,ea),pos) ->
    Bptriple ((e_apply_one p ec,
               e_apply_one p et,
               e_apply_one p ea),pos)
  | Tup2 ((e1,e2),pos) ->
    Tup2 ((e_apply_one p e1,
           e_apply_one p e2),pos)
  | Ann_Exp (e,ty,pos) -> Ann_Exp ((e_apply_one p e), ty, pos)
  | Var (sv, pos) -> Var (v_apply_one p sv, pos)
  | Level (sv, pos) -> Level (v_apply_one p sv, pos)
  | Add (a1, a2, pos) -> Add (e_apply_one p a1, e_apply_one p a2, pos)
  | Subtract (a1, a2, pos) -> Subtract (e_apply_one p a1, e_apply_one p a2, pos)
  | Mult (a1, a2, pos) -> Mult (e_apply_one p a1, e_apply_one p a2, pos)
  | Div (a1, a2, pos) -> Div (e_apply_one p a1, e_apply_one p a2, pos)
  | Max (a1, a2, pos) -> Max (e_apply_one p a1, e_apply_one p a2, pos)
  | Min (a1, a2, pos) -> Min (e_apply_one p a1, e_apply_one p a2, pos)
  | TypeCast (ty, a1, pos) -> TypeCast (ty, e_apply_one p a1, pos)
  | Bag (alist, pos) -> Bag ((e_apply_one_list p alist), pos)
  | BagUnion (alist, pos) -> BagUnion ((e_apply_one_list p alist), pos)
  | BagIntersect (alist, pos) -> BagIntersect ((e_apply_one_list p alist), pos)
  | BagDiff (a1, a2, pos) -> BagDiff (e_apply_one p a1, e_apply_one p a2, pos)
  | List (alist, pos) -> List ((e_apply_one_list p alist), pos)
  | ListAppend (alist, pos) -> ListAppend ((e_apply_one_list p alist), pos)
  | ListCons (a1, a2, pos) -> ListCons (e_apply_one p a1, e_apply_one p a2, pos)
  | ListHead (a1, pos) -> ListHead (e_apply_one p a1, pos)
  | ListTail (a1, pos) -> ListTail (e_apply_one p a1, pos)
  | ListLength (a1, pos) -> ListLength (e_apply_one p a1, pos)
  | ListReverse (a1, pos) -> ListReverse (e_apply_one p a1, pos)
  | Func (a, ind, pos) -> Func (a, (e_apply_one_list p ind), pos)
  | ArrayAt (a, ind, pos) -> ArrayAt (v_apply_one p a, (e_apply_one_list p ind), pos) (* An Hoa *)
  | BExpr f1 -> BExpr (apply_one p f1)
  | Template t -> Template { t with templ_args = e_apply_one_list p t.templ_args; }

and v_apply_one ((fr, t)) v = (if eq_var v fr then t else v)

and e_apply_one_list ((fr, t) as p) alist = match alist with
  |[] -> []
  |a :: rest -> (e_apply_one p a) :: (e_apply_one_list p rest)

(* apply_one function for the formula_ext_measures of ext_variance_formula *)
and e_apply_one_list_of_pair ((fr, t) as p) list_of_pair = match list_of_pair with
  | [] -> []
  | (expr, bound)::rest -> match bound with
    | None -> ((e_apply_one p expr), None)::(e_apply_one_list_of_pair p rest)
    | Some b_expr ->  ((e_apply_one p expr), Some (e_apply_one p b_expr))::(e_apply_one_list_of_pair p rest)

and subst_list_of_pair sst ls = match sst with
  | [] -> ls
  | s::rest -> subst_list_of_pair rest (e_apply_one_list_of_pair s ls)

and subst_list_of_exp sst ls = match sst with
  | [] -> ls
  | s::rest -> subst_list_of_exp rest (e_apply_one_list s ls)

and look_for_anonymous_exp_list (args : exp list) :
  (ident * primed) list =
  match args with
  | h :: rest ->
    List.append (look_for_anonymous_exp h)
      (look_for_anonymous_exp_list rest)
  | _ -> []

and anon_var (id, p) = 
  if ((String.length id) > 5) &&
     ((String.compare (String.sub id 0 5) "Anon_") == 0)
  then [ (id, p) ]
  else []

and look_for_anonymous_exp (arg : exp) : (ident * primed) list = match arg with
  | Var (b1, _) -> anon_var b1
  | Add (e1, e2, _) | Subtract (e1, e2, _) | Max (e1, e2, _) |
    Min (e1, e2, _) | BagDiff (e1, e2, _) ->
    List.append (look_for_anonymous_exp e1) (look_for_anonymous_exp e2)

  | Mult (e1, e2, _) | Div (e1, e2, _) ->
    List.append (look_for_anonymous_exp e1) (look_for_anonymous_exp e2)
  | Bag (e1, _) | BagUnion (e1, _) | BagIntersect (e1, _) ->  look_for_anonymous_exp_list e1

  | ListHead (e1, _) | ListTail (e1, _) | ListLength (e1, _) | ListReverse (e1, _) -> look_for_anonymous_exp e1
  | List (e1, _) | ListAppend (e1, _) -> look_for_anonymous_exp_list e1
  | ListCons (e1, e2, _) -> (look_for_anonymous_exp e1) @ (look_for_anonymous_exp e2)
  | _ -> []

and look_for_anonymous_pure_formula (f : formula) : (ident * primed) list = match f with
  | BForm (b,_) -> look_for_anonymous_b_formula b
  | And (b1,b2,_) -> (look_for_anonymous_pure_formula b1)@ (look_for_anonymous_pure_formula b1)
  | AndList b -> Gen.fold_l_snd look_for_anonymous_pure_formula b 
  | Or  (b1,b2,_,_) -> (look_for_anonymous_pure_formula b1)@ (look_for_anonymous_pure_formula b1)
  | Not (b1,_,_) -> (look_for_anonymous_pure_formula b1)
  | Forall (_,b1,_,_)-> (look_for_anonymous_pure_formula b1)
  | Exists (_,b1,_,_)-> (look_for_anonymous_pure_formula b1)


and look_for_anonymous_b_formula (f : b_formula) : (ident * primed) list =
  let (pf,il) = f in
  match pf with
  | XPure _ -> [] (*TO CHECK*)
  | BConst _ -> []
  | Frm (sv,_) -> anon_var sv
  | BVar (b1, _) -> anon_var b1
  | Lt (b1, b2, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | Lte (b1, b2, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | Gt (b1, b2, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | Gte (b1, b2, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | SubAnn (b1, b2, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | Eq (b1, b2, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | Neq (b1, b2, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | EqMax (b1, b2, b3, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2) @ (look_for_anonymous_exp b3)
  | EqMin(b1, b2, b3, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2) @ (look_for_anonymous_exp b3)
  | BagIn (b1, b2, _) -> (anon_var b1) @ (look_for_anonymous_exp b2)
  | BagNotIn (b1, b2, _) -> (anon_var b1) @ (look_for_anonymous_exp b2)
  | BagSub (b1, b2, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | BagMin (b1, b2, _) -> (anon_var b1) @ (anon_var b2)
  | BagMax (b1, b2, _) -> (anon_var b1) @ (anon_var b2)	
  (* | VarPerm _ -> [] (*can not have anon_var*) *)
  | ListIn (b1, b2,  _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | ListNotIn (b1, b2, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | ListAllN (b1, b2, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | ListPerm (b1, b2, _) -> (look_for_anonymous_exp b1) @ (look_for_anonymous_exp b2)
  | LexVar (_,args1, args2, _) -> 
    let vs = List.concat (List.map look_for_anonymous_exp (args1@args2)) in
    vs
  | RelForm (_,args,_) ->
    let vs = List.concat (List.map look_for_anonymous_exp (args)) in
    vs
  | ImmRel (r, _, _) -> look_for_anonymous_b_formula (r,il)

let merge_branches l1 l2 =
  let branches = Gen.BList.remove_dups_eq (=) (fst (List.split l1) @ (fst (List.split l2))) in
  let map_fun branch =
    try 
      let l1 = List.assoc branch l1 in
      try
        let l2 = List.assoc branch l2 in
        (branch, mkAnd l1 l2 no_pos)
      with Not_found -> (branch, l1)
      with Not_found -> (branch, List.assoc branch l2)
  in
  List.map map_fun branches

let rec find_lexp_formula (f: formula) ls =
  match f with
  | BForm (bf, _) -> find_lexp_b_formula bf ls
  | _ -> []

and find_lexp_b_formula (bf: b_formula) ls =
  let (pf, _) = bf in
  find_lexp_p_formula (pf: p_formula) ls
(* match pf with *)
(*   | XPure _ (\*TO CHECK*\) *)
(*   | Frm _ (\*TO CHECK*\) *)
(*   | BConst _ *)
(*   | BVar _ -> [] *)
(*   | Lt (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | Lte (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | Gt (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | Gte (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | SubAnn (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | Eq (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | Neq (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | EqMax (e1, e2, e3, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls @ find_lexp_exp e3 ls *)
(*       | EqMin (e1, e2, e3, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls @ find_lexp_exp e3 ls *)
(*       | BagIn (_, e, _) -> find_lexp_exp e ls *)
(*       | BagNotIn (_, e, _) -> find_lexp_exp e ls *)
(*       | BagSub (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | BagMin _ | BagMax _ -> [] *)
(*       | VarPerm _ -> [] *)
(*       | ListIn (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | ListNotIn (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | ListAllN (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | ListPerm (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls *)
(*       | RelForm (_, el, _) -> List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] el *)
(*       | LexVar (_,e1, e2, _) -> List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] (e1@e2) *)

and find_lexp_p_formula (pf: p_formula) ls =
  match pf with
  | XPure _ (*TO CHECK*)
  | Frm _ (*TO CHECK*)
  | BConst _
  | BVar _ -> []
  | Lt (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | Lte (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | Gt (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | Gte (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | SubAnn (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | Eq (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | Neq (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | EqMax (e1, e2, e3, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls @ find_lexp_exp e3 ls
  | EqMin (e1, e2, e3, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls @ find_lexp_exp e3 ls
  | BagIn (_, e, _) -> find_lexp_exp e ls
  | BagNotIn (_, e, _) -> find_lexp_exp e ls
  | BagSub (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | BagMin _ | BagMax _ -> []
  (* | VarPerm _ -> [] *)
  | ListIn (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | ListNotIn (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | ListAllN (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | ListPerm (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
  | RelForm (_, el, _) -> List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] el
  | ImmRel (r, _, _) -> find_lexp_p_formula r ls 
  | LexVar (_,e1, e2, _) -> List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] (e1@e2)

(* WN : what does this method do? *)
and find_lexp_exp (e: exp) ls =
  if Hashtbl.mem ls e then [e] else
    match e with
    | Null _
    | Var _
    | Level _
    | IConst _
    | AConst _
    | Tsconst _
    | InfConst _
    | NegInfConst _ 
    | FConst _ -> []
    | Ann_Exp(e,_,_) -> find_lexp_exp e ls
    | Bptriple ((ec, et, ea), _) -> find_lexp_exp ec ls @ find_lexp_exp et ls @ find_lexp_exp ea ls
    | Tup2 ((e1, e2), _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
    | Add (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
    | Subtract (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
    | Mult (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
    | Div (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
    | Min (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
    | Max (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
    | TypeCast (_, e1, _) -> find_lexp_exp e1 ls
    | Bag (el, _) -> List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] el
    | BagUnion (el, _) -> List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] el
    | BagIntersect (el, _) -> List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] el
    | BagDiff (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
    | List (el, _) -> List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] el
    | ListCons (e1, e2, _) -> find_lexp_exp e1 ls @ find_lexp_exp e2 ls
    | ListHead (e, _) -> find_lexp_exp e ls
    | ListTail (e, _) -> find_lexp_exp e ls
    | ListLength (e, _) -> find_lexp_exp e ls
    | ListAppend (el, _) -> List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] el
    | ListReverse (e, _) -> find_lexp_exp e ls
    | Func (_, el, _) -> List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] el
    | ArrayAt (_, el, _) -> List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] el
    | BExpr f1 -> find_lexp_formula (f1: formula) ls
    | Template { templ_args = t_args; } -> 
      List.fold_left (fun acc e -> acc @ find_lexp_exp e ls) [] t_args

and list_of_conjs (f: formula) : formula list =
  match f with
  | And (f1, f2, _) -> (list_of_conjs f1) @ (list_of_conjs f2)
  | _ -> [f]

and list_of_disjunctions (f: formula) : formula list =
  match f with
  | Or (f1, f2, _, _) -> (list_of_disjunctions f1) @ (list_of_disjunctions f2)
  | _ -> [f]

and conj_of_list (fs:formula list) : formula =
  match fs with
  | [] -> mkTrue no_pos
  | x::xs -> List.fold_left (fun a c-> mkAnd a c no_pos) x xs

(* and disj_of_list (fs:formula list) : formula = *)
(*   match fs with *)
(*     | [] -> mkTrue no_pos *)
(*     | x::xs -> List.fold_left (fun a c-> mkOr a c no_pos) x xs *)
;;

let rec break_pure_formula (f: formula) : b_formula list =
  match f with
  | BForm (bf, _) -> [bf]
  | And (f1, f2, _) -> (break_pure_formula f1) @ (break_pure_formula f2)
  | AndList b -> Gen.fold_l_snd break_pure_formula b
  | Or (f1, f2, _, _) -> (break_pure_formula f1) @ (break_pure_formula f2)
  | Not (f, _, _) -> break_pure_formula f
  | Forall (_, f, _, _) -> break_pure_formula f
  | Exists (_, f, _, _) -> break_pure_formula f



let rec contain_vars_exp (expr : exp) : bool =
  match expr with
  | Null _ 
  | Var _ 
  | Level _ 
  | IConst _ 
  | AConst _ 
  | Tsconst _
  | Bptriple _ (* TOCHECK *)
  | Tup2 _ (* TOCHECK *)
  | InfConst _ 
  | NegInfConst _
  | FConst _ -> false
  | Ann_Exp (exp,_,_) -> (contain_vars_exp exp)
  | Add (exp1, exp2, _) -> (contain_vars_exp exp1) || (contain_vars_exp exp2)
  | Subtract (exp1, exp2, _) -> (contain_vars_exp exp1) || (contain_vars_exp exp2)
  | Mult (exp1, exp2, _) -> (contain_vars_exp exp1) || (contain_vars_exp exp2)
  | Div (exp1, exp2, _) -> (contain_vars_exp exp1) || (contain_vars_exp exp2)
  | Max (exp1, exp2, _) -> (contain_vars_exp exp1) || (contain_vars_exp exp2)
  | Min (exp1, exp2, _) -> (contain_vars_exp exp1) || (contain_vars_exp exp2)
  | TypeCast (_, exp, _) -> contain_vars_exp exp
  | Bag (expl, _) -> List.exists (fun e -> contain_vars_exp e) expl
  | BagUnion (expl, _) -> List.exists (fun e -> contain_vars_exp e) expl
  | BagIntersect (expl, _) -> List.exists (fun e -> contain_vars_exp e) expl
  | BagDiff (exp1, exp2, _) -> (contain_vars_exp exp1) || (contain_vars_exp exp2)
  | List (expl, _) -> List.exists (fun e -> contain_vars_exp e) expl
  | ListCons (exp1, exp2, _) -> (contain_vars_exp exp1) || (contain_vars_exp exp2)
  | ListHead (exp, _) -> contain_vars_exp exp
  | ListTail (exp, _) -> contain_vars_exp exp
  | ListLength (exp, _) -> contain_vars_exp exp
  | ListAppend (expl, _) -> List.exists (fun e -> contain_vars_exp e) expl
  | ListReverse (exp, _) -> contain_vars_exp exp
  | Func _ -> true
  | ArrayAt _ -> true
  | Template _ -> false
  | BExpr f1 ->  f_contain_vars_exp f1

and f_contain_vars_exp f=
  let recf = f_contain_vars_exp in
  match f with
  | BForm ((pf,_),_) ->  p_contain_vars_exp pf
  | And (f1, f2, _)
  | Or (f1, f2, _, _)
    -> (recf f1) || (recf f2)
  | AndList fs -> List.exists (fun (_,f1) -> recf f1) fs
  | Not (f1, _, _)
  | Forall (_,f1,_,_)
  | Exists (_,f1,_,_) -> recf f1

and p_contain_vars_exp (pf) : bool = match pf with
  | Frm _ 
  | XPure _
  | BConst _
  | BVar _ -> false
  | SubAnn (exp1, exp2,_) 
  | Lt (exp1, exp2,_) 
  | Lte (exp1, exp2,_) 
  | Gt (exp1, exp2,_) 
  | Gte (exp1, exp2,_) 
  | Eq (exp1, exp2,_) 
  | Neq (exp1, exp2,_) -> (contain_vars_exp exp1) || (contain_vars_exp exp2)
  | EqMax (exp1, exp2,exp3,_)
  | EqMin (exp1, exp2,exp3,_) -> (contain_vars_exp exp1) || (contain_vars_exp exp2) || (contain_vars_exp exp3)
  | LexVar _ -> false
  (* | VarPerm _ *)
  | BagIn (_ , exp1 , _)
  | BagNotIn (_ , exp1 , _) -> (contain_vars_exp exp1)
  | BagSub (exp1, exp2,_) -> (contain_vars_exp exp1) || (contain_vars_exp exp2)
  | BagMin _
  | BagMax _ -> false
  | ListIn (exp1, exp2,_) 
  | ListNotIn (exp1, exp2,_) 
  | ListAllN (exp1, exp2,_) 
  | ListPerm (exp1, exp2,_)  -> (contain_vars_exp exp1) || (contain_vars_exp exp2)
  | RelForm _ 
  | ImmRel  _ -> false

and float_out_exp_min_max (e: exp): (exp * (formula * (string list) ) option) = match e with 
  | Null _ 
  | Var _ 
  | Level _ 
  | IConst _ 
  | AConst _ 
  | Tsconst _
  | InfConst _ 
  | NegInfConst _
  | FConst _ -> (e, None)
  | Ann_Exp (e, t, l) -> 
    let ne, np = float_out_exp_min_max e in
    (Ann_Exp (ne, t, l), np) 
  | Bptriple ((ec,et,ea),l) -> 
    let ec1,ec_r = float_out_exp_min_max ec in
    let et1,et_r = float_out_exp_min_max et in
    let ea1,ea_r = float_out_exp_min_max ea in
    let r = List.fold_left ( fun np1 np2 ->
        let res = match (np1, np2) with
          | None, None -> None
          | Some p, None -> Some p
          | None, Some p -> Some p
          | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))
        in res) ec_r [et_r;ea_r]
    in
    (Bptriple ((ec1,et1,ea1),l),r)
  | Tup2 ((e1,e2),l) -> 
    let e1,e1_r = float_out_exp_min_max e1 in
    let e2,e2_r = float_out_exp_min_max e2 in
    let r = List.fold_left ( fun np1 np2 ->
        let res = match (np1, np2) with
          | None, None -> None
          | Some p, None -> Some p
          | None, Some p -> Some p
          | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))
        in res) e1_r [e2_r]
    in
    (Tup2 ((e1,e2),l),r)
  | Add (e1, e2, l) ->
    let ne1, np1 = float_out_exp_min_max e1 in
    let ne2, np2 = float_out_exp_min_max e2 in
    let r = match (np1, np2) with
      | None, None -> None
      | Some p, None -> Some p
      | None, Some p -> Some p
      | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))in

    (Add (ne1, ne2, l), r) 
  | Subtract (e1, e2, l) ->
    let ne1, np1 = float_out_exp_min_max e1 in
    let ne2, np2 = float_out_exp_min_max e2 in
    let r = match (np1, np2) with
      | None, None -> None
      | Some p, None -> Some p
      | None, Some p -> Some p
      | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))in
    (Subtract (ne1, ne2, l), r) 
  | Mult (e1, e2, l) ->
    let ne1, np1 = float_out_exp_min_max e1 in
    let ne2, np2 = float_out_exp_min_max e2 in
    let r = match np1, np2 with
      | None, None -> None
      | Some p, None -> Some p
      | None, Some p -> Some p
      | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))
    in (Mult (ne1, ne2, l), r)
  | Div (e1, e2, l) ->
    let ne1, np1 = float_out_exp_min_max e1 in
    let ne2, np2 = float_out_exp_min_max e2 in
    let r = match np1, np2 with
      | None, None -> None
      | Some p, None -> Some p
      | None, Some p -> Some p
      | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))
    in (Div (ne1, ne2, l), r)
  | Max (e1, e2, l) ->
    let ne1, np1 = float_out_exp_min_max e1 in
    let ne2, np2 = float_out_exp_min_max e2 in
    let new_name = ("max"^(fresh_trailer())) in
    let nv = Var((new_name, Unprimed), l) in
    let lexp = find_lexp_exp e !linking_exp_list in (* find the linking exp inside Max *)
    let t = BForm ((EqMax(nv, ne1, ne2, l), Some(false, Globals.fresh_int(), lexp)), None) in
    (* $ h = 1 + max(h1, h2) -> <$,_> h = 1 + max_1 & <_,_> max_1 = max(h1, h2) ==> h is still separated from h1, h2 *)
    let r = match (np1, np2) with
      | None, None -> Some (t,[new_name])
      | Some (p1, l1), None -> Some ((And(p1, t, l)), (new_name:: l1))
      | None, Some (p1, l1) -> Some ((And(p1, t, l)), (new_name:: l1))
      | Some (p1, l1), Some (p2, l2) -> Some ((And ((And (p1, t, l)), p2, l)), new_name:: (List.rev_append l1 l2)) in
    (nv, r) 
  | Min (e1, e2, l) ->
    let ne1, np1 = float_out_exp_min_max e1 in
    let ne2, np2 = float_out_exp_min_max e2 in
    let new_name = ("min"^(fresh_trailer())) in
    let nv = Var((new_name, Unprimed), l) in
    let lexp = find_lexp_exp e !linking_exp_list in (* find the linking exp inside Min *)
    let t = BForm ((EqMin(nv, ne1, ne2, l), Some(false, Globals.fresh_int(), lexp)), None) in 
    let r = match (np1, np2) with
      | None, None -> Some (t,[new_name])
      | Some (p1, l1), None -> Some ((And(p1, t, l)), (new_name:: l1))
      | None, Some (p2, l2) -> Some ((And(p2, t, l)), (new_name:: l2))
      | Some (p1, l1), Some (p2, l2) -> Some ((And ((And (p1, t, l)), p2, l)), new_name:: (List.rev_append l1 l2)) in
    (nv, r)
  | TypeCast (ty, e1, l) ->
    let ne1, np1 = float_out_exp_min_max e1 in
    (TypeCast (ty, ne1, l), np1)
  (* bag expressions *)
  | Bag (le, l) ->
    let ne1, np1 = List.split (List.map float_out_exp_min_max le) in
    let r = List.fold_left (fun a c -> match (a, c)with
        | None, None -> None
        | Some p, None -> Some p
        | None, Some p -> Some p
        | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))) None np1 in
    (Bag (ne1, l), r)
  | BagUnion (le, l) ->
    let ne1, np1 = List.split (List.map float_out_exp_min_max le) in
    let r = List.fold_left (fun a c -> match (a, c)with
        | None, None -> None
        | Some p, None -> Some p
        | None, Some p -> Some p
        | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))) None np1 in
    (BagUnion (ne1, l), r)
  | BagIntersect (le, l) ->
    let ne1, np1 = List.split (List.map float_out_exp_min_max le) in
    let r = List.fold_left (fun a c -> match (a, c)with
        | None, None -> None
        | Some p, None -> Some p
        | None, Some p -> Some p
        | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), List.rev_append l1 l2)) None np1 in
    (BagIntersect (ne1, l), r)
  | BagDiff (e1, e2, l) ->
    let ne1, np1 = float_out_exp_min_max e1 in
    let ne2, np2 = float_out_exp_min_max e2 in
    let r = match (np1, np2) with
      | None, None -> None
      | Some p, None -> Some p
      | None, Some p -> Some p
      | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2)) in
    (BagDiff (ne1, ne2, l), r) 
  (* list expressions *)
  | List (le, l) ->
    let ne1, np1 = List.split (List.map float_out_exp_min_max le) in
    let r = List.fold_left (fun a c -> match (a, c) with
        | None, None -> None
        | Some p, None -> Some p
        | None, Some p -> Some p
        | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))) None np1 in
    (List (ne1, l), r)
  | ListAppend (le, l) ->
    let ne1, np1 = List.split (List.map float_out_exp_min_max le) in
    let r = List.fold_left (fun a c -> match (a, c) with
        | None, None -> None
        | Some p, None -> Some p
        | None, Some p -> Some p
        | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))) None np1 in
    (ListAppend (ne1, l), r)
  | ListCons (e1, e2, l) -> 
    let ne1, np1 = float_out_exp_min_max e1 in
    let ne2, np2 = float_out_exp_min_max e2 in
    let r = match (np1, np2) with
      | None, None -> None
      | Some p, None -> Some p
      | None, Some p -> Some p
      | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2)) in
    (ListCons (ne1, ne2, l), r) 
  | ListHead (e, l) -> 
    let ne1, np1 = float_out_exp_min_max e in
    (ListHead (ne1, l), np1)
  | ListTail (e, l) -> 
    let ne1, np1 = float_out_exp_min_max e in
    (ListTail (ne1, l), np1)
  | ListLength (e, l) -> 
    let ne1, np1 = float_out_exp_min_max e in
    (ListLength (ne1, l), np1)
  | ListReverse (e, l) -> 
    let ne1, np1 = float_out_exp_min_max e in
    (ListReverse (ne1, l), np1)
  | Func (a, i, l) ->
    let ne1, np1 = List.split (List.map float_out_exp_min_max i) in
    let r = List.fold_left (fun a c -> match (a, c) with
        | None, None -> None
        | Some p, None -> Some p
        | None, Some p -> Some p
        | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))) None np1 in
    (Func (a, ne1, l), r)
  (* An Hoa : get rid of min/max in a[i] *)
  | ArrayAt (a, i, l) ->
    let ne1, np1 = List.split (List.map float_out_exp_min_max i) in
    let r = List.fold_left (fun a c -> match (a, c) with
        | None, None -> None
        | Some p, None -> Some p
        | None, Some p -> Some p
        | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))) None np1 in
    (ArrayAt (a, ne1, l), r)
  | Template t ->
    let ne1, np1 = List.split (List.map float_out_exp_min_max t.templ_args) in
    let l = t.templ_pos in
    let r = List.fold_left (fun a c -> match (a, c) with
        | None, None -> None
        | Some p, None -> Some p
        | None, Some p -> Some p
        | Some (p1, l1), Some (p2, l2) -> Some ((And (p1, p2, l)), (List.rev_append l1 l2))) None np1 in
    (Template { t with templ_args = ne1; }, r)
  | BExpr f1 -> (e, None) (* BExpr (float_out_p_formula_min_max (pf: p_formula) []) *)

(* and float_out_b_formula_min_max (b: b_formula): b_formula = *)
(*   let (pf,il) = b in *)
(*   (float_out_p_formula_min_max (pf: p_formula), il) *)

(* and float_out_p_formula_min_max (pf: p_formula): p_formula = match pf with *)
(*   | BConst _ | Frm _ | BVar _ |XPure _  *)
(*   | LexVar _ -> (b) *)
(*   | Lt (e1, e2, l) -> *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let t = Lt (ne1, ne2, l) in *)
(* 	add_exists t np1 np2 l *)
(*   | Lte (e1, e2, l) -> *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let t = BForm ((Lte (ne1, ne2, l), il),lbl) in *)
(* 	add_exists t np1 np2 l *)
(*   | Gt (e1, e2, l) -> *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let t = BForm ((Gt (ne1, ne2, l), il), lbl) in *)
(* 	add_exists t np1 np2 l *)
(*   | Gte (e1, e2, l) -> *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let t = BForm ((Gte (ne1, ne2, l), il), lbl) in *)
(* 	add_exists t np1 np2 l *)
(*   | Eq (e1, e2, l) -> *)
(*         (\* WN : why not change below to a method? *\) *)
(* 	let r = match e1 with *)
(* 	  | Min(v1, v2, v3) -> let r2 = match e2 with *)
(* 	      | Null _ *)
(* 	      | IConst _ *)
(*               | FConst _ *)
(*               | AConst _ *)
(* 	      | Tsconst _ *)
(* 	      | Var _ -> *)
(* 		    let ne1 , np1 = float_out_exp_min_max v1 in *)
(* 		    let ne2 , np2 = float_out_exp_min_max v2 in *)
(* 		    let t = BForm((EqMin(e2, ne1, ne2, l), il), lbl) in *)
(* 		    add_exists t np1 np2 l *)
(* 	      | _ ->  *)
(* 		    let ne1, np1 = float_out_exp_min_max e1 in *)
(* 		    let ne2, np2 = float_out_exp_min_max e2 in *)
(* 		    let t = BForm ((Eq (ne1, ne2, l), il), lbl) in *)
(* 		    add_exists t np1 np2 l  in r2 *)
(* 	  | Max(v1, v2, v3) -> let r2 = match e2 with *)
(* 	      | Null _ *)
(* 	      | IConst _ *)
(*               | AConst _ *)
(* 	      | Tsconst _ *)
(* 	      | Var _ -> *)
(* 		    let ne1 , np1 = float_out_exp_min_max v1 in *)
(* 		    let ne2 , np2 = float_out_exp_min_max v2 in *)
(* 		    let t = BForm ((EqMax(e2, ne1, ne2, l), il), lbl) in *)
(* 		    add_exists t np1 np2 l *)
(* 	      | _ ->  *)
(* 		    let ne1, np1 = float_out_exp_min_max e1 in *)
(* 		    let ne2, np2 = float_out_exp_min_max e2 in *)
(* 		    let t = BForm ((Eq (ne1, ne2, l), il), lbl) in *)
(* 		    add_exists t np1 np2 l  *)
(* 	    in r2 *)
(* 	  | Null _ *)
(* 	  | IConst _ *)
(*           | FConst _ *)
(*           | AConst _ *)
(* 	  | Tsconst _ *)
(* 	  | Var _ -> let r2 = match e2 with *)
(* 	      | Min (v1, v2, v3) -> *)
(* 		    let ne1 , np1 = float_out_exp_min_max v1 in *)
(* 		    let ne2 , np2 = float_out_exp_min_max v2 in *)
(* 		    let t = BForm ((EqMin(e1, ne1, ne2, l), il), lbl) in *)
(* 		    add_exists t np1 np2 l *)
(* 	      | Max (v1, v2, v3) -> *)
(* 		    let ne1 , np1 = float_out_exp_min_max v1 in *)
(* 		    let ne2 , np2 = float_out_exp_min_max v2 in *)
(* 		    let t = BForm ((EqMax(e1, ne1, ne2, l), il), lbl) in *)
(* 		    add_exists t np1 np2 l *)
(* 	      | _ ->  *)
(* 		    let ne1, np1 = float_out_exp_min_max e1 in *)
(* 		    let ne2, np2 = float_out_exp_min_max e2 in *)
(* 		    let t = BForm ((Eq (ne1, ne2, l), il), lbl) in *)
(* 		    add_exists t np1 np2 l  *)
(* 	    in r2 *)
(* 	  | _ -> *)
(* 		let ne1, np1 = float_out_exp_min_max e1 in *)
(* 		let ne2, np2 = float_out_exp_min_max e2 in *)
(* 		let t = BForm ((Eq (ne1, ne2, l), il), lbl) in *)
(* 		add_exists t np1 np2 l  *)
(* 	in r *)
(*   | Neq (e1, e2, l) -> *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let t = BForm ((Neq (ne1, ne2, l), il), lbl) in *)
(* 	add_exists t np1 np2 l *)
(*   | EqMax (e1, e2, e3, l) -> *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let ne3, np3 = float_out_exp_min_max e3 in *)
(* 	let t = BForm ((EqMax (ne1, ne2, ne3, l), il), lbl) in *)
(* 	let t = add_exists t np1 np2 l in *)
(* 	let r = match np3 with  *)
(* 	  | None -> t *)
(* 	  | Some (p1, l1) -> List.fold_left (fun a c -> (Exists ((c, Unprimed), a, lbl, l))) (And(t, p1, l)) l1 in r *)
(*   | EqMin (e1, e2, e3, l) -> *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let ne3, np3 = float_out_exp_min_max e3 in *)
(* 	let t = BForm ((EqMin (ne1, ne2, ne3, l), il), lbl) in *)
(* 	let t = add_exists t np1 np2 l in *)
(* 	let r = match np3 with  *)
(* 	  | None -> t *)
(* 	  | Some (p1, l1) -> List.fold_left (fun a c -> Exists ((c, Unprimed), a, lbl, l)) (And(t, p1, l)) l1 in r *)
(*   | BagIn (v, e, l) ->  *)
(* 	let ne1, np1 = float_out_exp_min_max e in *)
(* 	let r = match np1 with *)
(* 	  | None -> BForm ((BagIn(v, ne1, l), il), lbl) *)
(* 	  | Some (r, l1) -> List.fold_left (fun a c -> Exists ((c, Unprimed), a, lbl, l)) (And (BForm ((BagIn(v, ne1, l), il), lbl), r, l)) l1 in r  *)
(*   | BagNotIn (v, e, l) ->  *)
(* 	let ne1, np1 = float_out_exp_min_max e in *)
(* 	let r = match np1 with *)
(* 	  | None -> BForm ((BagNotIn(v, ne1, l), il), lbl) *)
(* 	  | Some (r, l1) -> List.fold_left (fun a c -> Exists ((c, Unprimed), a, lbl,  l)) (And (BForm ((BagIn(v, ne1, l), il), lbl), r, l)) l1 in r *)
(*   | BagSub (e1, e2, l) -> *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let t = BForm ((BagSub (ne1, ne2, l), il), lbl) in *)
(* 	add_exists t np1 np2 l *)
(*   | SubAnn _ *)
(*   | VarPerm _ *)
(*   | BagMin _  *)
(*   | BagMax _ -> BForm (b,lbl)	 *)
(*   | ListIn (e1, e2, l) ->  *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let t = BForm ((ListIn (ne1, ne2, l), il), lbl) in *)
(* 	add_exists t np1 np2 l *)
(*   | ListNotIn (e1, e2, l) ->  *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let t = BForm ((ListNotIn (ne1, ne2, l), il), lbl) in *)
(* 	add_exists t np1 np2 l *)
(*   | ListAllN (e1, e2, l) -> *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let t = BForm ((ListAllN (ne1, ne2, l), il), lbl) in *)
(* 	add_exists t np1 np2 l *)
(*   | ListPerm (e1, e2, l) -> *)
(* 	let ne1, np1 = float_out_exp_min_max e1 in *)
(* 	let ne2, np2 = float_out_exp_min_max e2 in *)
(* 	let t = BForm ((ListPerm (ne1, ne2, l), il), lbl) in *)
(* 	add_exists t np1 np2 l *)
(* 	    (\* An Hoa : handle relation *\) *)
(* 	    (\* TODO Have to add the existential before the formula! Add a add_exists with a list instead *\) *)
(*   | RelForm (r, args, l) -> *)
(* 	let nargs = List.map float_out_exp_min_max args in *)
(* 	let nargse = List.map fst nargs in *)
(* 	let t = BForm ((RelForm (r, nargse, l), il), lbl) in *)
(* 	t *)

and float_out_pure_min_max (p : formula) : formula =

  let add_exists (t: formula)(np1: (formula * (string list))option)(np2: (formula * (string list))option) l: formula = 
    let r, ev = match np1 with
      | None -> (t,[])
      | Some (p1, ev1) -> (And (t, p1, l), ev1) in
    let r, ev2 = match np2 with 
      | None -> (r, ev)
      | Some (p1, ev1) -> (And(r, p1, l), (List.rev_append ev1 ev)) in 
    List.fold_left (fun a c -> (Exists ((c, Unprimed), a, None,l))) r ev2 in

  let rec float_out_b_formula_min_max (b: b_formula) lbl: formula =
    let (pf,il) = b in
    match pf with
    | BConst _ | Frm _ | BVar _ |XPure _
    | LexVar _ | ImmRel _ -> BForm (b,lbl)
    | Lt (e1, e2, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let t = BForm ((Lt (ne1, ne2, l), il), lbl) in
      add_exists t np1 np2 l
    | Lte (e1, e2, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let t = BForm ((Lte (ne1, ne2, l), il),lbl) in
      add_exists t np1 np2 l
    | Gt (e1, e2, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let t = BForm ((Gt (ne1, ne2, l), il), lbl) in
      add_exists t np1 np2 l
    | Gte (e1, e2, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let t = BForm ((Gte (ne1, ne2, l), il), lbl) in
      add_exists t np1 np2 l
    | Eq (e1, e2, l) ->
      (* WN : why not change below to a method? *)
      let r = match e1 with
        | Min(v1, v2, v3) -> let r2 = match e2 with
          | Null _
          | IConst _
          | FConst _
          | AConst _
          | Tsconst _
          | Var _ ->
            let ne1 , np1 = float_out_exp_min_max v1 in
            let ne2 , np2 = float_out_exp_min_max v2 in
            let t = BForm((EqMin(e2, ne1, ne2, l), il), lbl) in
            add_exists t np1 np2 l
          | _ ->
            let ne1, np1 = float_out_exp_min_max e1 in
            let ne2, np2 = float_out_exp_min_max e2 in
            let t = BForm ((Eq (ne1, ne2, l), il), lbl) in
            add_exists t np1 np2 l  in r2
        | Max(v1, v2, v3) -> let r2 = match e2 with
          | Null _
          | IConst _
          | AConst _
          | Tsconst _
          | Var _ ->
            let ne1 , np1 = float_out_exp_min_max v1 in
            let ne2 , np2 = float_out_exp_min_max v2 in
            let t = BForm ((EqMax(e2, ne1, ne2, l), il), lbl) in
            add_exists t np1 np2 l
          | _ ->
            let ne1, np1 = float_out_exp_min_max e1 in
            let ne2, np2 = float_out_exp_min_max e2 in
            let t = BForm ((Eq (ne1, ne2, l), il), lbl) in
            add_exists t np1 np2 l
          in r2
        | Null _
        | IConst _
        | FConst _
        | AConst _
        | Tsconst _
        | Var _ -> let r2 = match e2 with
          | Min (v1, v2, v3) ->
            let ne1 , np1 = float_out_exp_min_max v1 in
            let ne2 , np2 = float_out_exp_min_max v2 in
            let t = BForm ((EqMin(e1, ne1, ne2, l), il), lbl) in
            add_exists t np1 np2 l
          | Max (v1, v2, v3) ->
            let ne1 , np1 = float_out_exp_min_max v1 in
            let ne2 , np2 = float_out_exp_min_max v2 in
            let t = BForm ((EqMax(e1, ne1, ne2, l), il), lbl) in
            add_exists t np1 np2 l
          | _ ->
            let ne1, np1 = float_out_exp_min_max e1 in
            let ne2, np2 = float_out_exp_min_max e2 in
            let t = BForm ((Eq (ne1, ne2, l), il), lbl) in
            add_exists t np1 np2 l
          in r2
        | _ ->
          let ne1, np1 = float_out_exp_min_max e1 in
          let ne2, np2 = float_out_exp_min_max e2 in
          let t = BForm ((Eq (ne1, ne2, l), il), lbl) in
          add_exists t np1 np2 l
      in r
    | Neq (e1, e2, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let t = BForm ((Neq (ne1, ne2, l), il), lbl) in
      add_exists t np1 np2 l
    | EqMax (e1, e2, e3, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let ne3, np3 = float_out_exp_min_max e3 in
      let t = BForm ((EqMax (ne1, ne2, ne3, l), il), lbl) in
      let t = add_exists t np1 np2 l in
      let r = match np3 with
        | None -> t
        | Some (p1, l1) -> List.fold_left (fun a c -> (Exists ((c, Unprimed), a, lbl, l))) (And(t, p1, l)) l1 in r
    | EqMin (e1, e2, e3, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let ne3, np3 = float_out_exp_min_max e3 in
      let t = BForm ((EqMin (ne1, ne2, ne3, l), il), lbl) in
      let t = add_exists t np1 np2 l in
      let r = match np3 with
        | None -> t
        | Some (p1, l1) -> List.fold_left (fun a c -> Exists ((c, Unprimed), a, lbl, l)) (And(t, p1, l)) l1 in r
    | BagIn (v, e, l) ->
      let ne1, np1 = float_out_exp_min_max e in
      let r = match np1 with
        | None -> BForm ((BagIn(v, ne1, l), il), lbl)
        | Some (r, l1) -> List.fold_left (fun a c -> Exists ((c, Unprimed), a, lbl, l)) (And (BForm ((BagIn(v, ne1, l), il), lbl), r, l)) l1 in r
    | BagNotIn (v, e, l) ->
      let ne1, np1 = float_out_exp_min_max e in
      let r = match np1 with
        | None -> BForm ((BagNotIn(v, ne1, l), il), lbl)
        | Some (r, l1) -> List.fold_left (fun a c -> Exists ((c, Unprimed), a, lbl,  l)) (And (BForm ((BagIn(v, ne1, l), il), lbl), r, l)) l1 in r
    | BagSub (e1, e2, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let t = BForm ((BagSub (ne1, ne2, l), il), lbl) in
      add_exists t np1 np2 l
    | SubAnn _
    (* | VarPerm _ *)
    | BagMin _
    | BagMax _ -> BForm (b,lbl)
    | ListIn (e1, e2, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let t = BForm ((ListIn (ne1, ne2, l), il), lbl) in
      add_exists t np1 np2 l
    | ListNotIn (e1, e2, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let t = BForm ((ListNotIn (ne1, ne2, l), il), lbl) in
      add_exists t np1 np2 l
    | ListAllN (e1, e2, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let t = BForm ((ListAllN (ne1, ne2, l), il), lbl) in
      add_exists t np1 np2 l
    | ListPerm (e1, e2, l) ->
      let ne1, np1 = float_out_exp_min_max e1 in
      let ne2, np2 = float_out_exp_min_max e2 in
      let t = BForm ((ListPerm (ne1, ne2, l), il), lbl) in
      add_exists t np1 np2 l
    (* An Hoa : handle relation *)
    (* TODO Have to add the existential before the formula! Add a add_exists with a list instead *)
    | RelForm (r, args, l) ->
      let nargs = List.map float_out_exp_min_max args in
      let nargse = List.map fst nargs in
      let t = BForm ((RelForm (r, nargse, l), il), lbl) in
      t

  in
  match p with
  | BForm (b,lbl) -> (float_out_b_formula_min_max b lbl)
  | And (f1, f2, l) -> And((float_out_pure_min_max f1), (float_out_pure_min_max f2), l)
  | AndList b -> AndList (Gen.map_l_snd float_out_pure_min_max b)
  | Or (f1, f2, lbl, l) -> Or((float_out_pure_min_max f1), (float_out_pure_min_max f2), lbl,l)
  | Not (f1,lbl, l) -> Not((float_out_pure_min_max f1), lbl, l)
  | Forall (v, f1, lbl, l) -> Forall (v, (float_out_pure_min_max f1), lbl, l)
  | Exists (v, f1, lbl, l) -> Exists (v, (float_out_pure_min_max f1), lbl, l)

let find_equal_var (p:formula) : ((ident*primed) * (ident*primed)) list =
  (match p with
   | BForm ((p_f,_),_) ->
     (match p_f with
      | Eq (e1,e2,pos) ->
        (match e1,e2 with
         | Var (v1,_), Var (v2,_) ->
           [(v1,v2)]
         | _ -> []
        )
      | _ -> []
     )
   | _ -> []
  )

let find_closure (v:(ident*primed)) (vv:((ident*primed) * (ident*primed)) list) : (ident*primed) list = 
  let rec helper (vs: (ident*primed) list) (vv:((ident*primed) * (ident*primed)) list) =
    match vv with
    | (v1,v2)::xs -> 
      let v3 = if (List.exists (fun v -> eq_var v v1) vs) then Some v2
        else if (List.exists (fun v -> eq_var v v2) vs) then Some v1
        else 
          None 
      in
      (match v3 with
       | None -> helper vs xs
       | Some x -> helper (x::vs) xs)
    | [] -> vs
  in
  helper [v] vv

let rec find_p_val x v p = match p with 
  | BForm (((Eq (Var (a,_),IConst (b,_),_)),_),_) 
  | BForm (((Eq (IConst (b,_),Var (a,_),_)),_),_) -> a=v && b=x
  | BForm _ -> false
  | And (f1,f2,_) -> (find_p_val x v f1) || (find_p_val x v f2)
  | AndList l -> Gen.Basic.exists_l_snd (find_p_val x v) l 
  | Or (f1,f2,_,_) -> (find_p_val x v f1) && (find_p_val x v f2)
  | Not (f,_,_) 
  | Forall (_,f,_,_)
  | Exists (_,f,_,_)-> find_p_val x v f


(* get type of an expression *)
let rec typ_of_exp (e: exp) : typ =
  let pos = pos_of_exp e in
  let arr_typ_check typ1 typ2 =
    ( match typ1 with
      | Array (t1,_) -> if t1== UNK || t1 == typ2 then typ2 else
          ( match typ2 with
            | Array (t2,_) -> if t2== UNK || t1==t2 then typ1 else
                Gen.Basic.report_error pos "Ununified type in 2 expressions 1"
            | _ -> Gen.Basic.report_error pos "Ununified type in 2 expressions 2"
          )
      | _ -> 
        (let msg = string_of_typ typ2 in
         match typ2 with
          | Array (t,_) -> 
            if t== UNK || t=typ1 then typ1 
            else Gen.Basic.report_error pos ("Ununified type in 2 expressions 3"^msg)
          | _ -> Gen.Basic.report_error pos ("Ununified type in 2 expressions 4"^msg)
        )
    )
  in
  let arr_typ_check typ1 typ2 =
    let pr = string_of_typ in
    Debug.no_2 "arr_typ_check" pr pr pr arr_typ_check typ1 typ2 in

  let merge_types typ1 typ2 =
    (* let () = print_endline ("typ1:" ^ (string_of_typ typ1 )) in *)
    (* let () = print_endline ("typ2:" ^ (string_of_typ typ2 )) in *)
    if (typ1 = UNK) then typ2
    else if (typ1 = typ2) then typ1
    else match typ2  with
      | UNK
      | Array (UNK,_) -> typ1
      | _ -> arr_typ_check typ1 typ2
      (* Gen.Basic.report_error pos "Ununified type in 2 expressions" *)
  in
  let merge_types typ1 typ2 =
    let pr = string_of_typ in
    Debug.no_2 "merge_types" pr pr pr merge_types typ1 typ2 in

  let merge_types_ptr typ1 typ2 =
    if !Globals.ptr_arith_flag then
      begin
        if typ1=Int || typ1=NUM then typ2
        else if typ2=Int || typ2=NUM then typ1
        else x_add merge_types typ1 typ2
      end
    else x_add merge_types typ1 typ2 
  in
  match e with
  | Ann_Exp (ex, ty, _)       -> 
    let ty2 = typ_of_exp ex in
    x_add merge_types ty2 ty
  | Null _                    -> Globals.UNK               (* Trung: TODO: what is the type of Null? *) 
  | Var  _                    -> Globals.UNK               (* Trung: TODO: what is the type of Var? *)
  (* Const *)
  | Level _                   -> Globals.level_data_typ
  | IConst _                  -> Globals.Int
  | FConst _                  -> Globals.Float
  | InfConst _                  -> Globals.Int (* Type of Infinity should be Num keep Int for now *)
  | NegInfConst _               -> Globals.INFInt (* Type of Infinity should be Num keep Int for now *)
  | AConst _                  -> Globals.AnnT
  | Tsconst _ 				  -> Globals.Tree_sh
  | Bptriple _ 				  -> Globals.Bptyp
  | Tup2 ((e1,e2), _)				  -> Globals.Tup2 (typ_of_exp e1,typ_of_exp e2)
  (* Arithmetic expressions *)
  | Add (ex1, ex2, _)
  | Subtract (ex1, ex2, _) -> 
    let ty1 = typ_of_exp ex1 in
    let ty2 = typ_of_exp ex2 in
    merge_types_ptr ty1 ty2
  | Mult (ex1, ex2, _)
  | Div (ex1, ex2, _)
  | Max (ex1, ex2, _)
  | Min (ex1, ex2, _) -> 
    let ty1 = typ_of_exp ex1 in
    let ty2 = typ_of_exp ex2 in
    x_add merge_types ty1 ty2
  | TypeCast (ty, ex1, _)     -> ty
  (* bag expressions *)
  | Bag (ex_list, _)
  | BagUnion (ex_list, _)
  | BagIntersect (ex_list, _) -> let ty_list = List.map typ_of_exp ex_list in 
    let ty = List.fold_left (x_add merge_types) UNK ty_list in
    Globals.BagT ty
  | BagDiff (ex1, ex2, _)     -> let ty1 = typ_of_exp ex1 in
    let ty2 = typ_of_exp ex2 in
    let ty = x_add merge_types ty1 ty2 in
    Globals.BagT ty
  (* list expressions *)
  | List (ex_list, _)         -> let ty_list = List.map typ_of_exp ex_list in 
    let ty = List.fold_left (x_add merge_types) UNK ty_list in
    Globals.List ty
  | ListCons (ex1, ex2, _)    -> let ty1 = typ_of_exp ex1 in
    let ty2 = typ_of_exp ex2 in
    let ty = x_add merge_types ty1 ty2 in
    Globals.List ty
  | ListHead (ex, _)          -> typ_of_exp ex
  | ListTail (ex, _)          -> let ty = typ_of_exp ex in
    Globals.List ty
  | ListLength (ex, _)        -> Globals.Int
  | ListAppend (ex_list, _)   -> let ty_list = List.map typ_of_exp ex_list in 
    let ty = List.fold_left (x_add merge_types) UNK ty_list in
    Globals.List ty
  | ListReverse (ex, _)       -> let ty = typ_of_exp ex in
    Globals.List ty
  (* Array expressions *)
  | ArrayAt (_, ex_list, _)   -> 
    let ty_list = List.map typ_of_exp ex_list in 
    let ty = List.fold_left (x_add merge_types) UNK ty_list in
    let len = List.length ex_list in
    Globals.Array (ty, len)
  | Template t -> 
    let ty_list = List.map typ_of_exp t.templ_args in 
    List.fold_left (x_add merge_types) UNK ty_list
  (* Func expressions *)
  | Func _                    -> Gen.Basic.report_error pos "typ_of_exp doesn't support Func"
  | BExpr _ -> Bool

let typ_of_exp (e: exp) : typ =
  let pr = !print_formula_exp in
  Debug.no_1 "typ_of_exp" pr string_of_typ typ_of_exp e

(* Slicing Utils *)
let rec set_il_formula f il =
  match f with
  | BForm (bf, lbl) -> BForm (set_il_b_formula bf il, lbl)
  | _ -> f

and set_il_b_formula bf il =
  let (pf, o_il) = bf in
  match o_il with
  | None -> (pf, il)
  | Some (_, _, l_exp) ->
    match il with
    | None -> bf
    | Some (b, i, le) -> (pf, Some (b, i, le@l_exp))

and set_il_exp exp il =
  let (pe, _) = exp in (pe, il)


let find_closure_pure_x (v:(ident*primed)) (f:formula) : (ident*primed) list =
  let ps = list_of_conjs f in
  let eqvars = List.map find_equal_var ps in
  let eqvars = List.concat eqvars in
  find_closure v eqvars

(*find all variables that are equal to variable v*)
let find_closure_pure (v:(ident*primed)) (f:formula) : (ident*primed) list =
  let pr = pr_list !print_id in
  Debug.no_2 "find_closure_pure"
    !print_id !print_formula pr
    find_closure_pure_x v f

(*parition a formula f into those of vs and the rest*)
let partition_pointer (vs:(ident*primed) list) (f:formula) : (formula list)* (formula list) =
  let ps = list_of_conjs f in
  let rec helper ps =
    match ps with
    | [] -> [],[]
    | (e::es) ->
      let ls1,ls2 = helper es in
      let vars = find_equal_var e in
      let vars = List.map (fun (v1,v2) -> [v1;v2]) vars in
      let vars = List.concat vars in
      if (vars!=[] && List.for_all (fun v -> Gen.BList.mem_eq eq_var v vs) vars) then
        (*YES: belong to vs*)
        (e::ls1),ls2
      else
        ls1,e::ls2
  in
  let ls1,ls2 = helper ps in
  (ls1,ls2)

and subst_var (fr, t) (o : (ident*primed)) = if (eq_var fr o) then t else o

(*x'=x ==> x_new = x_old*)
let trans_special_formula s (p:formula) vars =
  (match p with
   | BForm ((p_f,sth1),sth2) ->
     (match p_f with
      | Eq (e1,e2,pos) ->
        (match e1,e2 with
         | Var ((id1,p1),pos1), Var ((id2,p2),pos2) ->
           (*x'=x*)
           if (id1=id2) && (p1!=p2) then
             if (Gen.BList.mem_eq eq_var (id1,p1) vars) || (Gen.BList.mem_eq eq_var (id2,p2) vars) then
               let unprimed_param = (id1,Unprimed) in
               let primed_param = (id1,Primed) in
               let old_param = (id1^"_old",Unprimed) in
               let new_param = (id1^"_new",Unprimed) in
               let s1 = (unprimed_param,old_param) in
               let s2 = (primed_param,new_param) in
               (*??? QUICK TRICK*)
               (* let () = print_endline ("v1 = " ^ (!print_id (id1,p1))) in *)
               (* let () = print_endline ("v2 = " ^ (!print_id (id2,p2))) in *)
               let new_v1 = subst_var s1 (id1,p1) in
               let new_v1 = subst_var s2 new_v1 in
               let new_v2 = subst_var s1 (id2,p2) in
               let new_v2 = subst_var s2 new_v2 in
               let e1 = Var (new_v1,pos1) in
               let e2 = Var (new_v2,pos2) in
               let ee = Eq (e1,e2,pos) in
               BForm ((ee,sth1),sth2)
             else p
           else p
         | _ -> p
        )
      | _ -> p
     )
   | _ -> p
  )



(* 
   Make a formula from a list of conjuncts, namely
   [F1,F2,..,FN]  ==> F1 & F2 & .. & Fn 
*)
(* let conj_of_list (fs : formula list) pos : formula = *)
(*   match fs with *)
(*     | [] -> mkTrue pos *)
(*     | x::xs -> List.fold_left (fun a c-> mkAnd a c no_pos) x xs *)

let join_conjunctions fl = conj_of_list fl

(* let join_disjunctions fl = disj_of_list fl *)

let mkAndList_opt f =
  if !Globals.remove_label_flag then 
    join_conjunctions (List.map snd f)
  else mkAndList f

let mkAndList_opt f =
  let pr = pr_list (pr_pair pr_none !print_formula) in
  let pr2 = !print_formula in
  Debug.no_1 "mkAndList_opt" pr pr2 mkAndList_opt f 

let args_of_term_ann ann =
  match ann with
  | TermU uid -> uid.tu_args
  | TermR uid -> uid.tu_args
  | _ -> []

(* (* Expression *)                                                                                                                                         *)
(* and exp =                                                                                                                                                *)
(*   | Ann_Exp of (exp * typ * loc)                                                                                                                         *)
(*   | Null of loc                                                                                                                                          *)
(*   | Level of ((ident * primed) * loc)                                                                                                                    *)
(*   | Var of ((ident * primed) * loc)                                                                                                                      *)
(*   (* variables could be of type pointer, int, bags, lists etc *)                                                                                         *)
(*   | IConst of (int * loc)                                                                                                                                *)
(*   | FConst of (float * loc)                                                                                                                              *)
(*   | AConst of (heap_ann * loc)                                                                                                                           *)
(*   | InfConst of (ident * loc) (* Constant for Infinity  *)                                                                                               *)
(*   | Tsconst of (Tree_shares.Ts.t_sh * loc)                                                                                                               *)
(*   | Bptriple of ((exp * exp * exp) * loc) (*triple for bounded permissions*)                                                                             *)
(*   (*| Tuple of (exp list * loc)*)                                                                                                                        *)
(*   | Add of (exp * exp * loc)                                                                                                                             *)
(*   | Subtract of (exp * exp * loc)                                                                                                                        *)
(*   | Mult of (exp * exp * loc)                                                                                                                            *)
(*   | Div of (exp * exp * loc)                                                                                                                             *)
(*   | Max of (exp * exp * loc)                                                                                                                             *)
(*   | Min of (exp * exp * loc)                                                                                                                             *)
(*   | TypeCast of (typ * exp * loc)                                                                                                                        *)
(*   (* bag expressions *)                                                                                                                                  *)
(*   | Bag of (exp list * loc)                                                                                                                              *)
(*   | BagUnion of (exp list * loc)                                                                                                                         *)
(*   | BagIntersect of (exp list * loc)                                                                                                                     *)
(*   | BagDiff of (exp * exp * loc)                                                                                                                         *)
(*   (* list expressions *)                                                                                                                                 *)
(*   | List of (exp list * loc)                                                                                                                             *)
(*   | ListCons of (exp * exp * loc)                                                                                                                        *)
(*   | ListHead of (exp * loc)                                                                                                                              *)
(*   | ListTail of (exp * loc)                                                                                                                              *)
(*   | ListLength of (exp * loc)                                                                                                                            *)
(*   | ListAppend of (exp list * loc)                                                                                                                       *)
(*   | ListReverse of (exp * loc)                                                                                                                           *)
(*   | ArrayAt of ((ident * primed) * (exp list) * loc)      (* An Hoa : array access, extend the index to a list of indices for multi-dimensional array *) *)
(*   | Func of (ident * (exp list) * loc)                                                                                                                   *)

let rec transform_exp_x f (e : exp) : exp = 
  let r =  f e in 
  match r with
  | Some ne -> ne
  | None -> (match e with
      | Null _  | Var _ | Level _ | IConst _ | AConst _ 
      | Tsconst _ | Bptriple _ | FConst _ | Tup2 _ -> e
      | Ann_Exp (e,t,l) ->
        let ne = transform_exp f e in
        Ann_Exp (ne,t,l)
      | Add (e1,e2,l) ->
        let ne1 = transform_exp f e1 in
        let ne2 = transform_exp f e2 in
        Add (ne1,ne2,l)
      | Subtract (e1,e2,l) ->
        let ne1 = transform_exp f e1 in
        let ne2 = transform_exp f e2 in
        Subtract (ne1,ne2,l)
      | Mult (e1,e2,l) ->
        let ne1 = transform_exp f e1 in
        let ne2 = transform_exp f e2 in
        Mult (ne1,ne2,l)
      | Div (e1,e2,l) ->
        let ne1 = transform_exp f e1 in
        let ne2 = transform_exp f e2 in
        Div (ne1,ne2,l)
      | Max (e1,e2,l) ->
        let ne1 = transform_exp f e1 in
        let ne2 = transform_exp f e2 in
        Max (ne1,ne2,l)
      | Min (e1,e2,l) ->
        let ne1 = transform_exp f e1 in
        let ne2 = transform_exp f e2 in
        Min (ne1,ne2,l)
      | TypeCast (ty, e1, l) ->
        let ne1 = transform_exp f e1 in
        TypeCast (ty, ne1, l)
      | Bag (le,l) -> 
        Bag (List.map (fun c-> transform_exp f c) le, l) 
      | BagUnion (le,l) -> 
        BagUnion (List.map (fun c-> transform_exp f c) le, l)
      | BagIntersect (le,l) -> 
        BagIntersect (List.map (fun c-> transform_exp f c) le, l)
      | BagDiff (e1,e2,l) ->
        let ne1 = transform_exp f e1 in
        let ne2 = transform_exp f e2 in
        BagDiff (ne1,ne2,l)
      | List (e1,l) -> List (( List.map (transform_exp f) e1), l) 
      | ListCons (e1,e2,l) -> 
        let ne1 = transform_exp f e1 in
        let ne2 = transform_exp f e2 in
        ListCons (ne1,ne2,l)
      | ListHead (e1,l) -> ListHead ((transform_exp f e1),l)
      | ListTail (e1,l) -> ListTail ((transform_exp f e1),l)
      | ListLength (e1,l) -> ListLength ((transform_exp f e1),l)
      | ListAppend (e1,l) ->  ListAppend (( List.map (transform_exp f) e1), l) 
      | ListReverse (e1,l) -> ListReverse ((transform_exp f e1),l)
      | Func (id, es, l) -> Func (id, (List.map (transform_exp f) es), l)
      | ArrayAt (a, i, l) -> ArrayAt (a, (List.map (transform_exp f) i), l) (* An Hoa *)
      | NegInfConst _
      | InfConst _ -> Error.report_no_pattern ()
      | BExpr _ -> e
      | Template _ -> e
    )

and transform_exp f (e : exp) : exp =
  let pr = !print_formula_exp in
  Debug.no_1 "transform_exp" pr pr (fun _ -> transform_exp_x f e) e

let transform_b_formula_x f (e : b_formula) : b_formula = 
  let (f_b_formula, f_exp) = f in
  let r =  f_b_formula e in 
  match r with
  | Some e1 -> e1
  | None -> (
      let (pf,il) = e in
      let npf = ( let rec helper pf = 
                    match pf with
                    | Frm _ | BConst _ | XPure _
                    (* | VarPerm _ *)
                    | BVar _ | BagMin _ | SubAnn _ | BagMax _ -> pf
                    | Lt (e1,e2,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      Lt (ne1,ne2,l)
                    | Lte (e1,e2,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      Lte (ne1,ne2,l)
                    | Gt (e1,e2,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      Gt (ne1,ne2,l)
                    | Gte (e1,e2,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      Gte (ne1,ne2,l)
                    | Eq (e1,e2,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      Eq (ne1,ne2,l)
                    | Neq (e1,e2,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      Neq (ne1,ne2,l)
                    | EqMax (e1,e2,e3,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      let ne3 = transform_exp f_exp e3 in
                      EqMax (ne1,ne2,ne3,l)   
                    | EqMin (e1,e2,e3,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      let ne3 = transform_exp f_exp e3 in
                      EqMin (ne1,ne2,ne3,l)
                    | BagIn (v,e,l)->
                      let ne1 = transform_exp f_exp e in
                      BagIn (v,ne1,l)
                    | BagNotIn (v,e,l)->
                      let ne1 = transform_exp f_exp e in
                      BagNotIn (v,ne1,l)
                    | BagSub (e1,e2,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      BagSub (ne1,ne2,l)
                    | ListIn (e1,e2,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      ListIn (ne1,ne2,l)
                    | ListNotIn (e1,e2,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      ListNotIn (ne1,ne2,l)
                    | ListAllN (e1,e2,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      ListAllN (ne1,ne2,l)
                    | ListPerm (e1,e2,l) ->
                      let ne1 = transform_exp f_exp e1 in
                      let ne2 = transform_exp f_exp e2 in
                      ListPerm (ne1,ne2,l)
                    | RelForm (r, args, l) ->
                      let nargs = List.map (transform_exp f_exp) args in
                      RelForm (r,nargs,l)
                    | ImmRel (r, cond, l) ->
                      let r = helper r in
                      ImmRel (r,cond,l)
                    | LexVar (t,es1,es2,l) -> 
                      let nes1 = List.map (transform_exp f_exp) es1 in
                      let nes2 = List.map (transform_exp f_exp) es2 in
                      LexVar (t,nes1,nes2,l)
                  in helper pf) in
      (npf,il)
    )

let transform_b_formula f (e : b_formula) : b_formula =
  let pr = !print_b_formula in
  Debug.no_1 "transform_b_formula" pr pr
    (fun _ -> transform_b_formula_x f e) e

let rec transform_formula_x f (e : formula) : formula = 
  let (_ , _, f_formula, f_b_formula, f_exp) = f in
  let r = f_formula e in 
  match r with
  | Some e1 -> e1
  | None -> (
      match e with
      | BForm (b1,b2) ->
        let new_b1 = transform_b_formula (f_b_formula, f_exp) b1 in
        BForm (new_b1, b2)
      | And (e1,e2,l) -> 
        let ne1 = transform_formula f e1 in
        let ne2 = transform_formula f e2 in
        mkAnd ne1 ne2 l
      | AndList b -> AndList (map_l_snd (transform_formula f) b) 
      | Or (e1,e2,fl, l) -> 
        let ne1 = transform_formula f e1 in
        let ne2 = transform_formula f e2 in
        Or (ne1,ne2,fl,l)
      | Not (e,fl,l) ->
        let ne1 = transform_formula f e in
        Not (ne1,fl,l)
      | Forall (v,e,fl,l) ->
        let ne = transform_formula f e in
        Forall(v,ne,fl,l)
      | Exists (v,e,fl,l) ->
        let ne = transform_formula f e in
        Exists(v,ne,fl,l)
    )

and transform_formula f (e:formula) :formula =
  Debug.no_1 "IP.transform_formula" !print_formula !print_formula
    (fun _ -> transform_formula_x f e ) e

let is_esv e= match e with
  | Var _ -> true
  | _ -> false

let is_bexp_p pf= match pf with
  | BVar _
  | Lt _
  | Gt _ 
  | Lte _ 
  | Gte _ 
  | Eq _
  | Neq _ -> true
  | _ -> false

let is_bexp_b bf=
  let (pf,_) = bf in
  is_bexp_p pf

let rec is_bexp_x f=
  let recf = is_bexp_x in
  match f with
  | BForm (bf,_) -> is_bexp_b bf
  | And (f1,f2,_) -> (recf f1)&&(recf f2)
  | AndList fs -> List.for_all (fun (_,f1) -> recf f1) fs
  | Or (f1,f2,_,_) -> (recf f1)&&(recf f2)
  | Not (f1, _, _)
  | Forall (_,f1,_,_)
  | Exists (_,f1,_,_) -> (recf f1)

let is_bexp f=
  let pr = !print_formula in
  Debug.no_1 "is_bexp" pr string_of_bool
    (fun _ -> is_bexp_x f) f


let rec transform_bexp_p_x f0 a b pf0 =
  let helper pf = match pf with
    | Eq (e1, e2, p) -> begin
        match e2 with
        | BExpr f2 -> begin
            let p = pos_of_pf pf in
            let f1 = match e1 with
              | Var (idp,p) -> BForm ((BVar (idp,p), a), b)
              | BExpr f -> f
              | _ -> raise Not_found
            in
            let f11 = And (f1, f2, p) in
            let f22 = And (Not (f1, None, p), Not (f2, None, p), p) in
            Or (f11, f22, None, p)
          end
        | _ -> raise Not_found
      end
    | Neq (e1, e2, p) -> begin
        match e2 with
        | BExpr f2 -> begin
            let p = pos_of_pf pf in
            let f1 = match e1 with
              | Var (idp,p) -> BForm ((BVar (idp,p), a), b)
              | BExpr f -> f
              | _ -> raise Not_found
            in
            let f11 = And (f1, Not (f2, None, p), p) in
            let f22 = And (Not (f1, None, p), f2, p) in
            Or (f11, f22, None, p)
          end
        | _ -> raise Not_found
      end
    | _ -> raise Not_found
  in
  try
    helper pf0
  with _ -> f0

let transform_bexp_p f0 lb sl pf =
  let pr1 = !print_formula in
  Debug.no_1 "transform_bexp_p" pr1 pr1
    (fun _ -> transform_bexp_p_x f0 lb sl pf) f0

(*
 v=e --> v & e | !v & !e
 e1 = e2 --> e1 & e2 | !(e1) & !e2
 e1!=e2 <--> (e1 & !e2 | !e2 & e1)
*)
let rec transform_bexp_x f0 lb sl e f2=
  match e with
  | Var (idp,p) ->
    let p = pos_of_formula f0 in
    let f1 = BForm ((BVar (idp,p), lb), sl) in
    let f11 = And (f1, f2, p) in
    let f22 = And (Not (f1, None, p), Not (f2, None, p), p) in
    Or (f11, f22, None, p)
  | _ -> f0

let transform_bexp f0 lb sl e f=
  let pr = !print_formula in
  Debug.no_1 "transform_bexp" pr pr
    (fun _ -> transform_bexp_x f0 lb sl e f) f

let rec transform_bexp_form f: formula=
  let recf = transform_bexp_form in
  match f with
  | BForm ((pf,a),b) -> begin
      match pf with
      | Eq (e1, e2, p)
      | Neq (e1, e2, p) -> begin
          match e1,e2 with
          | Var _, BExpr f2 -> transform_bexp f a b e1 f2
          | _ -> f
        end
      | _ -> f
    end
  | And (f1,f2,l) -> And (recf f1,recf f2,l)
  | AndList fs ->AndList ( List.map (fun (a,f1) -> (a, recf f1)) fs)
  | Or (f1,f2,c,l) -> Or(recf f1,recf f2,c,l)
  | Not (f1, a, b) -> Not (recf f1, a,b)
  | Forall (a,f1,b,c) -> Forall (a,recf f1,b,c)
  | Exists (a,f1,b,c) -> Exists(a,recf f1, b, c)

let is_ann_type = (=) AnnT

let is_anon_ident (n,p) : bool = ((String.length n) > 5) && ((String.compare (String.sub n 0 5) "Anon_") == 0) && (p==Unprimed)
