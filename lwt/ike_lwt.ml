
type session = {
  state : state ;
  addr : Ipaddr.t * int ;
}

type t = t list * sad list * control

let tick s ts =
  Lwt_list.fold_left_s (fun (acc, sads) t ->
      match Ike.handle_tick t.state with
      | `Ok (state, sads', outs) ->
        Lwt_list.iter_s (Lwt_unix.sendto s t.addr outs) >|= fun () ->
        ({t with state} :: acc, sads' @ sads)
      | `Fail sads' ->
        return (acc, sads' @ sads))
    ([], [])
    ts >>= fun (ts, sad_changes) ->
  (ts, sad_changes)

(* there might also be events from the control socket *)
let read_or_tick s =
  Lwt.join [
    (Lwt_unix.recv_from s >|= fun (addr, cs) -> `Data (addr, cs)) ;
    (Lwt_engine.on_timer tick_t >|= fun _ -> `Tick)
  ]

let handle_next config s ts =
  read_or_tick s >>= function
  | `Tick -> tick s ts
  | `Data (addr, cs) ->
    let t, others =
      match List.partition (spi_matches cs) ts with
      | ([t], others) -> (t, others)
      | ([], others) ->
        let state = Ike.responder config addr in
        ({ state ; addr }, others)
      | _ -> assert false
    in
    match Ike.handle_ike t.state addr cs with
    | `Ok (state, sad_changes, outs) ->
      Lwt_list.iter_s (Lwt_unix.sendto s t.addr outs) >|= fun () ->
      ({t with state} :: others, sad_changes)
    | `InitialContact (state, auth, outs) ->
      Lwt_list.iter_s (Lwt_unix.sendto s t.addr outs) >|= fun () ->
      let ts, sad_changes =
        List.fold_left (fun (acc, sads) t ->
            match Ike.handle_initial_contact t.state auth with
            | `Ok state -> ({ t with state } :: acc, sads)
            | `Fail sads' -> (acc, sads' @ sads))
          ([], [])
          others
      in
      ({t with state} :: ts, sad_changes)
    | `Fail sad_changes -> return (others, sad_changes)

let sad_change control = function
  | `Add _sad -> Lwt_io.write control "added sad"
  | `Remove _sad -> Lwt_io.write control "removed sad"

let service config control port =
  let rec loop s ts =
    handle_next config s ts >>= fun (ts, sad_changes) ->
    Lwt_list.iter_s (sad_change control) sad_changes >>= fun () ->
    loop s ts
  in
  let open_one pad =
    let state, addr = Ike.initiator config pad in
    { state ; addr }
  in
  Udp.bind port >>= fun s ->
  loop s (List.map open_one (Ike.active_pads config))
