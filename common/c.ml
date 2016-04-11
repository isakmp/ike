
(* high level types used all over, bottom of dependency *)
open Sexplib.Conv

type satype = [
  | `AH
  | `ESP
] [@@deriving sexp]

type auth_alg = [
  | `SHA256 (* likely hmac *)
  | `SHA384 (* likely hmac *)
  | `SHA512 (* likely hmac *)
] [@@deriving sexp]

type enc_alg = [
  | `DES (* this is 3des *)
  | `AES_CBC
  | `AES_CTR
  | `AES_GCM16 (* pls read https://eprint.iacr.org/2015/477 if you want shorter tags *)
] [@@deriving sexp]

type pfkey_to_kern = [
  | `Flush of satype option
  | `Dump of satype option
  | `Register of satype
  | `Policy_Flush
  | `Policy_Dump
] [@@deriving sexp]

type pfkey_from_kern = [
  | `Flush of satype option
  | `Supported of auth_alg list * (enc_alg * int * int * int) list
  | `Policy_Flush
] [@@deriving sexp]

type error =
  | Failed of string

let pp_error ppf = function
  | Failed s -> Format.fprintf ppf "failed: %s" s

include Monad.Or_error_make (struct type err = error end)
include Result
