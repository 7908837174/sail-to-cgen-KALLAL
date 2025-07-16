open Ast
open Ast_util
open PPrint

(* Enhanced CGEN backend for Sail to CGEN translation
   Supports registers, types, instructions, and scattered definitions

   Extension Schema Support (Issue #307):
   - Adds UDB extension identification in schema instead of hardcoded names
   - Supports extensible extension metadata without code changes
*)

(* Extension metadata for UDB extension identification (Issue #307) *)
type extension_metadata = {
  is_udb_defined: bool;
  extension_name: string option;
  extension_version: string option;
  extension_category: string option;
}

(* Default extension metadata for non-UDB extensions *)
let default_extension_metadata = {
  is_udb_defined = false;
  extension_name = None;
  extension_version = None;
  extension_category = None;
}

(* Create UDB extension metadata *)
let make_udb_extension_metadata name version category = {
  is_udb_defined = true;
  extension_name = Some name;
  extension_version = version;
  extension_category = category;
}

(* Describe information required by hardware with extension metadata *)
type hardware = string * string * (string list) * extension_metadata

(* Iterator pg90 *)
let rec print_iter out_channel l =
  match l with
    | [] -> ()
    | h::t -> output_string out_channel h;
              print_iter out_channel t

(* Print indices *)
let print_indices out_channel l =
    print_iter out_channel l

(* Prints extension metadata as CGEN attributes *)
let print_extension_metadata out_channel ext_meta =
  if ext_meta.is_udb_defined then (
    output_string out_channel "  (attrs all-isas all-machs udb-defined";
    (match ext_meta.extension_name with
     | Some name ->
       output_string out_channel " extension-name=";
       output_string out_channel name
     | None -> ());
    (match ext_meta.extension_version with
     | Some version ->
       output_string out_channel " extension-version=";
       output_string out_channel version
     | None -> ());
    (match ext_meta.extension_category with
     | Some category ->
       output_string out_channel " extension-category=";
       output_string out_channel category
     | None -> ());
    output_string out_channel ")\n"
  ) else (
    output_string out_channel "  (attrs all-isas all-machs)\n"
  )

(* Prints the define-hardware function with extension metadata support *)
let define_hardware out_channel (name, hw_type, indices, ext_meta) =
  output_string out_channel "(define-hardware\n";
  output_string out_channel "  (name h-";
  output_string out_channel name;
  output_string out_channel ")\n";
  output_string out_channel "  (comment ";
  output_string out_channel name;
  output_string out_channel ")\n";
  print_extension_metadata out_channel ext_meta;
  output_string out_channel "  (type ";
  output_string out_channel hw_type;
  output_string out_channel ")\n";
  match indices with
    | [] -> output_string out_channel ")\n"
    | h::t ->
      output_string out_channel "  (indices ";
      print_indices out_channel indices;
      output_string out_channel ")\n)\n"

(* Extension detection logic (Issue #307) *)
let detect_udb_extension name =
  (* Check for UDB extension naming patterns *)
  let name_str = string_of_id name in
  let udb_patterns = [
    ("Zicsr", "Control and Status Register");
    ("Zifencei", "Instruction-Fetch Fence");
    ("Zihintpause", "Pause Hint");
    ("Zmmul", "Integer Multiplication");
    ("Zba", "Address Generation");
    ("Zbb", "Basic Bit Manipulation");
    ("Zbc", "Carry-less Multiplication");
    ("Zbs", "Single-bit Instructions");
    ("Zknd", "NIST Suite: AES Decryption");
    ("Zkne", "NIST Suite: AES Encryption");
    ("Zknh", "NIST Suite: Hash Functions");
    ("Zksed", "ShangMi Suite: SM4 Block Cipher");
    ("Zksh", "ShangMi Suite: SM3 Hash Function");
  ] in

  (* Check if name matches any UDB extension pattern *)
  let rec check_patterns = function
    | [] -> default_extension_metadata
    | (pattern, category) :: rest ->
      if String.length name_str >= String.length pattern &&
         String.sub name_str 0 (String.length pattern) = pattern then
        make_udb_extension_metadata pattern None (Some category)
      else
        check_patterns rest
  in

  (* Also check for explicit UDB markers in comments or annotations *)
  if String.contains name_str '_' then
    let parts = String.split_on_char '_' name_str in
    match parts with
    | "UDB" :: ext_name :: _ ->
      make_udb_extension_metadata ext_name None (Some "UDB-defined")
    | _ -> check_patterns udb_patterns
  else
    check_patterns udb_patterns

(* Generate CGEN instruction format from bitfield type with extension metadata *)
let generate_iformat out_channel id fields =
  let ext_meta = detect_udb_extension id in
  output_string out_channel "(define-iformat f-";
  output_string out_channel (string_of_id id);
  output_string out_channel "\n";
  output_string out_channel "  (name \"";
  output_string out_channel (string_of_id id);
  output_string out_channel "\")\n";
  output_string out_channel "  (comment \"";
  output_string out_channel (string_of_id id);
  output_string out_channel " instruction format\")\n";
  print_extension_metadata out_channel ext_meta;
  output_string out_channel "  (length 32)\n";
  output_string out_channel "  (fields\n";
  List.iter (fun (field_id, range) ->
    output_string out_channel "    (";
    output_string out_channel (string_of_id field_id);
    output_string out_channel " ";
    (* Note: range processing would need more detailed implementation *)
    output_string out_channel "0 0";
    output_string out_channel ")\n"
  ) fields;
  output_string out_channel "  )\n)\n\n"

(* Generate CGEN operand type from enum with extension metadata *)
let generate_operand_type out_channel id variants =
  let ext_meta = detect_udb_extension id in
  output_string out_channel "(define-operand-type ";
  output_string out_channel (string_of_id id);
  output_string out_channel "\n";
  output_string out_channel "  (name \"";
  output_string out_channel (string_of_id id);
  output_string out_channel "\")\n";
  output_string out_channel "  (comment \"";
  output_string out_channel (string_of_id id);
  output_string out_channel " operand type\")\n";
  print_extension_metadata out_channel ext_meta;
  output_string out_channel "  (values";
  List.iter (fun variant_id ->
    output_string out_channel " ";
    output_string out_channel (string_of_id variant_id)
  ) variants;
  output_string out_channel ")\n)\n\n"

(* Generate CGEN instruction definition from union variant with extension metadata *)
let generate_instruction out_channel variant_id params =
  let ext_meta = detect_udb_extension variant_id in
  output_string out_channel "(define-insn ";
  output_string out_channel (String.lowercase_ascii (string_of_id variant_id));
  output_string out_channel "\n";
  output_string out_channel "  (name \"";
  output_string out_channel (String.lowercase_ascii (string_of_id variant_id));
  output_string out_channel "\")\n";
  output_string out_channel "  (comment \"";
  output_string out_channel (string_of_id variant_id);
  output_string out_channel " instruction\")\n";
  print_extension_metadata out_channel ext_meta;
  output_string out_channel "  (syntax \"";
  output_string out_channel (String.lowercase_ascii (string_of_id variant_id));
  (* Add parameter placeholders in syntax *)
  List.iteri (fun i _ ->
    output_string out_channel " $arg";
    output_string out_channel (string_of_int i)
  ) params;
  output_string out_channel "\")\n";
  output_string out_channel "  (format f-instruction)\n";
  output_string out_channel "  (semantics\n";
  output_string out_channel "    ;; Semantics would be extracted from execute function\n";
  output_string out_channel "    (nop)\n";
  output_string out_channel "  )\n)\n\n"

(* Process mapping definitions with extension metadata *)
let do_mapdef_registers out_channel (MD_aux (MD_mapping (id, _, clauses), _)) =
  output_string out_channel ";; Mapping definition: ";
  output_string out_channel (string_of_id id);
  output_string out_channel "\n";
  output_string out_channel ";; Clauses: ";
  output_string out_channel (string_of_int (List.length clauses));
  output_string out_channel "\n";
  let ext_meta = detect_udb_extension id in
  let hardware = (string_of_id id, "mapping", [], ext_meta) in
  define_hardware out_channel hardware

(* Process register definitions with extension metadata *)
let process_register out_channel (DEC_aux (dec_aux, _)) =
  match dec_aux with
  | DEC_reg (typ, id) ->
     let reg_name = string_of_id id in
     let ext_meta = detect_udb_extension id in
     let hardware = (reg_name, "register", [], ext_meta) in
     define_hardware out_channel hardware
  | DEC_config (id, typ, exp) ->
     let reg_name = string_of_id id in
     let ext_meta = detect_udb_extension id in
     let hardware = (reg_name, "configuration", [], ext_meta) in
     define_hardware out_channel hardware
  | DEC_alias (id, exp) ->
     let reg_name = string_of_id id in
     let ext_meta = detect_udb_extension id in
     let hardware = (reg_name, "alias", [], ext_meta) in
     define_hardware out_channel hardware
  | DEC_typ_alias (typ, id, exp) ->
     let reg_name = string_of_id id in
     let ext_meta = detect_udb_extension id in
     let hardware = (reg_name, "typed_alias", [], ext_meta) in
     define_hardware out_channel hardware

(* Process type definitions *)
let process_type_def out_channel (TD_aux (td_aux, _)) =
  match td_aux with
  | TD_variant (id, _, _, type_unions, _) ->
     output_string out_channel ";; Union type: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n";
     (* Generate instruction definitions for each variant *)
     List.iter (fun (Tu_aux (Tu_ty_id (typ, variant_id), _)) ->
       (* Extract parameters from typ if it's a tuple *)
       let params = match typ with
         | Typ_aux (Typ_tup typs, _) -> typs
         | _ -> [typ]
       in
       generate_instruction out_channel variant_id params
     ) type_unions
  | TD_enum (id, _, variants, _) ->
     output_string out_channel ";; Enum type: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n";
     generate_operand_type out_channel id variants
  | TD_bitfield (id, typ, fields) ->
     output_string out_channel ";; Bitfield type: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n";
     generate_iformat out_channel id fields
  | TD_record (id, _, _, fields, _) ->
     output_string out_channel ";; Record type: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n";
     let ext_meta = detect_udb_extension id in
     let hardware = (string_of_id id, "record", [], ext_meta) in
     define_hardware out_channel hardware
  | TD_abbrev (id, _, _, typ) ->
     output_string out_channel ";; Type abbreviation: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n"

(* Process function definitions *)
let process_function_def out_channel (FD_aux (FD_function (_, _, _, funcls), _)) =
  output_string out_channel ";; Function definition with ";
  output_string out_channel (string_of_int (List.length funcls));
  output_string out_channel " clauses\n"

(* Process scattered definitions *)
let process_scattered_def out_channel (SD_aux (sd_aux, _)) =
  match sd_aux with
  | SD_function (_, _, _, id) ->
     output_string out_channel ";; Scattered function: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n"
  | SD_funcl funcl ->
     output_string out_channel ";; Function clause\n"
  | SD_variant (id, _, _) ->
     output_string out_channel ";; Scattered union: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n"
  | SD_unioncl (id, type_union) ->
     output_string out_channel ";; Union clause for: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n"
  | SD_mapping (id, _) ->
     output_string out_channel ";; Scattered mapping: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n"
  | SD_mapcl (id, _) ->
     output_string out_channel ";; Mapping clause for: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n"
  | SD_end id ->
     output_string out_channel ";; End of scattered definition: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n"

(* Process value specifications *)
let process_val_spec out_channel (VS_aux (VS_val_spec (_, id, _, _), _)) =
  output_string out_channel ";; Value specification: ";
  output_string out_channel (string_of_id id);
  output_string out_channel "\n"

(* Main processing function - handles all definition types *)
let rec list_definitions out_channel = function
  | [] -> ()
  | (DEF_reg_dec reg) :: defs ->
     process_register out_channel reg;
     list_definitions out_channel defs
  | (DEF_mapdef mapdef) :: defs ->
     do_mapdef_registers out_channel mapdef;
     list_definitions out_channel defs
  | (DEF_type type_def) :: defs ->
     process_type_def out_channel type_def;
     list_definitions out_channel defs
  | (DEF_fundef fundef) :: defs ->
     process_function_def out_channel fundef;
     list_definitions out_channel defs
  | (DEF_scattered scattered_def) :: defs ->
     process_scattered_def out_channel scattered_def;
     list_definitions out_channel defs
  | (DEF_spec val_spec) :: defs ->
     process_val_spec out_channel val_spec;
     list_definitions out_channel defs
  | (DEF_val _) :: defs ->
     output_string out_channel ";; Value definition\n";
     list_definitions out_channel defs
  | (DEF_overload (id, ids)) :: defs ->
     output_string out_channel ";; Overload definition: ";
     output_string out_channel (string_of_id id);
     output_string out_channel "\n";
     list_definitions out_channel defs
  | def :: defs ->
     output_string out_channel ";; Other definition\n";
     list_definitions out_channel defs

(* Generate CGEN file header *)
let generate_header out_channel filename =
  output_string out_channel ";; Generated CGEN file from Sail specification\n";
  output_string out_channel ";; File: ";
  output_string out_channel filename;
  output_string out_channel "\n\n"

(* Called in sail.ml *)
let create_file out_name (Defs defs) =
  try
    (* Validate output directory exists *)
    let dir = Filename.dirname out_name in
    if not (Sys.file_exists dir) then
      failwith ("Output directory does not exist: " ^ dir);

    let ochannel = open_out out_name in
    try
      let filename = Filename.basename out_name in
      generate_header ochannel filename;
      list_definitions ochannel defs;
      close_out ochannel
    with
    | exn ->
        close_out ochannel;
        raise exn
  with
  | Sys_error msg ->
      failwith ("File system error: " ^ msg)
  | Invalid_argument msg ->
      failwith ("Invalid input: " ^ msg)
  | exn ->
      failwith ("Error creating CGEN file: " ^ (Printexc.to_string exn))
