
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

open Lwt.Infix
open Result

(* this reader has the logic to read a single complete pfkey message!
     bytes 5 and 6 (in little endian) encode the length of the message in 64bit words *)
let pfkey_reader src socket () =
  let buf = Bytes.create 16 in
  Lwt_unix.recv socket buf 0 16 [Lwt_unix.MSG_PEEK] >>= fun _n ->
  let cs = Cstruct.of_string (Bytes.to_string (Bytes.sub buf 0 16)) in
  let len = (Cstruct.LE.get_uint16 cs 4) * 8 in
  let buf = Bytes.create len in
  Lwt_unix.read socket buf 0 len >|= fun _n ->
  let cs = Cstruct.of_string (Bytes.to_string (Bytes.sub buf 0 len)) in
  Logs.debug ~src (fun pp -> pp "reading %d %a" len Ike.Utils.pp_cs cs) ;
  Some (`Pfkey cs)

let pfkey_send src socket msg =
  Logs.debug ~src (fun pp -> pp "writing %a" Ike.Utils.pp_cs msg) ;
  Lwt_unix.write socket (Bytes.of_string (Cstruct.to_string msg)) 0 (Cstruct.len msg) >>= fun n ->
  (* should be a fail *)
  if n = Cstruct.len msg then
    Lwt.return_unit
  else
    Lwt.fail_with "failed to write to pfkey socket"

(*
let rec user_socket push socket () =
  Lwt_unix.read socket >>= fun data ->
  push (`Control data) >>= fun () ->
  user_socket push socket ()

let rec network_socket push socket () =
  Lwt_unix.recv_from socket >>= fun (data, addr) ->
  push (`Data (data, addr)) >>= fun () ->
  network_socket push socket ()

let rec tick push () =
  push `Tick >>= fun () ->
  Lwt_unix.sleep 0.5 >>= fun () ->
  tick push ()
*)


let service _user _port pfkey_port _config =
  Lwt.async_exception_hook :=
    (* error handling of a failed network send:
        - inform IKE (find which t is responsible and do a proper shutdown)
        --> maybe emit a `NetworkFailure event to handle?
        - what should happen when pfkey socket fails?
        - what if control socket fails?
        - log error (done ;) *)
    (fun exn -> Logs.err (fun pp -> pp "async exception %s" (Printexc.to_string exn))) ;

  let pfkey_src = Logs.Src.create "lwt_pfkey" in
  let pfkey_fd = Lwt_unix.(socket PF_INET SOCK_STREAM 0) in
  Lwt_unix.(connect pfkey_fd (ADDR_INET (Unix.inet_addr_of_string "127.0.0.1", pfkey_port))) >>= fun () ->
  let pfkey_stream = Lwt_stream.from (pfkey_reader pfkey_src pfkey_fd) in
  let maybe_send_pf = function
    | None -> Lwt.return_unit
    | Some pfkey -> pfkey_send pfkey_src pfkey_fd pfkey
  in

  (* Lwt_unix.(socket PF_INET SOCK_STREAM user) >>= fun user ->
     Lwt_unix.(socket PF_INET SOCK_DGRAM port) >>= fun network -> *)
  (* need to bind / connect *)
(*  Lwt.async (pfkey_socket push pfkey) ;
  Lwt.async (user_socket push user) ;
  Lwt.async (network_socket push network) ;
  Lwt.async (tick push) ; *)
  let rec go t =
    Lwt_stream.next pfkey_stream >>= fun ev ->
    match Ike.Dispatcher.handle t ev with
    | Ok (t', `Pfkey pfkey, `Data _nouts) ->
      maybe_send_pf pfkey >>= fun () ->
(*      Lwt_list.iter_s (Lwt_unix.sendto network) nouts >>= fun () -> *)
      go t'
    | Error (Ike.C.Failed str) ->
      Logs.err (fun pp -> pp "failed (with %s) while executing, goodbye" str) ;
      Lwt.return_unit
  in
  let t, pfkey = Ike.Dispatcher.create (*config*) () in
  maybe_send_pf pfkey >>= fun () ->
  go t

(* copied from logs library test/test_lwt.ml *)
let lwt_reporter () =
  let buf_fmt ~like =
    let b = Buffer.create 512 in
    Fmt.with_buffer ~like b,
    fun () -> let m = Buffer.contents b in Buffer.reset b; m
  in
  let app, app_flush = buf_fmt ~like:Fmt.stdout in
  let dst, dst_flush = buf_fmt ~like:Fmt.stderr in
  let report src level ~over k msgf =
    let reporter = Logs_fmt.reporter ~prefix:(Some (Logs.Src.name src ^ " ")) ~app ~dst () in
    let k () =
      let write () = match level with
      | Logs.App -> Lwt_io.write Lwt_io.stdout (app_flush ())
      | _ -> Lwt_io.write Lwt_io.stderr (dst_flush ())
      in
      let unblock () = over (); Lwt.return_unit in
      Lwt.finalize write unblock |> Lwt.ignore_result;
      k ()
    in
    reporter.Logs.report src level ~over:(fun () -> ()) k msgf;
  in
  { Logs.report = report }

(* handle log command-line arguments *)
let pfkey = ref 1234
let user = ref 23
let port = ref 500
let config = ref ""
let rest = ref []

let usage = "usage " ^ Sys.argv.(0)

let arglist = [
  ("-u", Arg.Int (fun d -> user := d), "port for user config (defaults to 23)") ;
  ("-p", Arg.Int (fun d -> pfkey := d), "port for pfkey (defaults to 1234)") ;
  ("-d", Arg.Int (fun d -> port := d), "port for IKE daemon (defaults to 500)") ;
  ("-c", Arg.String (fun d -> config := d), "IKE configuration") ;
]

let _ =
  try
    Arg.parse arglist (fun x -> rest := x :: !rest) usage ;
    Fmt_tty.setup_std_outputs ();
    Logs.set_level @@ Some Logs.Debug;
    Logs.set_reporter @@ lwt_reporter ();
    Lwt_main.run (service !user !port !pfkey !config)
  with
  | Sys_error s -> print_endline s
