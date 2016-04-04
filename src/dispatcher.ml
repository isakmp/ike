open C

type state = int

type t = {
  ts : state list ;
  pfkey : Pfkey_engine.state ;
  logger : Logs.src ;
(*  config : Config.t ;
  supported_auth : ?? ; (* from the kernel *)
    supported_enc : ?? ; *)
}

(*
let handle_tick t =
  List.fold_left (fun (acc, sads) t ->
      match Ike.handle_tick t with
      | Ok (state, sads', outs) ->
        ({t with state} :: acc, sads' @ sads)
      | Error sads' ->
        (acc, sads' @ sads))
    ([], [])
    ts

let handle_data t data addr =
  let t, others =
    match List.partition (spi_matches cs) ts with
    | ([t], others) -> (t, others)
    | ([], others) ->
      let state = Ike.responder config addr in
      ({ state ; addr }, others)
    | _ -> assert false
  in
  match Ike.handle_ike t.state addr cs with
  | Ok (state, sad_changes, outs) ->
    ({t with state} :: others, sad_changes, outs)
  | `InitialContact (state, auth, outs) ->
    let ts, sad_changes =
      List.fold_left (fun (acc, sads) t ->
          match Ike.handle_initial_contact t.state auth with
          | `Ok state -> ({ t with state } :: acc, sads)
          | `Fail sads' -> (acc, sads' @ sads))
        ([], [])
        others
    in
    ({t with state} :: ts, sad_changes)
  | Error sad_changes -> (others, sad_changes)
*)

(*
let handle_control t = function
  | _ -> assert false
*)

let handle t ev =
  Logs.info ~src:t.logger (fun pp -> pp "handling..") ;
  match ev with
  | `Pfkey data ->
    Pfkey_engine.decode t.pfkey data >|= fun (pfkey, out) ->
    Logs.info ~src:t.logger (fun pp -> pp "handled pfkeys, out %s" out) ;
    ({ t with pfkey }, `Pfkey [], `Data [])
  | _ -> assert false
(* | `Control data > Control.decode data >>= handle_control t
   | `Data (data, addr) -> handle_data t data addr
   | `Timer -> handle_tick t *)

let create () =
  (*  let config = Config.parse config in *)
  let pfs = [ (* `Flush ; `Register Pfkey_wire.AH ;*) `Register Pfkey_wire.ESP ] in
  let pfkey = Pfkey_engine.create () in
  let pfkey, outs =
    List.fold_left (fun (s, cs) msg ->
        let s', out = Pfkey_engine.encode s msg in
        s', out :: cs)
      (pfkey, [])
      pfs
  in
  ({ ts = [] ; pfkey ; logger = Logs.Src.create "dispatcher" },
   List.rev outs)
