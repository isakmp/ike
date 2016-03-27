
type t = {
  ts : state list ;
  config : Config.t ;
}

let handle_tick t =
  List.fold_left (fun (acc, sads) t ->
      match Ike.handle_tick t with
      | `Ok (state, sads', outs) ->
        ({t with state} :: acc, sads' @ sads)
      | `Fail sads' ->
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
  | `Ok (state, sad_changes, outs) ->
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
  | `Fail sad_changes -> (others, sad_changes)

let handle_pfkey t = function
  | _ -> assert false

let handle_config t = function
  | _ -> assert false

let handle t ev =
  match
    match ev with
    | `Pfkey data -> Pfkey.decode data >>= handle_pfkey t
    | `Control data > Control.decode data >>= handle_control t
    | `Data (data, addr) -> handle_data t data addr
    | `Timer -> handle_tick t
  with
  | Ok (t, pfkeys, outs) ->
    (t, `Pfkey (List.map Pfkey.encode pfkeys), `Data outs)
  | Error e -> Error e

let create config () =
  let config = Config.parse config in
  let pfs = [ `Sadb_flush ; `Sadb_register `AH ; `Sadb_register `ESP ] in
  ({ ts = [] ; config }, List.map Pfkey.encode pfs)
