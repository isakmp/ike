
(* general useful utilities missing from the stdlib *)

let rec filter_map ~f = function
  | []    -> []
  | x::xs ->
      match f x with
      | None    ->       filter_map ~f xs
      | Some x' -> x' :: filter_map ~f xs

let rec map_find ~f = function
  | []    -> None
  | x::xs ->
      match f x with
      | None         -> map_find ~f xs
      | Some _ as x' -> x'

let option none some = function
  | None   -> none
  | Some x -> some x


module Hex = struct
  let printable s r =
    let l = String.length s in
    for i = 0 to pred l do
      match String.get s i with
      | x when int_of_char x > 0x20 && int_of_char x < 0x7F -> Bytes.set r i x
      | _ -> Bytes.set r i '.'
    done

  let c_to_h c idx s =
    let v_to_h = function
      | x when x < 10 -> char_of_int (x + 48)
      | x -> char_of_int (x + 55)
    in
    let i = int_of_char c in
    let high = (0xf0 land i) lsr 4
    and low = 0x0f land i
    in
    Bytes.set s idx (v_to_h high) ;
    Bytes.set s (succ idx) (v_to_h low)

  let to_hex bytes =
    if bytes = "" then
      ""
    else
      let s = Bytes.make (String.length bytes * 3 - 1) ' ' in
      for i = 0 to pred (String.length bytes) do
        c_to_h (String.get bytes i) (i * 3) s
      done ;
      Bytes.to_string s

  let to_hexdump data =
    let rec lines d acc =
      if d = "" then List.rev acc
      else
        let data, left =
          let l = String.length d in
          if l > 16 then String.sub d 0 16, String.sub d 16 (l - 16)
          else d, ""
        in
        let d1, d2 =
          let l = String.length data in
          if l > 8 then String.sub data 0 8, String.sub data 8 (l - 8)
          else data, ""
        in
        let p_hex d =
          let l = String.length d in
          let h = to_hex d in
          if l = 0 then
            String.make 23 ' '
          else if l < 8 then
            h ^ (String.make ((8 - l) * 3) ' ')
          else
            h
        in
        let cnt =
          let b = Bytes.make 4 ' ' in
          let f, s =
            let l = 16 * List.length acc in
            char_of_int (l lsr 8), char_of_int (l mod 256)
          in
          c_to_h f 0 b ;
          c_to_h s 2 b ;
          Bytes.to_string b
        in
        let hr1 = Bytes.make 8 ' '
        and hr2 = Bytes.make 8 ' '
        in
        printable d1 hr1 ;
        printable d2 hr2 ;
        let d = String.concat "  " [ cnt ; p_hex d1 ; p_hex d2 ; Bytes.to_string (Bytes.concat (Bytes.make 1 ' ') [ hr1 ; hr2 ]) ] in
        lines left (d :: acc)
    in
    lines data []
end

let pp_cs pp cs =
  List.iter (fun hex ->
      Format.pp_print_newline pp () ;
      Format.pp_print_string pp hex)
    (Hex.to_hexdump (Cstruct.to_string cs))
