
(* IKEv2 LWT interface

communication channels:
  - kernel: pfkey(v2) - RFC2367 + KAME changes
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
   message length is a 16 bit value, little endian, offset 5, in 64bit words *)
let pfkey_reader src socket () =
  let buf = Bytes.create 16 in
  Lwt_unix.recv socket buf 0 16 [Lwt_unix.MSG_PEEK] >>= fun _n ->
  let cs = Cstruct.of_string (Bytes.to_string (Bytes.sub buf 0 16)) in
  let len = (Cstruct.LE.get_uint16 cs 4) * 8 in
  let buf = Bytes.create len in
  Lwt_unix.read socket buf 0 len >|= fun _n ->
  let cs = Cstruct.of_string (Bytes.to_string (Bytes.sub buf 0 len)) in
  Logs.debug ~src (fun pp -> pp "read %d %a" len Ike.Utils.pp_cs cs) ;
  Some (`Pfkey cs)

let pfkey_send src socket msg =
  let len = Cstruct.len msg in
  Logs.debug ~src (fun pp -> pp "writing %d %a" len Ike.Utils.pp_cs msg) ;
  let bytes = Bytes.of_string (Cstruct.to_string msg) in
  Lwt_unix.write socket bytes 0 len >>= fun n ->
  (* should be a fail *)
  if n = Cstruct.len msg then
    Lwt.return_unit
  else
    Lwt.fail_with "failed to write to pfkey socket"


let pfkey_socket_fd addr =
  let buf = " " in
  let io_vectors = [ Lwt_unix.(io_vector buf 0 1) ] in
  let pass_fd = Lwt_unix.(socket PF_UNIX SOCK_STREAM 0) in
  Lwt_unix.(connect pass_fd (ADDR_UNIX addr)) >>= fun () ->
  Lwt_unix.(recv_msg pass_fd io_vectors) >>= function
  | (1, [pfkey_fd]) ->
    Lwt_unix.(close pass_fd) >>= fun () ->
    Lwt.return (Lwt_unix.of_unix_file_descr pfkey_fd)
  | ( _ , _ ) ->
    Lwt_unix.(close pass_fd) >>= fun () ->
    Lwt.fail_with "failed to aquire pf_key fd"

let pfkey_socket_tcp port =
  let pfkey_fd = Lwt_unix.(socket PF_INET SOCK_STREAM 0)
  and addr = Lwt_unix.ADDR_INET (Unix.inet_addr_of_string "127.0.0.1", port)
  in
  Lwt_unix.connect pfkey_fd addr >>= fun () ->
  Lwt.return pfkey_fd

let pfkey_socket = function
  | (_, addr) when (String.length addr) != 0 -> pfkey_socket_fd addr
  | (port, _) -> pfkey_socket_tcp port

(*
let rec user_socket push socket () =
  Lwt_unix.read socket >>= fun data ->
  push (`Control data) >>= fun () ->
  user_socket push socket ()

let rec network_socket push socket () =
  Lwt_unix.recv_from socket >>= fun (data, addr) ->
  push (`Data (data, addr)) >>= fun () ->
  network_socket push socket ()
*)

let tick () =
  Lwt_unix.sleep 5. >|= fun () ->
  Some `Tick

let service _user _port pf_key_cnf _config =
  Lwt.async_exception_hook :=
    (* error handling of a failed network send:
        - inform IKE (find which t is responsible and do a proper shutdown)
        --> maybe emit a `NetworkFailure event to handle?
        - what should happen when pfkey socket fails?
        - what if control socket fails?
        - log error (done ;) *)
    (fun exn -> Logs.err (fun pp ->
         pp "async exception %s" (Printexc.to_string exn))) ;

  let pfkey_src = Logs.Src.create "lwt_pfkey" in
  pfkey_socket pf_key_cnf >>= fun pfkey_fd ->
  let pfkey_stream = Lwt_stream.from (pfkey_reader pfkey_src pfkey_fd) in
  let maybe_send_pf = function
    | None -> Lwt.return_unit
    | Some pfkey -> pfkey_send pfkey_src pfkey_fd pfkey
  in

  (* Lwt_unix.(socket PF_INET SOCK_STREAM user) >>= fun user ->
     Lwt_unix.(socket PF_INET SOCK_DGRAM port) >>= fun network -> *)
  (* need to bind / connect *)
  (* drop privileges <here> *)
(*Lwt.async (user_socket push user) ;
  Lwt.async (network_socket push network) ; *)

  let timer_stream = Lwt_stream.from tick in
  (* we might need some fixed choose, https://github.com/ocsigen/lwt/issues/213 (and 214) *)
  let stream = Lwt_stream.choose [ pfkey_stream ; timer_stream ] in
  let rec go t =
    Lwt_stream.next stream >>= fun ev ->
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
    let prefix = Some (Logs.Src.name src ^ " ") in
    let reporter = Logs_fmt.reporter ~prefix ~app ~dst () in
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
let un_addr = ref ""
let rest = ref []

let usage = "usage " ^ Sys.argv.(0)

let arglist = [
  ("-u", Arg.Int (fun d -> user := d), "user port (defaults to 23)") ;
  ("-p", Arg.Int (fun d -> pfkey := d), "pfkey port (defaults to 1234)") ;
  ("-A", Arg.String (fun d -> un_addr := d), "pfkey UNIX-domain address");
  ("-d", Arg.Int (fun d -> port := d), "IKE daemin port (defaults to 500)") ;
  ("-c", Arg.String (fun d -> config := d), "IKE configuration file") ;
]

let _ =
  try
    Arg.parse arglist (fun x -> rest := x :: !rest) usage ;
    Fmt_tty.setup_std_outputs ();
    Logs.set_level @@ Some Logs.Debug;
    Logs.set_reporter @@ lwt_reporter ();
    Lwt_main.run (service !user !port (!pfkey, !un_addr) !config)
  with
  | Sys_error s -> print_endline s
