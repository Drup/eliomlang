open Typedtree
module P = Parsetree
open Ast_helper
open Ppx_core.Std

module U = Untypeast
module AM = Ast_mapper
module AC = Ast_convenience

open El_utils

let get_client_section stri =
  match stri.str_desc with
  | Tstr_value (_, [ {vb_attributes} ]) ->
    get_attr eliom_section_attr vb_attributes
  | _ -> None

let get_client_fragment e =
  match get_attr eliom_fragment_attr e.exp_attributes with
  | Some PStr [{pstr_desc = Pstr_eval (e,_)}] -> Some e
  | Some _ -> Some (exp_error ~loc:e.exp_loc "Eliom ICE")
  | _ -> None



let close_server_section ~loc =
  let e_hash = AC.str @@ string_of_int @@ file_hash loc in
  [%stri
    let () = Eliom_runtime.close_server_section [%e e_hash]
  ][@metaloc loc]

let fragment ~loc id arg =
  [%expr
    Eliom_runtime.fragment
      ~pos:[%e position loc ]
      [%e id]
      [%e arg]
  ][@metaloc loc]


let expr mapper e =
  match get_client_fragment e with
  | None -> U.default_mapper.expr mapper e
  | Some _ -> begin
      let loc = e.exp_loc in
      match e.exp_desc with
      | Texp_apply (_, [Nolabel, Some id ; Nolabel, Some arg]) ->
        let arg = U.default_mapper.expr U.default_mapper arg in
        let id = U.default_mapper.expr U.default_mapper id in
        fragment ~loc id arg
      | _ -> exp_error ~loc "Eliom ICE"
    end

let structure_item mapper stri =
  let loc = stri.str_loc in
  match get_client_section stri with
  | None -> [
      U.default_mapper.structure_item mapper stri  ;
      close_server_section ~loc
    ]
  | Some _stri -> []
