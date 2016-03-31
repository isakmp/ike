
type error =
  | Unknown        of string
  | Underflow

val error_of_sexp : Sexplib.Sexp.t -> error
val sexp_of_error : error -> Sexplib.Sexp.t

type 'a result = ('a, error) Result.result

val decode_message : Cstruct.t -> (Cstruct.t * (Pfkey_wire.message_type * int * Pfkey_wire.satype * int32 * int32)) result
