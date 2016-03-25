
(* high level types used all over, bottom of dependency *)

type version =
  | IKE_V2

type message =
  | Authentication of authentication
  | Certificate of certificate list
  | CertificateRequest of ??
  | Configuration
  | Delete
