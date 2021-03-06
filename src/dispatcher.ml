open C

type state = int

(* XXX: somehow this might be more convenient (works if each module instantiated only once / using a single logger)
let src = Logs.Src.create "dispatcher" ~doc:"xxx"
module Log = (val Logs.src_log src : Logs.LOG)
*)

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
  match ev with
  | `Pfkey data ->
    Logs.info ~src:t.logger (fun pp -> pp "handling pfkey") ;
    Pfkey_engine.handle t.pfkey data >|= fun (pfkey, cmd) ->
    let cmdstr = match cmd with
      | None -> "none"
      | Some x -> Sexplib.Sexp.to_string_hum (sexp_of_pfkey_from_kern x)
    in
    Logs.info ~src:t.logger (fun pp -> pp "handled pfkeys: %s" cmdstr) ;
    let pfkey, out = Pfkey_engine.maybe_command pfkey in
    Logs.debug ~src:t.logger (fun pp -> pp "sending out %d" (match out with None -> 0 | Some x -> Cstruct.len x)) ;
    ({ t with pfkey }, `Pfkey out, `Data [])
  | `Tick ->
    Logs.debug ~src:t.logger (fun pp -> pp "tick") ;
    Ok (t, `Pfkey None, `Data [])
  | _ -> assert false
(* | `Control data > Control.decode data >>= handle_control t
   | `Data (data, addr) -> handle_data t data addr *)

let create () =
  (*  let config = Config.parse config in *)
  let pfkey, out = Pfkey_engine.create
      ~commands:[`Dump None ; `Flush None ; `Policy_Dump ; `Policy_Flush ; `Register `AH ; `Register `ESP] () in
  ({ ts = [] ; pfkey ; logger = Logs.Src.create "dispatcher" }, out)
