open C
open Pfkey_wire

open Sexplib.Conv

type header = {
  typ : message_type ;
  errno : int ;
  satyp : satype ;
  seq : int32 ;
  pid : int32 ;
} [@@deriving sexp]

type alg =
  | Auth of aalg * int * int
  | Enc of ealg * int * int * int
  [@@deriving sexp]

type extension =
  | Supported of alg list
  | Policy of Pfkey_wire.policy_type * Pfkey_wire.direction * int32 * int32
  | Source of int * int * int * Ipaddr.t
  | Destination of int * int * int * Ipaddr.t
  [@@deriving sexp]

module Decode = struct
  type 'a result = ('a, C.error) Result.result

  let catch f x =
    try f x with
    | Invalid_argument _ -> fail (Failed "underflow")

  let unknown fmt arg = Failed (Printf.sprintf fmt arg)

  let check_len should buf =
    let is = Cstruct.len buf
    and should = should * 8
    in
    guard (is = should)
      (Failed (Printf.sprintf "length: claimed %d real %d" should is))

  let separate_extensions = catch @@ fun buf ->
    let rec one acc cs =
      if Cstruct.len cs > 0 then
        let len = get_ext_len cs in
        let t, xs = Cstruct.split cs (len * 8) in
        one (t::acc) xs
      else
        List.rev acc
    in
    return (one [] buf)

  let alg buf =
    let id = get_alg_id buf
    and ivlen = get_alg_ivlen buf
    and minbits = get_alg_minbits buf
    and maxbits = get_alg_maxbits buf
    in
    (id, ivlen, minbits, maxbits)

  let algs buf =
    let rec go acc cs =
      if Cstruct.len cs > 0 then
        let this, rest = Cstruct.split cs sizeof_alg in
        go (alg this :: acc) rest
      else
        List.rev acc
    in
    let algs = Cstruct.shift buf sizeof_supported in
    if Cstruct.len algs mod sizeof_alg <> 0 then
      fail (unknown "algorithm extensions size is wrong (%d)" (Cstruct.len algs))
    else
      return (go [] algs)

  let support_enc src buf =
    algs buf >|= fun algs ->
    Supported (Utils.filter_map ~f:(fun (id, iv, min, max) ->
        match int_to_ealg id with
        | None -> Logs.warn ~src (fun pp -> pp "unkown encryption algorithm %d" id) ; None
        | Some x -> Some (Enc (x, iv, min, max)))
        algs)

  let support_auth src buf =
    algs buf >>= fun algs ->
    foldM (fun acc (id, iv, min, max) ->
        match iv, int_to_aalg id with
        | 0, Some x -> return (Auth (x, min, max) :: acc)
        | x, Some _ -> fail (unknown "IV field in authentication alg not zero %d" x)
        | _ ->
          Logs.warn ~src (fun pp -> pp "unknown authentication algorithm %d" id) ;
          return acc)
      []
      algs >|= fun algs ->
    Supported algs

  let policy _src buf =
    let ptype = get_policy_ptype buf in
    match int_to_policy_type ptype with
    | None -> fail (unknown "policy type %d" ptype)
    | Some ptype ->
      let dir = get_policy_direction buf in
      match int_to_direction dir with
      | None -> fail (unknown "direction %d" dir)
      | Some dir ->
        let id = get_policy_id buf
        and priority = get_policy_priority buf
        in
        return (Policy (ptype, dir, id, priority))

  let address _src buf =
    let proto = get_address_proto buf
    and prefixlen = get_address_prefixlen buf
    in
    (* now there is a struct sockaddr -- might be platform-specific *)
    let sockaddr = Cstruct.shift buf sizeof_address in
    let _sin_len = Cstruct.get_uint8 sockaddr 0
    and family = Cstruct.get_uint8 sockaddr 1
    and port = Cstruct.LE.get_uint16 sockaddr 2
    in
    (* depends on family *)
    (let open Ipaddr in
     let ip = Cstruct.(to_string @@ shift sockaddr 4) in
     match family with
     | 2 (* AF_INET *) -> return (V4 (V4.of_bytes_raw ip 0))
     | 28 (* AF_INET6 *) -> return (V6 (V6.of_bytes_raw ip 4)) (* there's a uint32_t flowinfo *)
     | x -> fail (unknown "address family %d" x)) >|= fun address ->
    (proto, prefixlen, port, address)

  let extension src = catch @@ fun buf ->
    let typ = get_ext_ext_type buf in
    match int_to_extension_type typ with
    | None -> fail (unknown "extension type %d" typ)
    | Some typ ->
      match typ with
      | SUPPORTED_ENCRYPT -> support_enc src buf
      | SUPPORTED_AUTH -> support_auth src buf
      | POLICY -> policy src buf
      | ADDRESS_SRC ->
        address src buf >|= fun (proto, pflen, port, address) ->
        Source (proto, pflen, port, address)
      | ADDRESS_DST ->
        address src buf >|= fun (proto, pflen, port, address) ->
        Destination (proto, pflen, port, address)
      | x ->
        Logs.debug ~src (fun pp -> pp "buffer is %a" Utils.pp_cs buf) ;
        fail (unknown "NYI extension type %s" (extension_type_to_string x))

  let header_exn buf =
    let version = get_message_version buf in
    guard (version = 2) (unknown "version %d" version) >>= fun () ->
    let msg_type = get_message_msg_type buf in
    match int_to_message_type msg_type with
    | None -> fail (unknown "message type %d" msg_type)
    | Some typ ->
      let errno = get_message_errno buf in
      let satype = get_message_satype buf in
      match int_to_satype satype with
      | None -> fail (unknown "satype %d" satype)
      | Some satyp ->
        let len = get_message_len buf in
        check_len len buf >>= fun () ->
        let seq = get_message_seq buf in
        let pid = get_message_pid buf in
        return (Cstruct.sub buf sizeof_message ((len - 2) * 8),
                { typ ; errno ; satyp ; seq ; pid })

  let header = catch @@ header_exn

end

module Encode = struct

  let header hdr payload =
    let buf = Cstruct.create sizeof_message in
    set_message_version buf 2 ;
    set_message_msg_type buf (message_type_to_int hdr.typ) ;
    set_message_errno buf hdr.errno ;
    set_message_satype buf (satype_to_int hdr.satyp) ;
    set_message_len buf ((Cstruct.len payload + sizeof_message) / 8) ;
    set_message_reserved buf 0 ;
    set_message_seq buf hdr.seq ;
    set_message_pid buf hdr.pid ;
    Cstruct.append buf payload

end
