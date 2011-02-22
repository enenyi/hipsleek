(**
   Helper and other ultilities for Hip/Sleek's GUI
 *)

open Globals

(**/**)
module TP = Tpdispatcher
module SE = Sleekengine
module SC = Sleekcommons
(**/**)

(** Wrap a widget in a scrolled window and return that window
 *)
let create_scrolled_win child = 
  let scroll_win = GBin.scrolled_window 
    ~hpolicy: `AUTOMATIC ~vpolicy: `AUTOMATIC 
    () in
  scroll_win#add child#coerce;
  scroll_win

(**/**)
let log_func = ref (fun _ -> raise Not_found)
let verbose_flag = ref true
(**/**)
(** Print msg to stdout if verbose flag is on *)
let log msg =
  if !verbose_flag then begin
    try !log_func msg
    with Not_found ->
      log_func := (fun msg -> print_endline msg; flush stdout);
      !log_func msg
  end

(**
   Common operations on text file
 *)
module FileUtil = struct

  (** Read a text file and then return it's content as a string 
   *)
  let read_from_file (fname: string) : string =
    if Sys.file_exists fname then begin
      let ic = open_in fname in
      let size = in_channel_length ic in
      let buf = String.create size in
      really_input ic buf 0 size;
      close_in ic;
      buf
    end else ""

  (** Write text to a file 
   *)
  let write_to_file (fname: string) (text: string) : unit =
    let oc = open_out fname in
    output_string oc text;
    flush oc;
    close_out oc;
    ()

end (* FileUtil *)


(**
   Quick & dirty parsing functions of sleek file
   based on simple regular expressions
 *)
module SourceUtil = struct

  type seg_pos = {
    start_char: int;
    start_line: int;
    stop_char: int;
    stop_line: int;
  }

  type procedure = {
    name: string;
    pos: seg_pos;
  }

  type entailment = procedure

  exception Syntax_error of string * seg_pos

  let checkentail_re = Str.regexp "checkentail \\([^\\.]+\\)\\."
  let print_re = Str.regexp "print [^\\.]+\\."
  let new_line_re = Str.regexp "^"

  let string_of_entailment (e: entailment) =
    Printf.sprintf "(%d,%d): %s" e.pos.start_line e.pos.stop_line e.name

  (** return a list of all positions of "new line" char in src *)
  let get_new_line_positions (src: string) : int list =
    let rec new_line_pos (start: int): int list =
      try
        let pos = Str.search_forward new_line_re src start in
        pos::(new_line_pos (pos+1))
      with Not_found | Invalid_argument _ -> []
    in
    new_line_pos 0

  (** map a position to it's line number,
     based on a list of positions of new line chars
   *)
  let char_pos_to_line_num (pos: int) (new_lines: int list) : int =
    (** return index of first item in list xs which value greater than x
       return -1 if xs is empty *)
    let rec greater_than x xs = match xs with
      | [] -> -1
      | head::tail -> if head > x then 0 else 1+(greater_than x tail)
    in
    greater_than pos new_lines

  (** remove all checkentail command from source *)
  let remove_checkentail (src: string) : string =
    Str.global_replace checkentail_re "" src

  (** remove all print command from source *)
  let remove_print (src: string) : string =
    Str.global_replace print_re "" src

  let clean (src: string) : string =
    let res = remove_checkentail src in
    let res = remove_print res in
    res

  (** parse sleek file and return list of entailments (to be checked) *)
  let parse_entailment_list (src: string) : entailment list =
    let new_lines = get_new_line_positions src in
    let to_line_num pos = char_pos_to_line_num pos new_lines in
    let rec parse (start: int) : entailment list =
      try
        let start_char = Str.search_forward checkentail_re src start in
        let stop_char = Str.match_end () in
        let f = Str.matched_group 1 src in
        let start_line = to_line_num start_char in
        let stop_line = to_line_num stop_char in
        let pos = {
          start_char = start_char;
          stop_char = stop_char;
          start_line = start_line;
          stop_line = stop_line;
        } in
        let first = {
          pos = pos;
          name = f;
        } in
        first::(parse (stop_char+1))
      with Not_found -> []
    in
    parse 0

  let parse_procedure_list (src: string) : procedure list =
    let parse (proc: Iast.proc_decl) : procedure =
      let proc_pos = proc.Iast.proc_loc in
      let pos = {
        start_char = proc_pos.start_pos.Lexing.pos_cnum;
        start_line = proc_pos.start_pos.Lexing.pos_lnum;
        stop_char = proc_pos.end_pos.Lexing.pos_cnum;
        stop_line = proc_pos.end_pos.Lexing.pos_lnum;
      } in
      {
        name = proc.Iast.proc_name;
        pos = pos;
      }
    in
    let lexbuf = Lexing.from_string src in
    try
      let prog = Iparser.program (Ilexer.tokenizer "editor_buffer") lexbuf in
      let procs = prog.Iast.prog_proc_decls in
      List.rev_map parse procs
    with Parsing.Parse_error ->
      let start_p = lexbuf.Lexing.lex_start_p in
      let curr_p = lexbuf.Lexing.lex_curr_p in
      let pos = {
        start_char = start_p.Lexing.pos_cnum;
        stop_char = curr_p.Lexing.pos_cnum;
        start_line = start_p.Lexing.pos_lnum;
        stop_line = start_p.Lexing.pos_lnum;
      } in
      log (Printf.sprintf "Syntax error at line %d" start_p.Lexing.pos_lnum);
      raise (Syntax_error ("Syntax error", pos))

  (** search for all substring in a string *)
  let search (doc: string) (sub: string) : seg_pos list =
    let reg = Str.regexp_string sub in
    let rec search_next (start: int) : seg_pos list =
      try
        let start_char = Str.search_forward reg doc start in
        let stop_char = Str.match_end () in
        let pos = { 
          start_char = start_char; stop_char = stop_char;
          start_line = -1; stop_line = -1
        } in
        pos::(search_next (stop_char+1))
      with Not_found -> []
    in
    search_next 0

