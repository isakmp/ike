
type t

(* The dispatcher receives an event and a `t`, and distributes the
   event to interested IKE sessions (Engine.t).  It is the main
   entry point for a side-effecting speaker. *)
val handle : t ->
  [ `Pfkey of Cstruct.t | `Control of Cstruct.t | `Data of (Cstruct.t * (Unix.inet_addr * int)) | `Tick ] ->
  (t * [ `Pfkey of Cstruct.t option ] * [ `Data of (Cstruct.t * (Unix.inet_addr * int)) list ],
   C.error ) Result.result

(* creation of a `t`: it will start with an empty list of Engine.t, and emit
   a message to be send to the pfkey socket (REGISTER ESP).  It waits for
   `Config directives which initially add policies *)
val create : unit -> (t * Cstruct.t)
