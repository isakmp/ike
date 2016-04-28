open C

open Pfkey_coding

type ready_or_not = Waiting | Ready

type state = {
  machina : ready_or_not ;
  logger : Logs.src ;
  pid : int32 ;
  sequence : int32 ;
  commands : pfkey_to_kern list
}

let sa_to_satype =
  let open Pfkey_wire in
  function
  | `ESP -> ESP
  | `AH -> AH

let encode s cmd =
  let open Pfkey_wire in
  let null = Cstruct.create 0 in
  let typ, errno, satyp, payload = match cmd with
    | `Register satype -> (REGISTER, 0, sa_to_satype satype, null)
    | `Dump satype ->
      let satype = Utils.option UNSPEC sa_to_satype satype in
      (DUMP, 0, satype, null)
    | `Flush satype ->
      let satype = Utils.option UNSPEC sa_to_satype satype in
      (FLUSH, 0, satype, null)
    | `Policy_Dump -> (SPDDUMP, 0, UNSPEC, null)
    | `Policy_Flush -> (SPDFLUSH, 0, UNSPEC, null)
  and seq = s.sequence
  and pid = s.pid
  in
  let hdr = { Pfkey_coding.typ ; errno ; satyp ; seq ; pid } in
  let cs = Pfkey_coding.Encode.header hdr payload in
  Logs.debug ~src:s.logger
    (fun pp -> pp "encoded message %s" (Sexplib.Sexp.to_string_hum (Pfkey_coding.sexp_of_header hdr))) ;
  ({ s with sequence = Int32.succ seq }, cs)

let maybe_command s =
  Logs.debug ~src:s.logger
    (fun pp -> pp "%d comamnds in queue, state %s" (List.length s.commands)
        (match s.machina with Waiting -> "waiting" | Ready -> "ready")) ;
  match s.machina, s.commands with
  | Ready, c::commands ->
    let s, cs = encode s c in
    ({ s with machina = Waiting ; commands }, Some cs)
  | Ready, [] -> (s, None)
  | Waiting, commands -> ({ s with commands }, None)

let enqueue s cmd = { s with commands = s.commands @ [cmd] }

let create ?(pid = 42l) ?(commands = []) () =
  let s = {
    pid ;
    sequence = 0l ;
    logger = Logs.Src.create "pfkey engine" ;
    commands ;
    machina = Ready
  }
  in
  maybe_command s

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
        let auth, enc = List.fold_left (fun (a, es) -> function
            | Auth (id, _, _) -> (id :: a, es)
            | Enc (id, iv, min, max) -> (a, (id, iv, min, max) :: es))
            ([], [])
            algs
        in
        (a @ Utils.filter_map aalg_to_auth auth,
         e @ Utils.filter_map ealg_to_enc enc)
      | _ -> (a, e))
    ([], [])
    exts
  in
  if List.length a = 0 && List.length e = 0 then
    fail (Failed "no supported algorithms")
  else if List.exists (function Supported _ -> false | _ -> true) exts then
    fail (Failed "invalid register message")
  else
    return (`Supported (a, e))

let maybe_sa hdr =
  let open Pfkey_wire in
  match hdr.satyp with
  | UNSPEC -> None
  | AH -> Some `AH
  | ESP -> Some `ESP
  | _ -> None (* XXX: maybe log some error? *)

let handle s buf =
  Decode.header buf >>= fun (payload, hdr) ->
  Decode.separate_extensions payload >>= fun exts ->
  mapM (Decode.extension s.logger) exts >>= fun exts ->
  Logs.debug ~src:s.logger
    (fun pp -> pp "handling message %s with %d extensions: %s"
        (Sexplib.Sexp.to_string_hum (sexp_of_header hdr))
        (List.length exts)
        (String.concat ", "
           (List.map Sexplib.Sexp.to_string_hum
              (List.map sexp_of_extension exts)))) ;

  let s =
    if hdr.seq = Int32.pred s.sequence && hdr.pid = s.pid then
      (* this was the outstanding reply *)
      { s with machina = Ready }
    else if hdr.seq = 0l && hdr.pid = s.pid && hdr.typ = Pfkey_wire.SPDDUMP then
      (* FreeBSD-CURRENT replies in interesting ways for SPDDUMP
         (sys/netipsec/key.c:key_spddump:2398-2451):
         - sequence set to number of policies
         - for each policy:
           - decrese sequence number
           - send SPDDUMP with single policy
         --> violating the request <-> response protocol
         --> violating the mapping of pid|seq from request to response
         --> XXX: bug to be reported to FreeBSD people?
         --> thus we're ok with the last SPDDUMP msg (seq=0) to be ready again *)
      { s with machina = Ready }
    else
      (* handle unsolicited messages (such as SPDADD from setkey) *)
      s
  in
  (* need to handle errors here...
     translate errno to msg (again, platform-specific), unix-errno package *)
  (* if hdr.errno <> 0 then *)
  let open Pfkey_wire in
  match hdr.typ with
  | REGISTER -> handle_register exts >|= fun supported -> (s, Some supported)
  | FLUSH -> return (s, Some (`Flush (maybe_sa hdr)))
  | SPDFLUSH -> return (s, Some `Policy_Flush)
  | x ->
    Logs.debug ~src:s.logger
      (fun pp -> pp "not forwarding %s" (Pfkey_wire.message_type_to_string x)) ;
    return (s, None)
