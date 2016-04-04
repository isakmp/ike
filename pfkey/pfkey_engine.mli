open Result

type cmd_to_kern = [
  | `Flush
  | `Register of Pfkey_wire.satype
]

type cmd_from_kern = string

type state

val create : unit -> state

val decode : state -> Cstruct.t -> (state * cmd_from_kern, C.error) result

val encode : state -> cmd_to_kern -> (state * Cstruct.t)
