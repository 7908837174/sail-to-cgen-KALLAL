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

(* Type environment for storing type definitions *)
type type_env = {
  type_aliases: (string * string) list; (* type name -> CGEN type mapping *)
  bit_widths: (string * int) list;      (* type name -> bit width mapping *)
}

let empty_type_env = { type_aliases = []; bit_widths = [] }

(* Add type alias to environment *)
let add_type_alias env name cgen_type bit_width =
  { type_aliases = (name, cgen_type) :: env.type_aliases;
    bit_widths = (name, bit_width) :: env.bit_widths }

(* Look up type in environment *)
let lookup_type_alias env name =
  try Some (List.assoc name env.type_aliases)
  with Not_found -> None

(* Look up bit width in environment *)
let lookup_bit_width env name =
  try Some (List.assoc name env.bit_widths)
  with Not_found -> None

(* Extract parameter information from instruction type definition *)
type param_info = {
  name: string;
  sail_type: string;
  cgen_type: string;
  bit_width: int option;
}

(* Extract instruction name and parameters from union type definition *)
let extract_instruction_info type_env = function
  | Tu_aux (Tu_ty_id (typ, id), _) ->
    let instr_name = string_of_id id in
    let params = extract_parameters_from_type type_env typ in
    (instr_name, params)
  | _ -> ("unknown_instr", [])

(* Extract parameters from a type (handles tuples and single types) *)
and extract_parameters_from_type type_env = function
  | ATyp_aux (ATyp_tup type_list, _) ->
    List.mapi (fun i atyp -> extract_single_parameter type_env i atyp) type_list
  | single_type ->
    [extract_single_parameter type_env 0 single_type]

(* Extract a single parameter from a type *)
and extract_single_parameter type_env index = function
  | ATyp_aux (ATyp_id (Id_aux (Id type_name, _)), _) ->
    let cgen_type = match lookup_type_alias type_env type_name with
      | Some ct -> ct
      | None -> sail_type_name_to_cgen type_name
    in
    let bit_width = lookup_bit_width type_env type_name in
    { name = "param" ^ string_of_int (index + 1);
      sail_type = type_name;
      cgen_type = cgen_type;
      bit_width = bit_width }
  | ATyp_aux (ATyp_app (Id_aux (Id "bits", _), [A_aux (A_nexp (Nexp_aux (Nexp_constant n, _)), _)]), _) ->
    let width = Big_int.to_int n in
    let cgen_type = if width <= 8 then "register QI"
                   else if width <= 16 then "register HI"
                   else if width <= 32 then "register SI"
                   else if width <= 64 then "register DI"
                   else "register TI" in
    { name = "param" ^ string_of_int (index + 1);
      sail_type = "bits(" ^ string_of_int width ^ ")";
      cgen_type = cgen_type;
      bit_width = Some width }
  | _ ->
    { name = "param" ^ string_of_int (index + 1);
      sail_type = "unknown";
      cgen_type = "register SI";
      bit_width = None }

(* Map Sail type names to CGEN types *)
and sail_type_name_to_cgen = function
  | "regbits" -> "register QI"  (* Typically 5 bits for register indices *)
  | "imm12" -> "register HI"    (* 12-bit immediate *)
  | "imm20" -> "register SI"    (* 20-bit immediate *)
  | "shamt" -> "register QI"    (* Shift amount, typically 6 bits *)
  | "csr_addr" -> "register HI" (* CSR address, 12 bits *)
  | name when String.contains name 'i' && String.contains name 'm' -> "register SI" (* Generic immediate *)
  | _ -> "register SI"          (* Default fallback *)

(* Generate CGEN field definitions from parameters *)
let generate_cgen_fields out_channel params =
  let generate_field param =
    let field_name = "f-" ^ param.name in
    let bit_width = match param.bit_width with
      | Some w -> string_of_int w
      | None -> "32" (* default width *)
    in
    output_string out_channel ("(define-ifield " ^ field_name ^ "\n");
    output_string out_channel ("  \"" ^ param.sail_type ^ " field\"\n");
    output_string out_channel ("  () 31 " ^ bit_width ^ ")\n\n")
  in
  List.iter generate_field params

