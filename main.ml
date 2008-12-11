(******************************************)
(* command line processing                *)
(******************************************)

let parse_only = ref false

let to_java = ref false

let comp_pred = ref false

let rtc = ref false

let pred_to_compile = ref ([] : string list)

let set_pred arg = 
  comp_pred := true;
  pred_to_compile := arg :: !pred_to_compile


let usage_msg = Sys.argv.(0) ^ " [options] <source files>"

let set_source_file arg = 
  Globals.source_files := arg :: !Globals.source_files

let set_proc_verified arg =
  let procs = Util.split_by "," arg in
	Globals.procs_verified := procs @ !Globals.procs_verified

let process_cmd_line () = Arg.parse [
	("--simpl-pure-part", Arg.Set Globals.simplify_pure,
	"Simplify the pure part of the formulas");
	("--combined-lemma-heuristic", Arg.Set Globals.lemma_heuristic,
	"Use the combined coerce&match + history heuristic for lemma application");
	("--move-exist-to-LHS", Arg.Set Globals.move_exist_to_LHS,
	"Move instantiation (containing existential vars) to the LHS at the end of the folding process");
	("--max-renaming", Arg.Set Globals.max_renaming,
	"Always rename the bound variables");
	("--no-anon-exist", Arg.Clear Globals.anon_exist,
	"Disallow anonymous variables in the precondition to be existential");
	("--LHS-wrap-exist", Arg.Set Globals.wrap_exist,
	"Existentially quantify the fresh vars in the residue after applying ENT-LHS-EX");
  ("-noee", Arg.Clear Tpdispatcher.elim_exists_flag,
   "No eleminate existential quantifiers before calling TP.");
  ("-nofilter", Arg.Clear Tpdispatcher.filtering_flag,
   "No assumption filtering.");
  ("-cp", Arg.String set_pred,
   "Compile specified predicate to Java.");
  ("-rtc", Arg.Set rtc,
   "Compile to Java with runtime checks.");
  ("-nopp", Arg.String Rtc.set_nopp,
   "-nopp caller:callee: do not check callee's pre/post in caller");
  ("-nofield", Arg.String Rtc.set_nofield,
   "-nofield proc: do not perform field check in proc");
  ("--verify-callees", Arg.Set Globals.verify_callees,
   "Verify callees of the specified procedures");
  ("--check-coercions", Arg.Set Globals.check_coercions,
   "Check coercion validity");
  ("-dd", Arg.Set Debug.devel_debug_on,
   "Turn on devel_debug");
  ("-gist", Arg.Set Globals.show_gist,
   "Show gist when implication fails");
  ("--hull-pre-inv", Arg.Set Globals.hull_pre_inv,
   "Hull precondition invariant at call sites");
  ("-inline", Arg.String Inliner.set_inlined,
   "Procedures to be inlined");
  ("-java", Arg.Set to_java,
   "Convert source code to Java");
  ("--log-proof", Arg.String Prooftracer.set_proof_file,
   "Log (failed) proof to file");
  ("--trace-all", Arg.Set Globals.trace_all,
   "Trace all proof paths");
  ("--log-cvcl", Arg.String Cvclite.set_log_file,
   "Log all CVC Lite formula to specified log file");
  ("--log-omega", Arg.Set Omega.log_all_flag,
   "Log all formulae sent to Omega Calculator in file allinput.oc");
  ("--log-isabelle", Arg.Set Isabelle.log_all_flag,
   "Log all formulae sent to Isabelle in file allinput.thy");
  ("--log-coq", Arg.Set Coq.log_all_flag,
   "Log all formulae sent to Coq in file allinput.v");
  ("--log-mona", Arg.Set Mona.log_all_flag,
   "Log all formulae sent to Mona in file allinput.mona");
  ("--use-isabelle-bag", Arg.Set Isabelle.bag_flag,
   "Use the bag theory from Isabelle, instead of the set theory");
  ("--no-coercion", Arg.Clear Globals.use_coercion,
   "Turn off coercion mechanism");
  ("--no-exists-elim", Arg.Clear Globals.elim_exists,
   "Turn off existential quantifier elimination during type-checking");
  ("--no-diff", Arg.Set Solver.no_diff,
   "Drop disequalities generated from the separating conjunction");
  ("--no-set", Arg.Clear Globals.use_set,
   "Turn of set-of-states search");
  ("--no-unsat-elim", Arg.Clear Globals.elim_unsat,
   "Turn off unsatisfiable formulae elimination during type-checking");
  ("-nxpure", Arg.Set_int Globals.n_xpure,
   "Number of unfolding using XPure");
  ("-p", Arg.String set_proc_verified, 
   "Procedure to be verified. If none specified, all are verified.");
  ("-parse", Arg.Set parse_only,
   "Parse only");
  ("-print", Arg.Set Globals.print_proc,
   "Print procedures being checked");
  ("--print-iparams", Arg.Set Globals.print_mvars,
   "Print input parameters of predicates");
  ("--print-x-inv", Arg.Set Globals.print_x_inv,
   "Print computed view invariants");
  ("-stop", Arg.Clear Globals.check_all,
   "Stop checking on erroneous procedure");
  ("--build-image", Arg.Symbol (["true"; "false"], Isabelle.building_image),
   "Build the image theory in Isabelle - default false");
  ("-tp", Arg.Symbol (["cvcl"; "omega"; "co"; "isabelle"; "coq"; "mona"; "om"; "oi"; "set"; "cm"], Tpdispatcher.set_tp),
   "Choose theorem prover:\n\tcvcl: CVC Lite\n\tomega: Omega Calculator (default)\n\tco: CVC Lite then Omega\n\tisabelle: Isabelle\n\tcoq: Coq\n\tmona: Mona\n\tom: Omega and Mona\n\toi: Omega and Isabelle\n\tset: Use MONA in set mode.\n\tcm: CVC Lite then MONA.");
  ("--use-field", Arg.Set Globals.use_field,
   "Use field construct instead of bind");
  ("--use-large-bind", Arg.Set Globals.large_bind,
   "Use large bind construct, where the bound variable may be changed in the body of bind");
  ("-v", Arg.Set Debug.debug_on, 
   "Verbose")] set_source_file usage_msg

