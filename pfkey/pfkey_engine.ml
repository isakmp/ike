open C

open Pfkey_coding

type cmd_to_kern = [
  | `Flush
  | `Register of Pfkey_wire.satype
]

type cmd_from_kern = string

type state = {
  logger : Logs.src ;
  pid : int32 ;
  sequence : int32 ;
}

let create () = {
  pid = 42l ;
  sequence = 0l ;
  logger = Logs.Src.create "pfkey engine" ;
}

let handle_data state hdr exts =
  let open Pfkey_wire in
  Logs.debug ~src:state.logger
    (fun pp -> pp "handling message %s with %d extensions: %s"
        (Sexplib.Sexp.to_string_hum (sexp_of_header hdr))
        (List.length exts)
        (String.concat ", "
           (List.map Sexplib.Sexp.to_string_hum
              (List.map sexp_of_extension exts)))) ;
  match hdr.typ with
  | REGISTER -> return (state, "bla")
  | _ -> assert false

let decode s buf =
  Decode.header buf >>= fun (payload, hdr) ->
  Decode.separate_extensions payload >>= fun exts ->
  mapM (Decode.extension s.logger) exts >>= fun exts ->
  handle_data s hdr exts

let encode s cmd =
  let open Pfkey_wire in
  let null = Cstruct.create 0 in
  let typ, errno, satyp, payload = match cmd with
    | `Flush -> (FLUSH, 0, UNSPEC, null)
    | `Register satype -> (REGISTER, 0, satype, null)
  and seq = s.sequence
  and pid = s.pid
  in
  let hdr = { Pfkey_coding.typ ; errno ; satyp ; seq ; pid } in
  let cs = Pfkey_coding.Encode.header hdr payload in
  Logs.debug ~src:s.logger
    (fun pp -> pp "encoded message %s" (Sexplib.Sexp.to_string_hum (Pfkey_coding.sexp_of_header hdr))) ;
  ({ s with sequence = Int32.succ seq }, cs)
