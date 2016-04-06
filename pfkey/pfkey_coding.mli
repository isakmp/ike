
type header = {
  typ : Pfkey_wire.message_type ;
  errno : int ;
  satyp : Pfkey_wire.satype ;
  seq : int32 ;
  pid : int32 ;
} [@@deriving sexp]

type alg =
  | Auth of Pfkey_wire.aalg * int * int
  | Enc of Pfkey_wire.ealg * int * int * int
  [@@deriving sexp]

type extension =
  | Supported of alg list
  | Policy of Pfkey_wire.policy_type * Pfkey_wire.direction * int32 * int32
  | Source of int * int * int * Ipaddr.t
  | Destination of int * int * int * Ipaddr.t
  [@@deriving sexp]

module Decode : sig
  type 'a result = ('a, C.error) Result.result

  val separate_extensions : Cstruct.t -> (Cstruct.t list) result

  val extension : Logs.Src.t -> Cstruct.t -> extension result

  val header : Cstruct.t -> (Cstruct.t * header) result
end

module Encode : sig

  (*  val extension : extension -> Cstruct.t *)

  val header : header -> Cstruct.t -> Cstruct.t
end
