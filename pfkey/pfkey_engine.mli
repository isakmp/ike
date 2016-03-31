open Result

type message = [
  | `Register of Pfkey_wire.satype
]

type state

type error

val pp_error : Format.formatter -> error -> unit

val create : unit -> state

val handle : state -> Cstruct.t -> (state * Cstruct.t, error) result

val send : state -> message -> (state * Cstruct.t)
