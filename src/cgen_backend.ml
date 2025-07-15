open Ast
open Ast_util
open PPrint

(* out_name = "/home/mary/Documents/SAIL/riscv.cpu"
   Useful files: riscv_insts_base.sail : instruction definitions
   riscv_types.sail      : registers *)

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

let do_mapdef_registers out_channel (MD_aux (MD_mapping (id, tannot_opt, clauses), _)) =
  let mapping_name = string_of_id id in
  output_string out_channel ";; Mapping definition: ";
  output_string out_channel mapping_name;
  output_string out_channel "\n";
  output_string out_channel ";; Clauses: ";
  output_string out_channel (string_of_int (List.length clauses));
  output_string out_channel "\n";
  (* Generate actual CGEN mapping construct *)
  let hardware = (mapping_name, "mapping", []) in
  define_hardware out_channel hardware

(* Removed hardcoded print_hardware function - now using actual AST processing *)

let rec list_registers out_channel = function
  | [] -> ()
  | (DEF_reg_dec reg) :: defs ->
     process_register out_channel reg;
     list_registers out_channel defs
  | (DEF_mapdef mapdef) :: defs ->
     do_mapdef_registers out_channel mapdef;
     list_registers out_channel defs
  | def :: defs ->
     list_registers out_channel defs

and process_register out_channel (DEC_aux (dec_aux, _)) =
  match dec_aux with
  | DEC_reg (typ, id) ->
     let reg_name = string_of_id id in
     let reg_type = "register" in (* Could be enhanced to extract actual type info *)
     let hardware = (reg_name, reg_type, []) in
     define_hardware out_channel hardware
  | DEC_config (id, typ, exp) ->
     let reg_name = string_of_id id in
     let reg_type = "configuration" in
     let hardware = (reg_name, reg_type, []) in
     define_hardware out_channel hardware
  | _ -> () (* Handle other declaration types if needed *)

(* Called in sail.ml *)
let create_file out_name (Defs defs) =
  try
    (* Validate output directory exists *)
    let dir = Filename.dirname out_name in
    if not (Sys.file_exists dir) then
      failwith ("Output directory does not exist: " ^ dir);

    let ochannel = open_out out_name in
    try
      (* Generate CGEN header comment *)
      output_string ochannel ";; Generated CGEN file from Sail specification\n";
      output_string ochannel ";; File: ";
      output_string ochannel out_name;
      output_string ochannel "\n\n";

      (* Process actual definitions from AST *)
      list_registers ochannel defs;
      close_out ochannel
    with
    | exn ->
        close_out ochannel;
        raise exn
  with
  | Sys_error msg ->
      failwith ("File system error: " ^ msg)
  | exn ->
      failwith ("Error creating CGEN file: " ^ (Printexc.to_string exn))