end (* SourceUtil *)


(**
   Helper for interacting with Sleek script
   Command calling, process management, parsing of result,...
 *)
module SleekHelper = struct

  open SourceUtil

  type sleek_args = {
    tp: TP.tp_type;
    eps: bool;
    eap: bool;
  }

  let infile = "/tmp/sleek.in." ^ (string_of_int (Unix.getpid ()))
  let outfile = "/tmp/sleek.out." ^ (string_of_int (Unix.getpid ()))

  let default_args = {
    tp = TP.OmegaCalc;
    eps = false;
    eap = false;
  }

  let build_args_string (args: sleek_args) =
    let tp = " -tp " ^ (TP.string_of_tp args.tp) in
    let eps = if args.eps then " --eps" else "" in
    let eap = if args.eap then " --eap" else "" in
    let res = tp ^ eps ^ eap in
    res

  let sleek_command (args: sleek_args) = 
    let args_string = build_args_string args in
    Printf.sprintf "./sleek -dd %s %s > %s" args_string infile outfile

  (** run sleek with source text and return result string *)
  let run_sleek ?(args = default_args) (src: string) =
    FileUtil.write_to_file infile src;
    let cmd = sleek_command args in
    ignore (Sys.command cmd);
    let res = FileUtil.read_from_file outfile in
    Sys.remove infile;
    Sys.remove outfile;
    res

  let parse_checkentail_result (res: string) =
    let regexp = Str.regexp "Valid\\." in
    try
      ignore (Str.search_forward regexp res 0);
      true
    with Not_found -> false

  let checkentail_external ?args (src: string) (e: entailment) =
    let header = clean (String.sub src 0 e.pos.start_char) in
    let src = Printf.sprintf "%s checkentail %s. print residue." header e.name in
    let res = run_sleek ?args src in
    parse_checkentail_result res, res

  let parse_command_list (src: string) : SC.command list =
    let lexbuf = Lexing.from_string src in
    Sparser.opt_command_list (Slexer.tokenizer "editor_buffer") lexbuf

  let process_cmd cmd = match cmd with
    | SC.DataDef ddef -> 
        log "processing data def";
        SE.process_data_def ddef; None
    | SC.PredDef pdef -> 
        log "processing pred def";
        SE.process_pred_def pdef; None
    | SC.EntailCheck (iante, iconseq) -> 
        log "processing entail check"; 
        Some (SE.run_entail_check iante iconseq)
    | SC.CaptureResidue lvar -> 
        log "processing capture residue";
        SE.process_capture_residue lvar; None
    | SC.LemmaDef ldef -> 
        log "processing lemmad def";
        SE.process_lemma ldef; None
    | SC.PrintCmd pcmd -> 
        log "processing print cmd";
        SE.process_print_command pcmd; None
    | SC.LetDef (lvar, lbody) -> 
        log "processing let def";
        SC.put_var lvar lbody; None
    | SC.Time (b,s,_) -> None
    | SC.EmptyCmd -> None

  let checkentail src e =
    try
      log ("Checking entailment: " ^ (string_of_entailment e));
      let header = clean (String.sub src 0 e.pos.start_char) in
      let src = Printf.sprintf "%s checkentail %s." header e.name in
      let cmds = parse_command_list src in
      let _ = SE.clear_all () in
      let rec exec cmds = match cmds with
        | [] -> failwith "[gUtil.ml/checkentail]: empty command list"
        | [cmd] -> process_cmd cmd
        | cmd::rest -> ignore (process_cmd cmd); exec rest
      in
      let res, contexts = match exec cmds with
        | None -> failwith "[gUtil.ml/checkentail]: last command is not checkentail command"
        | Some v -> v
      in
      let residue = match SE.get_residue () with
        | Some residue ->
            let formulas = Cformula.list_formula_of_list_context residue in
            let fstring = Cprinter.string_of_list_formula formulas in
            "Residue:\n" ^ fstring ^ "\n"
        | None -> ""
      in
      let context = Cprinter.string_of_list_context contexts in
      let info = residue ^ context in
      let valid = if res then "valid" else "fail" in
      log valid;
      res, info
    with exn as e ->
      false, (Printexc.to_string e) ^ "\n" ^ (Printexc.get_backtrace ())

