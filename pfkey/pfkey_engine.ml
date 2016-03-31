
type message = [
  | `Register of Pfkey_wire.satype
]

type spd = { (* our policy type -- maybe directly in ike? *)
  idx : int
}

type sa = { (* our sa type -- maybe directly in ike? *)
  spi : int32 ;
}

type state = {
  spds : spd list ;
  sas : sa list ;
  logger : Logs.src ;
}

let create () = {
  spds = [] ;
  sas = [] ;
  logger = Logs.Src.create "pfkey engine"
}

type error =
  | Failed of string

let pp_error ppf = function
  | Failed s -> Format.fprintf ppf "failed: %s" s

include Monad.Or_error_make (struct type err = error end)
open Result

let handle_data state (msg_type, errno, sa_type, seq, pid) payload =
  let open Pfkey_wire in
  Logs.debug ~src:state.logger
    (fun pp -> pp "handling message %s: errno %d sa_type %s seq %08lX pid %lu"
        (message_type_to_string msg_type) errno (satype_to_string sa_type) seq pid) ;
  return (state, payload)

let handle state buf =
  let open Pfkey_coding in
  match decode_message buf with
  | Ok (payload, data) ->
    handle_data state data payload
  | Error (Unknown x) -> fail (Failed ("unknown " ^ x))
  | Error Underflow -> fail (Failed "underflow")

let send _state _msg =
  assert false
