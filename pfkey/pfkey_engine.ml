open C

open Pfkey_coding

type state = {
  logger : Logs.src ;
  pid : int32 ;
  sequence : int32 ;
}

let create ?(pid = 42l) () = {
  pid ;
  sequence = 0l ;
  logger = Logs.Src.create "pfkey engine" ;
}

let aalg_to_auth =
  let open Pfkey_wire in
  function
  | AALG_SHA2_256 -> Some `SHA256
  | AALG_SHA2_384 -> Some `SHA384
  | AALG_SHA2_512 -> Some `SHA512
  | _ -> None

let ealg_to_enc (id, iv, min, max) =
  Utils.option
    None
    (fun id -> Some (id, iv, min, max))
    (let open Pfkey_wire in
     match id with
     | EALG_3DESCBC -> Some `DES
     | EALG_AESCBC -> Some `AES_CBC
     | EALG_AESCTR -> Some `AES_CTR
     | EALG_AESGCM16 -> Some `AES_GCM16
     | _ -> None)

let handle_register exts =
  let a, e = List.fold_left (fun (a, e) -> function
      | Supported algs ->
        let auth, enc = List.partition (function Auth _ -> true | Enc _ -> false) algs
        and f = function
          | Auth (id, _, _) -> id
          | Enc _ -> assert false
        and g = function
          | Enc (id, iv, min, max) -> (id, iv, min, max)
          | Auth _ -> assert false
        in
        (a @ Utils.filter_map aalg_to_auth (List.map f auth),
         e @ Utils.filter_map ealg_to_enc (List.map g enc)))
    ([], [])
    exts
  in
  `Supported (a, e)


let decode s buf =
  Decode.header buf >>= fun (payload, hdr) ->
  (* validate that sequence is good (either a reply to our request, or a new message from the kernel [or pid X]) *)
  Decode.separate_extensions payload >>= fun exts ->
  mapM (Decode.extension s.logger) exts >>= fun exts ->
  Logs.debug ~src:s.logger
    (fun pp -> pp "handling message %s with %d extensions: %s"
        (Sexplib.Sexp.to_string_hum (sexp_of_header hdr))
        (List.length exts)
        (String.concat ", "
           (List.map Sexplib.Sexp.to_string_hum
              (List.map sexp_of_extension exts)))) ;
  (* handle unsolicited requests and responses which are not in serial number *)
  let open Pfkey_wire in
  match hdr.typ with
  | REGISTER -> return (s, Some (handle_register exts))
  | FLUSH -> return (s, Some `Flush)
  | SPDFLUSH -> return (s, Some `SPD_Flush)
  | _ -> assert false

let sa_to_satype =
  let open Pfkey_wire in
  function
  | `ESP -> ESP
  | `AH -> AH

(*
let satype_to_sa = function
  | Pfkey_wire.ESP -> `ESP
  | Pfkey_wire.AH -> `AH
*)

let encode s cmd =
  let open Pfkey_wire in
  let null = Cstruct.create 0 in
  let typ, errno, satyp, payload = match cmd with
    | `Flush -> (FLUSH, 0, UNSPEC, null)
    | `SPD_Flush -> (SPDFLUSH, 0, UNSPEC, null)
    | `Register satype -> (REGISTER, 0, sa_to_satype satype, null)
  and seq = s.sequence
  and pid = s.pid
  in
  let hdr = { Pfkey_coding.typ ; errno ; satyp ; seq ; pid } in
  let cs = Pfkey_coding.Encode.header hdr payload in
  Logs.debug ~src:s.logger
    (fun pp -> pp "encoded message %s" (Sexplib.Sexp.to_string_hum (Pfkey_coding.sexp_of_header hdr))) ;
  ({ s with sequence = Int32.succ seq }, cs)
