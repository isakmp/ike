
type t

(* The dispatcher receives an event and a `t`, and distributes the
   event to interested IKE sessions (Engine.t).  It is the main
   entry point for a side-effecting speaker. *)
val handle : t ->
  [ `Pfkey of Cstruct.t | `Config of Cstruct.t | `Data of (Cstruct.t, addr) | `Tick ] ->
  (t * [ `Pfkey of Cstruct.t list ] * [ `Data of (Cstruct.t, addr) list ],
   string ) Result.result

(* creation of a `t`: it will start with an empty list of Engine.t, and emit
   some messages to be send to the pfkey socket (FLUSH, REGISTER AH, REGISTER
   ESP).  It waits for `Config directives which initially add policies *)
val create : unit -> (t * Cstruct.t list)
