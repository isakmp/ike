open Result

type message = [
  | `Register of Pfkey_wire.satype
]

type t

type error

val pp_error : Format.formatter -> error -> unit

val handle : t -> Cstruct.t -> (t * Cstruct.t, error) result

val send : t -> message -> (t * Cstruct.t)