end (* SleekHelper *)

module HipHelper = struct

  open SourceUtil

  type hip_args = {
    tp: TP.tp_type;
    eps: bool;
    eap: bool;
  }

  let infile = "hip.in." ^ (string_of_int (Unix.getpid ()))
  let outfile = "hip.out." ^ (string_of_int (Unix.getpid ()))
  let errfile = "hip.err." ^ (string_of_int (Unix.getpid ()))
  let debug_log_buffer = Buffer.create 1024
  let prover_log_buffer = Buffer.create 1024

  let default_args = {
    tp = TP.OmegaCalc;
    eps = false;
    eap = false;
  }

  let build_args_string (args: hip_args) =
    let tp = "-tp " ^ (TP.string_of_tp args.tp) in
    let eps = if args.eps then " --eps" else "" in
    let eap = if args.eap then " --eap" else "" in
    let res = tp ^ eps ^ eap in
    res

  let hip_command (args: hip_args) (proc_name: string) =
    let args = build_args_string args in
    let hip = "./hip -dd --log-cvc3 --log-omega --log-coq --log-mona --log-redlog" in
    Printf.sprintf "%s %s -p %s %s>%s 2>%s" hip args proc_name infile outfile errfile

  (** run hip with source text and return result string *)
  let run_hip ?(args = default_args) (src: string) (proc_name: string) =
    FileUtil.write_to_file infile src;
    let cmd = hip_command args proc_name in
    log ("Executing: " ^ cmd);
    ignore (Sys.command cmd);
    let res = FileUtil.read_from_file outfile in
    Buffer.clear debug_log_buffer;
    Buffer.add_string debug_log_buffer (FileUtil.read_from_file errfile);
    Buffer.clear prover_log_buffer;
    let tp_log_file = TP.log_file_of_tp args.tp in
    Buffer.add_string prover_log_buffer (FileUtil.read_from_file tp_log_file);
    Sys.remove infile;
    Sys.remove outfile;
    Sys.remove errfile;
    res

  let parse_result (res: string) =
    let regexp = Str.regexp_string "SUCCESS" in
    try
      ignore (Str.search_forward regexp res 0);
      log "Success.";
      true
    with Not_found -> (log "FAIL!"; false)

  let check_proc_external ?args (src: string) (p: procedure) =
    let res = run_hip ?args src p.name in
    parse_result res

  let get_debug_log () =
    Buffer.contents debug_log_buffer

  let get_prover_log () =
    Buffer.contents prover_log_buffer

end (* HipHelper *)

let initialize () =
  ignore (GtkMain.Main.init ());
  Debug.devel_debug_on := true;
  Debug.log_devel_debug := true;
  Globals.reporter := (fun loc msg ->
    let pos = {
      SourceUtil.start_char = loc.start_pos.Lexing.pos_cnum;
      SourceUtil.stop_char = loc.end_pos.Lexing.pos_cnum;
      SourceUtil.start_line = loc.start_pos.Lexing.pos_lnum;
      SourceUtil.stop_line = loc.end_pos.Lexing.pos_lnum;
    } in
    raise (SourceUtil.Syntax_error ("Syntax error: " ^ msg, pos))
  );
  TP.enable_log_for_all_provers ();
  TP.start_prover ()

let finalize () =
  TP.stop_prover ()