(* Generate CGEN instruction definition with enhanced parameter support *)
let generate_cgen_instruction out_channel instr_name params =
  output_string out_channel ("(define-insn " ^ String.lowercase_ascii instr_name ^ "\n");
  output_string out_channel ("  (name \"" ^ instr_name ^ "\")\n");
  output_string out_channel ("  (comment \"" ^ instr_name ^ " instruction\")\n");
  output_string out_channel ("  (attrs all-isas all-machs)\n");

  (* Generate syntax with proper parameter names *)
  output_string out_channel ("  (syntax \"" ^ String.lowercase_ascii instr_name);
  let generate_syntax_param param =
    output_string out_channel (" $" ^ param.name)
  in
  List.iter generate_syntax_param params;
  output_string out_channel "\")\n";

  (* Generate format specification with field references *)
  output_string out_channel "  (format (+ ";
  let generate_format_param first param =
    if not first then output_string out_channel " ";
    output_string out_channel ("(f-" ^ param.name ^ " " ^ param.name ^ ")")
  in
  let rec generate_format_params first = function
    | [] -> ()
    | param :: rest ->
        generate_format_param first param;
        generate_format_params false rest
  in
  generate_format_params true params;
  output_string out_channel "))\n";

  (* Generate enhanced semantics placeholder *)
  output_string out_channel "  (semantics\n";
  output_string out_channel "    (sequence ()\n";
  if List.length params > 0 then (
    output_string out_channel ("      (comment \"" ^ instr_name ^ " with parameters: ");
    let param_names = List.map (fun p -> p.name ^ ":" ^ p.sail_type) params in
    output_string out_channel (String.concat ", " param_names);
    output_string out_channel "\")\n"
  ) else (
    output_string out_channel ("      (comment \"" ^ instr_name ^ " execution semantics\")\n")
  );
  output_string out_channel "    )\n";
  output_string out_channel "  )\n";
  output_string out_channel ")\n\n"

(* Global type environment - will be populated during processing *)
let global_type_env = ref empty_type_env

