open Result

type state

val create : ?process:int32 -> ?commands:C.pfkey_to_kern list -> unit -> state * Cstruct.t option

val enqueue : state -> C.pfkey_to_kern -> state

val maybe_command : state -> state * Cstruct.t option

val handle : state -> Cstruct.t -> (state * C.pfkey_from_kern option, C.error) result

