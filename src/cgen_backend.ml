open Ast
open Ast_util
open PPrint

(* CGEN backend for generating CPU descriptions from Sail specifications *)

(* Describe information required by hardware *)
type hardware = string * string * (string list)

(* Map Sail types to CGEN types *)
let rec sail_typ_to_cgen_typ = function
  | Typ_aux (Typ_app (Id_aux (Id "bits", _), [A_aux (A_nexp (Nexp_aux (Nexp_constant n, _)), _)]), _) ->
    let width = Big_int.to_int n in
    if width <= 8 then "register QI"
    else if width <= 16 then "register HI"
    else if width <= 32 then "register SI"
    else if width <= 64 then "register DI"
    else "register TI"
  | Typ_aux (Typ_app (Id_aux (Id "vector", _), [A_aux (A_nexp size, _); _; A_aux (A_typ elem_typ, _)]), _) ->
    let elem_type = sail_typ_to_cgen_typ elem_typ in
    elem_type (* For vector registers, use the element type *)
  | Typ_aux (Typ_app (Id_aux (Id "register", _), [A_aux (A_typ inner_typ, _)]), _) ->
    sail_typ_to_cgen_typ inner_typ
  | Typ_aux (Typ_id (Id_aux (Id "bool", _)), _) ->
    "register QI" (* Boolean as 1-bit register *)
  | _ -> "register SI" (* default fallback *)

(* Iterator pg90 *)
let rec print_iter out_channel l =
  match l with
    | [] -> ()
    | h::t -> output_string out_channel h;
              print_iter out_channel t

(* Print indices *)
let print_indices out_channel l =
    print_iter out_channel l

(* Generate CGEN hardware definition for a register *)
let define_hardware out_channel (name, hw_type, indices) =
  output_string out_channel "(define-hardware\n";
  output_string out_channel "  (name h-";
  output_string out_channel name;
  output_string out_channel ")\n";
  output_string out_channel "  (comment \"";
  output_string out_channel name;
  output_string out_channel "\")\n";
  output_string out_channel "  (attrs all-isas all-machs)\n";
  output_string out_channel "  (type ";
  output_string out_channel hw_type;
  output_string out_channel ")\n";
  match indices with
    | [] -> output_string out_channel ")\n\n"
    | h::t ->
      output_string out_channel "  (indices ";
      print_indices out_channel indices;
      output_string out_channel ")\n)\n\n"

(* Extract register information from a register declaration *)
let process_register_dec out_channel = function
  | DEC_aux (DEC_reg (typ, id), _) ->
    let reg_name = string_of_id id in
    let cgen_type = sail_typ_to_cgen_typ typ in
    let hardware = (reg_name, cgen_type, []) in
    define_hardware out_channel hardware
  | DEC_aux (DEC_config (id, typ, _), _) ->
    let reg_name = string_of_id id in
    let cgen_type = sail_typ_to_cgen_typ typ in
    let hardware = (reg_name, cgen_type, []) in
    define_hardware out_channel hardware
  | _ -> () (* Skip other declaration types *)

(* Extract instruction name from union type definition *)
let extract_instruction_name = function
  | TU_aux (TU_ty_id (typ, id), _) -> string_of_id id
  | _ -> "unknown_instr"

(* Generate CGEN instruction definition *)
let generate_cgen_instruction out_channel instr_name params =
  output_string out_channel ("(define-insn " ^ String.lowercase_ascii instr_name ^ "\n");
  output_string out_channel ("  (name \"" ^ instr_name ^ "\")\n");
  output_string out_channel ("  (comment \"" ^ instr_name ^ " instruction\")\n");
  output_string out_channel ("  (attrs all-isas all-machs)\n");
  output_string out_channel ("  (syntax \"" ^ String.lowercase_ascii instr_name);

  (* Generate syntax parameters *)
  let rec generate_syntax_params i = function
    | [] -> ()
    | _ :: rest ->
        output_string out_channel (" $param" ^ string_of_int i);
        generate_syntax_params (i + 1) rest
  in
  generate_syntax_params 1 params;
  output_string out_channel "\")\n";

  (* Generate format specification (simplified) *)
  output_string out_channel "  (format (+ ";
  let rec generate_format_params i = function
    | [] -> ()
    | _ :: rest ->
        if i > 1 then output_string out_channel " ";
        output_string out_channel ("(f-param" ^ string_of_int i ^ " param" ^ string_of_int i ^ ")");
        generate_format_params (i + 1) rest
  in
  generate_format_params 1 params;
  output_string out_channel "))\n";

  (* Generate semantics placeholder *)
  output_string out_channel "  (semantics\n";
  output_string out_channel "    (sequence ()\n";
  output_string out_channel ("      (comment \"" ^ instr_name ^ " execution semantics\")\n");
  output_string out_channel "    )\n";
  output_string out_channel "  )\n";
  output_string out_channel ")\n\n"

