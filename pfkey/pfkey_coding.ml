
open Sexplib.Conv

type error =
  | Unknown        of string
  | Underflow
  [@@deriving sexp]

include Monad.Or_error_make (struct type err = error end)
type 'a result = ('a, error) Result.result

let catch f x =
  try f x with
  | Invalid_argument _ -> fail Underflow

open Pfkey_wire

let check_len should buf =
  guard (Cstruct.len buf = should * 8)
    (Unknown (Printf.sprintf "length: claimed %d real %d"
                (should * 8) (Cstruct.len buf)))

let decode_message_exn buf =
  let version = get_message_version buf in
  guard (version = 2) (Unknown (Printf.sprintf "version %d" version)) >>= fun () ->
  let msg_type = get_message_msg_type buf in
  match int_to_message_type msg_type with
  | None -> fail (Unknown (Printf.sprintf "message type %d" msg_type))
  | Some msg_type ->
    let errno = get_message_errno buf in
    let satype = get_message_satype buf in
    match int_to_satype satype with
    | None -> fail (Unknown (Printf.sprintf "satype %d" satype))
    | Some satype ->
      let len = get_message_len buf in
      check_len len buf >>= fun () ->
      let seq = get_message_seq buf in
      let pid = get_message_pid buf in
      return (Cstruct.sub buf sizeof_message (len * 8 - sizeof_message),
              (msg_type, errno, satype, seq, pid))

let decode_message = catch @@ decode_message_exn