(******************************************)
(* main function                          *)
(******************************************)

let parse_file_full file_name = 
  let org_in_chnl = open_in file_name in
  let input = Lexing.from_channel org_in_chnl in
    try
	  let ptime1 = Unix.times () in
	  let t1 = ptime1.Unix.tms_utime +. ptime1.Unix.tms_cutime in
		print_string "Parsing... ";
		let prog = Iparser.program (Ilexer.tokenizer file_name) input in
		  close_in org_in_chnl;
		  let ptime2 = Unix.times () in
		  let t2 = ptime2.Unix.tms_utime +. ptime2.Unix.tms_cutime in
			print_string ("done in " ^ (string_of_float (t2 -. t1)) ^ " second(s)\n");
			prog
    with
		End_of_file -> exit 0	  

let process_source_full source =
  print_string ("\nProcessing file \"" ^ source ^ "\"\n");
  let prog = parse_file_full source in
	if !to_java then begin
	  print_string ("Converting to Java...");
	  let tmp = Filename.chop_extension (Filename.basename source) in
	  let main_class = Util.replace_minus_with_uscore tmp in
	  let java_str = Java.convert_to_java prog main_class in
	  let tmp2 = Util.replace_minus_with_uscore (Filename.chop_extension source) in
	  let jfile = open_out ("output/" ^ tmp2 ^ ".java") in
		output_string jfile java_str;
		close_out jfile;
		print_string (" done.\n");
		exit 0
	end;
	if not (!parse_only) then
	  let ptime1 = Unix.times () in
	  let t1 = ptime1.Unix.tms_utime +. ptime1.Unix.tms_cutime in
	  let _ = print_string ("Translating to core language...") in
	  let cprog = Astsimp.trans_prog prog in
	  let _ = 
		if !Globals.verify_callees then begin
		  let tmp = Cast.procs_to_verify cprog !Globals.procs_verified in
			Globals.procs_verified := tmp
		end in
	  let ptime2 = Unix.times () in
	  let t2 = ptime2.Unix.tms_utime +. ptime2.Unix.tms_cutime in
	  let _ = print_string (" done in " ^ (string_of_float (t2 -. t1)) ^ " second(s)\n") in
	  let _ =
		if !comp_pred then begin
		  let _ = print_string ("Compiling predicates to Java...") in
		  let compile_one_view vdef = 
			if (!pred_to_compile = ["all"] || List.mem vdef.Cast.view_name !pred_to_compile) then
			  let data_def, pbvars = Predcomp.gen_view cprog vdef in
			  let java_str = Java.java_of_data data_def pbvars in
			  let jfile = open_out (vdef.Cast.view_name ^ ".java") in
				print_string ("\n\tWriting Java file " ^ vdef.Cast.view_name ^ ".java");
				output_string jfile java_str;
				close_out jfile
			else
			  ()
		  in
			ignore (List.map compile_one_view cprog.Cast.prog_view_decls);
			print_string ("\nDone.\n");
			exit 0
		end 
	  in
	  let _ =
		if !rtc then begin
		  Rtc.compile_prog cprog source;
		  exit 0
		end
	  in
		ignore (Typechecker.check_prog cprog);
		let ptime4 = Unix.times () in
		let t4 = ptime4.Unix.tms_utime +. ptime4.Unix.tms_cutime in
		  print_string ("\nTotal verification time: " 
						^ (string_of_float t4) ^ " second(s)\n"
						^ "\tTime spent in main process: " 
						^ (string_of_float ptime4.Unix.tms_utime) ^ " second(s)\n"
						^ "\tTime spent in child processes: " 
						^ (string_of_float ptime4.Unix.tms_cutime) ^ " second(s)\n")

	  
let main1 () =
  process_cmd_line ();
  if List.length (!Globals.source_files) = 0 then begin
	(* print_string (Sys.argv.(0) ^ " -help for usage information\n") *)
	Globals.procs_verified := ["f3"];
	Globals.source_files := ["examples/test5.ss"]
  end;
  let _ = List.map process_source_full !Globals.source_files in
	(* Tpdispatcher.print_stats (); *)
	()
	  
let _ = 
  main1 ()
