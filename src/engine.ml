

type initiator_state =
  | Sa_init_sent of ??
  | Auth_sent of ??
  | Active
  | Closing

type responder_state =
  | Initial
  | Sa_init_replied of ??
  | Auth_replied of ??
  | Active
  | Closing

type state =
  | Initiator of initiator_state
  | Responder of responder_state

let active = function
  | Initiator (Active _) | Responder (Active _) -> true
  | _ -> false

type t = {
  spi : Cstruct.t ;
  message_id : Int32 ;
  machina : state ;
  window_size : int ;
  peer : Ipaddr.t * int ;
  childs : sa list ;
  replies : (int * Cstruct.t) list ;
  requests : (int * Cstruct.t) list ;
  crypto_ctx : ?? option ;
  log : Logs.Src.t ;
}

let initiator config peer =
  ({ machina = Initiator Sa_init_sent ;
     window_size = 1 ;
     peer ;
     childs = [] ;
     replies = [] ;
     requests = [] ;
     crypto_ctx = None },
   Encoder.encode (SA_INIT ???))

let responder config peer =
  { machina = Responder Initial ;
    window_size = 1 ;
    peer ;
    childs = [] ;
    replies = [] ;
    requests = [] ;
    crypto_ctx = None }

let handle_frame t data =
  match t.machina, data with
  | Responder Initial, SA_INIT data ->
  | Responder Sa_init_replied, SA_AUTH data ->
  | Initiator Sa_init_sent, SA_INIT data ->
  | Initiator Auth_sen, SA_AUTH data ->
  | x, y when active x -> handle_y
  | _ -> Logs.warn ~src:t.logger (fun p -> p "don't know what to do")

let pipeline t data =
  parse data >>= fun (hdr, frames, encrypted) ->
  handle_header t hdr >>= fun t ->
  fold handle_frame t frames >>= fun (t, unenc_out, pfkey) ->
  decrypt t encrypted >>= fun frames ->
  fold handle_enc t frames >>= fun (t, out, pfkey') ->
  let enc_out = encrypt t out in
  (t, assemble t unenc_out enc_out, pfkey@pfkey')


(* initial handshake: SA_INIT; reply; SA_AUTH; reply [done once all received]
     responder might reply with cookie or 'do not like group' (or both, up to 8 messages)
 *)
let recv_data t data =
  match pipeline t data with
  | Ok x -> x
  | Error e ->
    Logs.warn ~src:t.logger (fun p -> p "parse error %s" e) ;
    (t, [], [])
