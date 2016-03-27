
(* configuration stuff, both sides share the same datatype *)

type t = {
  supported_versions : version list ;
  enc : cipher list ;
  policies : ?? ;
  selectors : ?? ;
  peers : ?? ;
}

val parse : data -> t
