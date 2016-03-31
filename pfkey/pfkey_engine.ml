
type message = [
  | `Register of Pfkey_wire.satype
]

type spd = { (* our policy type -- maybe directly in ike? *)
  idx : int
}

type sa = { (* our sa type -- maybe directly in ike? *)
  spi : int32 ;
}

type t = {
  spds : spd list ;
  sas : sa list ;
}

type error =
  | Failed of string

let pp_error ppf = function
  | Failed s -> Format.fprintf ppf "failed: %s" s

let handle _t _buf =
  assert false

let send _t _msg =
  assert false
