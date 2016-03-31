open Result

type pfkey_message = [
  | `Register of Pfkey_wire.satype
]

type state

val create : unit -> state

val handle : state -> Cstruct.t -> (state * Cstruct.t, C.error) result

val send : state -> pfkey_message -> (state * Cstruct.t)
