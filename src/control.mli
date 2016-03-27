
type action =
  | `SPDadd
  | `SPDremove
  | ...

val decode : Cstruct.t -> action error
