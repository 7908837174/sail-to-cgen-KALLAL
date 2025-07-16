open Ast
open Ast_util
open PPrint

(* Enhanced CGEN backend for Sail to CGEN translation
   Supports registers, types, instructions, and scattered definitions *)

(* Describe information required by hardware *)
type hardware = string * string * (string list)

(* Iterator pg90 *)
let rec print_iter out_channel l =
  match l with
    | [] -> ()
    | h::t -> output_string out_channel h;
              print_iter out_channel t

(* Print indices *)
let print_indices out_channel l =
    print_iter out_channel l

(* Prints the define-hardware function *)
let define_hardware out_channel (name, hw_type, indices) =
  output_string out_channel "(define-hardware\n";
  output_string out_channel "  (name h-";
  output_string out_channel name;
  output_string out_channel ")\n";
  output_string out_channel "  (comment ";
  output_string out_channel name;
  output_string out_channel ")\n";
  output_string out_channel "  (attrs all-isas all-machs)\n";
  output_string out_channel "  (type ";
  output_string out_channel hw_type;
  output_string out_channel ")\n";
  match indices with
    | [] -> output_string out_channel ")\n"
    | h::t ->
      output_string out_channel "  (indices ";
      print_indices out_channel indices;
      output_string out_channel ")\n)\n"

(* Generate CGEN instruction format from bitfield type *)
let generate_iformat out_channel id fields =
  output_string out_channel "(define-iformat f-";
  output_string out_channel (string_of_id id);
  output_string out_channel "\n";
  output_string out_channel "  (name \"";
  output_string out_channel (string_of_id id);
  output_string out_channel "\")\n";
  output_string out_channel "  (comment \"";
  output_string out_channel (string_of_id id);
  output_string out_channel " instruction format\")\n";
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

(* Generate CGEN operand type from enum *)
let generate_operand_type out_channel id variants =
  output_string out_channel "(define-operand-type ";
  output_string out_channel (string_of_id id);
  output_string out_channel "\n";
  output_string out_channel "  (name \"";
  output_string out_channel (string_of_id id);
  output_string out_channel "\")\n";
  output_string out_channel "  (comment \"";
  output_string out_channel (string_of_id id);
  output_string out_channel " operand type\")\n";
  output_string out_channel "  (values";
  List.iter (fun variant_id ->
    output_string out_channel " ";
    output_string out_channel (string_of_id variant_id)
  ) variants;
  output_string out_channel ")\n)\n\n"

(* Generate CGEN instruction definition from union variant *)
let generate_instruction out_channel variant_id params =
  output_string out_channel "(define-insn ";
  output_string out_channel (String.lowercase_ascii (string_of_id variant_id));
  output_string out_channel "\n";
  output_string out_channel "  (name \"";
  output_string out_channel (String.lowercase_ascii (string_of_id variant_id));
  output_string out_channel "\")\n";
  output_string out_channel "  (comment \"";
  output_string out_channel (string_of_id variant_id);
  output_string out_channel " instruction\")\n";
  output_string out_channel "  (attrs all-isas all-machs)\n";
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

(* Process mapping definitions *)
let do_mapdef_registers out_channel (MD_aux (MD_mapping (id, _, clauses), _)) =
  output_string out_channel ";; Mapping definition: ";
  output_string out_channel (string_of_id id);
  output_string out_channel "\n";
  output_string out_channel ";; Clauses: ";
  output_string out_channel (string_of_int (List.length clauses));
  output_string out_channel "\n";
  let hardware = (string_of_id id, "mapping", []) in
  define_hardware out_channel hardware

(* Process register definitions *)
let process_register out_channel (DEC_aux (dec_aux, _)) =
  match dec_aux with
  | DEC_reg (typ, id) ->
     let reg_name = string_of_id id in
     let hardware = (reg_name, "register", []) in
     define_hardware out_channel hardware
  | DEC_config (id, typ, exp) ->
     let reg_name = string_of_id id in
     let hardware = (reg_name, "configuration", []) in
     define_hardware out_channel hardware
  | DEC_alias (id, exp) ->
     let reg_name = string_of_id id in
     let hardware = (reg_name, "alias", []) in
     define_hardware out_channel hardware
  | DEC_typ_alias (typ, id, exp) ->
     let reg_name = string_of_id id in
     let hardware = (reg_name, "typed_alias", []) in
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
     let hardware = (string_of_id id, "record", []) in
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
