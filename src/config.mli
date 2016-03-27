
(* configuration stuff, both sides share the same datatype *)

type t = {
  supported_versions : version list ;
  enc : cipher list
}

type action =
  | `SPDadd
  | `SPDremove
  | ...

val decode : Cstruct.t -> action error
