
(* the main engine *)

type state

(* failures, to be shown to us *)
type failure = [
  | `InvalidFoo
  | `InvalidBar
]

val pp_failure : Format.formatter * failure -> unit

val initiator : Config.t -> (state * Cstruct.t)
val responder : Config.t -> state

type ret = [
  | `Ok of [ `Ok of state | `Eof | `Notify of Packet.error ]
           * [ `Response of Cstruct.t option ]
           * [ `Data of Cstruct.t option ]
           * [ `Retransmission of int option ]
  | `Fail of failure * [ `Response of Cstruct.t ]
]

(* retransmission timers handling *)
val handle_retransmission : state -> ret

(* main handler for incoming bytes *)
val handle_ike : state -> Cstruct.t -> ret

(* do we need a destination (to discover whether to establish a new sa?)? *)
val send_payload : state -> Cstruct.t -> (state * Cstruct.t) option

(* informational data about SA *)
type sa = {
  version : ?? ;
}

val sa : state -> sa list
