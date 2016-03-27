open Return

(* the main engine *)
type t

(* failures, to be shown to us *)
type failure = [
  | `InvalidFoo
  | `InvalidBar
]

val pp_failure : Format.formatter * failure -> unit

type sad_change

type ret =
  (t * sad_change list * Cstruct.t list,
   sad_change list) return

val active_pads : Config.t -> peer_auth list

val initiator : Config.t -> peer_auth -> t * (Ipaddr.t * int)
val responder : Config.t -> t

(* main handler for incoming bytes *)
val handle_ike : t -> addr -> Cstruct.t ->
  [ ret | `InitialContact of t * peer_auth * out list ]

val handle_initial_contact : t -> peer_auth ->
  [ `Ok of t | `Fail of sad_change list ]

val handle_tick : t -> ret

val spi_matches : t -> Cstruct.t -> bool

