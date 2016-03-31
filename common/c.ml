
(* high level types used all over, bottom of dependency *)

type version =
  | IKE_V2

type message =
  | Authentication(* of authentication *)
  | Certificate (* of certificate list *)
  | CertificateRequest (* of ??*)
  | Configuration
  | Delete

type spd = { (* our policy type -- maybe directly in ike? *)
  idx : int
}

type sa = { (* our sa type -- maybe directly in ike? *)
  spi : int32 ;
}

type error =
  | Failed of string

let pp_error ppf = function
  | Failed s -> Format.fprintf ppf "failed: %s" s

include Monad.Or_error_make (struct type err = error end)
include Result
