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

(* Process mapping definitions (currently just outputs info) *)
let do_mapdef_registers out_channel (MD_aux (MD_mapping (_, _, clauses), _)) =
  output_string out_channel ("(* Mapping with " ^ string_of_int (List.length clauses) ^ " clauses *)\n")

(* Process all definitions in the AST to extract registers *)
let rec process_definitions out_channel = function
  | [] -> ()
  | (DEF_reg_dec reg) :: defs ->
     process_register_dec out_channel reg;
     process_definitions out_channel defs
  | (DEF_mapdef mapdef) :: defs ->
     do_mapdef_registers out_channel mapdef;
     process_definitions out_channel defs
  | def :: defs ->
     process_definitions out_channel defs

(* Main function called from sail.ml to generate CGEN file *)
let create_file out_name (Defs defs) =
  let ochannel = open_out out_name in
    try
      (* Write CGEN file header *)
      output_string ochannel ";; CGEN CPU description generated from Sail specification\n";
      output_string ochannel ";; This file contains hardware register definitions\n\n";

      (* Process all definitions to extract and generate register hardware *)
      process_definitions ochannel defs;

      (* Write footer *)
      output_string ochannel ";; End of generated CGEN file\n";
      close_out ochannel
    with
      exn ->
        close_out ochannel;
        raise exn