(* Process scattered union type definitions (instruction AST) with enhanced parameter extraction *)
let process_scattered_union out_channel = function
  | SD_aux (SD_unioncl (id, type_union), _) when string_of_id id = "ast" ->
    let instr_name, params = extract_instruction_info !global_type_env type_union in
    (* Generate field definitions for this instruction's parameters *)
    generate_cgen_fields out_channel params;
    (* Generate the instruction definition *)
    generate_cgen_instruction out_channel instr_name params
  | _ -> () (* Skip non-ast union clauses *)

(* Bit field information extracted from mappings *)
type bit_field = {
  name: string;
  start_bit: int;
  width: int;
  is_constant: bool;
  constant_value: string option;
}

(* Extract bit fields from mapping pattern expressions *)
let rec extract_bit_fields_from_mpexp current_pos = function
  | MPat_aux (MPat_pat mpat, _) ->
    extract_bit_fields_from_mpat current_pos mpat
  | _ -> ([], 0)

(* Extract bit fields from mapping patterns *)
and extract_bit_fields_from_mpat current_pos = function
  | MP_aux (MP_id (Id_aux (Id name, _)), _) ->
    (* Variable pattern - represents a field *)
    ([{ name = name; start_bit = current_pos; width = 0; is_constant = false; constant_value = None }], 0)
  | MP_aux (MP_typ (MP_aux (MP_id (Id_aux (Id name, _)), _), typ), _) ->
    (* Typed variable pattern *)
    let width = extract_width_from_type typ in
    ([{ name = name; start_bit = current_pos; width = width; is_constant = false; constant_value = None }], width)
  | MP_aux (MP_lit (L_aux (L_bin bits, _)), _) ->
    (* Binary literal pattern - constant field *)
    let width = String.length bits in
    ([{ name = "const"; start_bit = current_pos; width = width; is_constant = true; constant_value = Some ("0b" ^ bits) }], width)
  | MP_aux (MP_lit (L_aux (L_hex hex, _)), _) ->
    (* Hex literal pattern - constant field *)
    let width = String.length hex * 4 in
    ([{ name = "const"; start_bit = current_pos; width = width; is_constant = true; constant_value = Some ("0x" ^ hex) }], width)
  | MP_aux (MP_app (Id_aux (Id "@", _), [left_mpat; right_mpat]), _) ->
    (* Concatenation pattern *)
    let left_fields, left_width = extract_bit_fields_from_mpat current_pos left_mpat in
    let right_fields, right_width = extract_bit_fields_from_mpat (current_pos + left_width) right_mpat in
    (left_fields @ right_fields, left_width + right_width)
  | MP_aux (MP_vector_concat mpats, _) ->
    (* Vector concatenation pattern *)
    let rec process_mpats pos acc_fields acc_width = function
      | [] -> (List.rev acc_fields, acc_width)
      | mpat :: rest ->
        let fields, width = extract_bit_fields_from_mpat pos mpat in
        process_mpats (pos + width) (fields @ acc_fields) (acc_width + width) rest
    in
    process_mpats current_pos [] 0 mpats
  | _ -> ([], 0)

(* Extract bit width from type annotation *)
and extract_width_from_type = function
  | ATyp_aux (ATyp_app (Id_aux (Id "bits", _), [A_aux (A_nexp (Nexp_aux (Nexp_constant n, _)), _)]), _) ->
    Big_int.to_int n
  | ATyp_aux (ATyp_id (Id_aux (Id type_name, _)), _) ->
    (* Look up known type widths *)
    (match type_name with
     | "regbits" -> 5
     | "imm12" -> 12
     | "imm20" -> 20
     | "shamt" -> 6
     | "csr_addr" -> 12
     | _ -> 32) (* default *)
  | _ -> 32 (* default width *)

(* Generate CGEN field definitions from bit fields *)
let generate_bit_field_definitions out_channel bit_fields =
  let generate_field_def field =
    if not field.is_constant then (
      let field_name = "f-" ^ field.name in
      output_string out_channel ("(define-ifield " ^ field_name ^ "\n");
      output_string out_channel ("  \"" ^ field.name ^ " field\"\n");
      output_string out_channel ("  () " ^ string_of_int field.start_bit ^ " " ^ string_of_int field.width ^ ")\n\n")
    )
  in
  List.iter generate_field_def bit_fields

(* Process mapping definitions for instruction encodings with bit field extraction *)
let process_mapping_def out_channel (MD_aux (MD_mapping (id, _, clauses), _)) =
  output_string out_channel ("(* Mapping " ^ string_of_id id ^ " with " ^ string_of_int (List.length clauses) ^ " clauses *)\n");

  (* Process each mapping clause to extract bit field information *)
  let process_clause = function
    | MCL_aux (MCL_bidir (mpexp1, mpexp2), _) ->
      let bit_fields, total_width = extract_bit_fields_from_mpexp 0 mpexp2 in
      if List.length bit_fields > 0 then (
        output_string out_channel ("(* Bit fields for " ^ string_of_id id ^ ": total width " ^ string_of_int total_width ^ " bits *)\n");
        generate_bit_field_definitions out_channel bit_fields
      )
    | _ -> ()
  in
  List.iter process_clause clauses

(* Semantic operation information *)
type semantic_op = {
  operation: string;
  target: string;
  operands: string list;
}

(* Extract semantic operations from expressions (simplified) *)
let rec extract_semantic_operations = function
  | E_aux (E_block exps, _) ->
    List.concat (List.map extract_semantic_operations exps)
  | E_aux (E_app (Id_aux (Id "+", _), [left; right]), _) ->
    let left_ops = extract_expression_operands left in
    let right_ops = extract_expression_operands right in
    [{ operation = "add"; target = ""; operands = left_ops @ right_ops }]
  | E_aux (E_app (Id_aux (Id "=", _), [left; right]), _) ->
    (* Assignment operation *)
    let target = extract_assignment_target left in
    let operands = extract_expression_operands right in
    [{ operation = "set"; target = target; operands = operands }]
  | _ -> []

(* Extract assignment target from left-hand side expression *)
and extract_assignment_target = function
  | E_aux (E_id (Id_aux (Id name, _)), _) -> name
  | E_aux (E_vector_access (E_aux (E_id (Id_aux (Id name, _)), _), _), _) -> name ^ "[index]"
  | _ -> "unknown"

(* Extract operand names from expressions *)
and extract_expression_operands = function
  | E_aux (E_id (Id_aux (Id name, _)), _) -> [name]
  | E_aux (E_vector_access (E_aux (E_id (Id_aux (Id name, _)), _), _), _) -> [name ^ "[index]"]
  | E_aux (E_app (Id_aux (Id op, _), args), _) ->
    List.concat (List.map extract_expression_operands args)
  | E_aux (E_lit _, _) -> ["immediate"]
  | _ -> []

(* Generate CGEN semantics from semantic operations *)
let generate_cgen_semantics out_channel instr_name semantic_ops =
  if List.length semantic_ops > 0 then (
    output_string out_channel "  (semantics\n";
    output_string out_channel "    (sequence ()\n";
    List.iter (fun op ->
      match op.operation with
      | "set" ->
        output_string out_channel ("      (set (reg h-" ^ op.target ^ ") ");
        if List.length op.operands > 1 then
          output_string out_channel ("(add " ^ String.concat " " (List.map (fun o -> "(reg h-" ^ o ^ ")") op.operands) ^ "))")
        else if List.length op.operands = 1 then
          output_string out_channel ("(reg h-" ^ List.hd op.operands ^ ")")
        else
          output_string out_channel "0";
        output_string out_channel ")\n"
      | _ ->
        output_string out_channel ("      (comment \"" ^ op.operation ^ " operation\")\n")
    ) semantic_ops;
    output_string out_channel "    )\n";
    output_string out_channel "  )\n"
  ) else (
    output_string out_channel "  (semantics\n";
    output_string out_channel "    (sequence ()\n";
    output_string out_channel ("      (comment \"" ^ instr_name ^ " execution semantics\")\n");
    output_string out_channel "    )\n";
    output_string out_channel "  )\n"
  )

(* Process function definitions for instruction semantics with enhanced analysis *)
let process_function_def out_channel = function
  | FD_aux (FD_function (_, _, _, funcls), _) ->
    List.iter (fun funcl ->
      match funcl with
      | FCL_aux (FCL_Funcl (id, pexp), _) when string_of_id id = "execute" ->
        output_string out_channel ("(* Execute function clause for instruction semantics *)\n");
        (* Extract semantic operations from the function body *)
        (match pexp with
         | Pat_aux (Pat_exp (pat, exp), _) ->
           let semantic_ops = extract_semantic_operations exp in
           let instr_name = extract_instruction_name_from_pattern pat in
           output_string out_channel ("(* Semantic analysis for " ^ instr_name ^ ": " ^
                                     string_of_int (List.length semantic_ops) ^ " operations *)\n")
         | _ -> ())
      | _ -> ()
    ) funcls

(* Extract instruction name from function pattern *)
and extract_instruction_name_from_pattern = function
  | P_aux (P_app (Id_aux (Id name, _), _), _) -> name
  | P_aux (P_id (Id_aux (Id name, _)), _) -> name
  | _ -> "unknown"

(* Process type definitions and build type environment *)
let process_type_def out_channel = function
  | TD_aux (TD_variant (id, _, _, type_unions, _), _) when string_of_id id = "ast" ->
    output_string out_channel ("(* Instruction AST type definition *)\n");
    List.iter (fun tu ->
      let instr_name, params = extract_instruction_info !global_type_env tu in
      (* Generate field definitions for this instruction's parameters *)
      generate_cgen_fields out_channel params;
      (* Generate the instruction definition *)
      generate_cgen_instruction out_channel instr_name params
    ) type_unions
  | TD_aux (TD_abbrev (id, _, _, atyp), _) ->
    let type_name = string_of_id id in
    output_string out_channel ("(* Type abbreviation: " ^ type_name ^ " *)\n");
    (* Add type alias to global environment *)
    let cgen_type, bit_width = match atyp with
      | ATyp_aux (ATyp_app (Id_aux (Id "bits", _), [A_aux (A_nexp (Nexp_aux (Nexp_constant n, _)), _)]), _) ->
        let width = Big_int.to_int n in
        let ct = if width <= 8 then "register QI"
                else if width <= 16 then "register HI"
                else if width <= 32 then "register SI"
                else if width <= 64 then "register DI"
                else "register TI" in
        (ct, width)
      | _ -> ("register SI", 32)
    in
    global_type_env := add_type_alias !global_type_env type_name cgen_type bit_width
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
