open Result

type state

val create : ?pid:int32 -> unit -> state

val decode : state -> Cstruct.t -> (state * C.pfkey_from_kern option, C.error) result

val encode : state -> C.pfkey_to_kern -> (state * Cstruct.t)
