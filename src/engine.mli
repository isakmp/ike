
(* the main engine *)

type state

(* failures, to be shown to us *)
type failure = [
  | `InvalidFoo
  | `InvalidBar
]

val pp_failure : Format.formatter * failure -> unit

type sad_change

type ret = [
  | `Ok of state * sad_change list * Cstruct.t list
  | `Fail of sad_change list

val active_pads : Config.t -> peer_auth list

val initiator : Config.t -> peer_auth -> state * (Ipaddr.t * int)
val responder : Config.t -> state

(* main handler for incoming bytes *)
val handle_ike : state -> addr -> Cstruct.t ->
  [ ret | `InitialContact of state * peer_auth * out list ]

val handle_initial_contact : state -> peer_auth ->
  [ `Ok of state | `Fail of sad_change list ]

val handle_tick : state -> ret

val spi_matches : state -> Cstruct.t -> bool