(* Process scattered union type definitions (instruction AST) *)
let process_scattered_union out_channel = function
  | SD_aux (SD_unioncl (id, type_union), _) when string_of_id id = "ast" ->
    let instr_name = extract_instruction_name type_union in
    let params = [] in (* TODO: Extract actual parameters from type_union *)
    generate_cgen_instruction out_channel instr_name params
  | _ -> () (* Skip non-ast union clauses *)

(* Process mapping definitions for instruction encodings *)
let process_mapping_def out_channel (MD_aux (MD_mapping (id, _, clauses), _)) =
  output_string out_channel ("(* Mapping " ^ string_of_id id ^ " with " ^ string_of_int (List.length clauses) ^ " clauses *)\n");
  (* TODO: Process mapping clauses to extract instruction encodings *)
  List.iter (fun _ -> ()) clauses

(* Process function definitions for instruction semantics *)
let process_function_def out_channel = function
  | FD_aux (FD_function (_, _, _, funcls), _) ->
    List.iter (fun funcl ->
      match funcl with
      | FCL_aux (FCL_Funcl (id, _), _) when string_of_id id = "execute" ->
        output_string out_channel ("(* Execute function clause for instruction semantics *)\n")
      | _ -> ()
    ) funcls

(* Process type definitions *)
let process_type_def out_channel = function
  | TD_aux (TD_variant (id, _, _, type_unions, _), _) when string_of_id id = "ast" ->
    output_string out_channel ("(* Instruction AST type definition *)\n");
    List.iter (fun tu ->
      let instr_name = extract_instruction_name tu in
      let params = [] in (* TODO: Extract parameters from type union *)
      generate_cgen_instruction out_channel instr_name params
    ) type_unions
  | TD_aux (TD_abbrev (id, _, _, _), _) ->
    output_string out_channel ("(* Type abbreviation: " ^ string_of_id id ^ " *)\n")
  | _ -> ()

(* Process all definitions in the AST *)
let rec process_definitions out_channel = function
  | [] -> ()
  | (DEF_reg_dec reg) :: defs ->
     process_register_dec out_channel reg;
     process_definitions out_channel defs
  | (DEF_mapdef mapdef) :: defs ->
     process_mapping_def out_channel mapdef;
     process_definitions out_channel defs
  | (DEF_fundef fundef) :: defs ->
     process_function_def out_channel fundef;
     process_definitions out_channel defs
  | (DEF_type typedef) :: defs ->
     process_type_def out_channel typedef;
     process_definitions out_channel defs
  | (DEF_scattered scattered) :: defs ->
     process_scattered_union out_channel scattered;
     process_definitions out_channel defs
  | def :: defs ->
     (* Skip other definition types for now *)
     process_definitions out_channel defs

(* Main function called from sail.ml to generate CGEN file *)
let create_file out_name (Defs defs) =
  let ochannel = open_out out_name in
    try
      (* Write CGEN file header *)
      output_string ochannel ";; CGEN CPU description generated from Sail specification\n";
      output_string ochannel ";; This file contains hardware register and instruction definitions\n\n";

      (* Write hardware section header *)
      output_string ochannel ";; ========================================\n";
      output_string ochannel ";; Hardware Register Definitions\n";
      output_string ochannel ";; ========================================\n\n";

      (* Process all definitions to extract and generate hardware and instructions *)
      process_definitions ochannel defs;

      (* Write instruction section header *)
      output_string ochannel "\n;; ========================================\n";
      output_string ochannel ";; Instruction Definitions\n";
      output_string ochannel ";; ========================================\n\n";

      (* Write footer *)
      output_string ochannel ";; End of generated CGEN file\n";
      close_out ochannel
    with
      exn ->
        close_out ochannel;
        raise exn
