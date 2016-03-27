
(* IKEv2 LWT interface

communication channels:
  - kernel: pfkey(v2) - RFC2367 + KAME changes
    startup: register AH + ESP
    update SA, get requested on outgoing packet
    policies also contained
  - user: file descriptor / socket with config (mainly SP)
  - network: UDP port 500 IKEv2 (* later also 4500 *)
  - timer (for retransmission and keepalive) every 500 ms

   all of them are combined into a Lwt_stream.t, which is consumed element-wise
   by the main loop: evaluate Ike.handle, perform received actions (sending
   pfkey and udp), goto 0.
*)

let rec pfkey_socket push socket () =
  Lwt_unix.read socket >>= fun data ->
  push (`Pfkey data) >>= fun () ->
  pfkey_socket push socket ()

let rec user_socket push socket () =
  Lwt_unix.read socket >>= fun data ->
  push (`Config data) >>= fun () ->
  user_socket push socket ()

let rec network_socket push socket () =
  Lwt_unix.recv_from socket >>= fun (data, addr) ->
  push (`Data (data, addr)) >>= fun () ->
  network_socket push socket ()

let rec tick push () =
  Lwt_unix.sleep 0.5 >>= fun () ->
  push `Tick >>= fun () ->
  tick push ()

let service user port =
  (* XXX: log reporters need to be installed here as well
    (upon request (e.g. new IKE session))! *)
  let stream, push = Lwt_stream.create () in
  Lwt_unix.socket PF_KEY SOCK_RAW PF_KEY_V2 >>= fun pfkey ->
  Lwt_unix.socket PF_INET SOCK_RAW user >>= fun user ->
  Lwt_unix.socket PF_INET SOCK_DGRAM port >>= fun network ->
  Lwt.async (pfkey_socket push pfkey) ;
  Lwt.async (user_socket push user) ;
  Lwt.async (network_socket push network) ;
  Lwt.async (tick push) ;
  let rec go t =
    Lwt_stream.next stream >>= fun ev ->
    match Ike.Dispatcher.handle ev with
    | Ok (t', `Pfkey pfkey, `Data nout) ->
      Lwt_list.iter_s (Lwt_unix.sendto network) nout >>= fun () ->
      Lwt_unix.send pfkey pfkey >>= fun () ->
      go t'
    | Error str ->
      Printf.printf "failed (with %s) while executing, goodbye" str ;
      Lwt.return_unit
  in
  go (Ike.Dispatcher.create ())
