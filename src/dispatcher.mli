
(* The dispatcher receives an event and a `t`, and distributes the
   event to interested IKE sessions (Engine.t).  It is the main
   entry point for a side-effecting speaker. *)

type t

val handle : t ->
  [ `Pfkey of Cstruct.t | `Config of Cstruct.t | `Data of (Cstruct.t, addr) | `Tick ] ->
  (t * [ `Pfkey of Cstruct.t list ] * [ `Data of (Cstruct.t, addr) list ],
   string ) Result.result

val create : unit -> t
