open Core.Std
open MoOps
module MoInst = MoInstructions

type labelvars = {
  typ : string;
  flag_prf : string;
  flag_out : string;
}

type t = {
  mutable ctr : int;
  code : string Queue.t;
  items : labelvars Stack.t;
  mutable start_vars : labelvars;
}

let datatypes = "(declare-datatypes () ((T R B)))"

let create () =
  let t = { ctr = 1;
            code = Queue.create ();
            items = Stack.create ();
            start_vars = { typ = ""; flag_prf = ""; flag_out = "" };
          } in
  Queue.enqueue t.code datatypes;
  t

let create_vars t fn =
  let typ = "var" ^ "_" ^ fn ^ "_" ^ (string_of_int t.ctr) in
  let flag_prf = "flag_prf" ^ "_" ^ fn ^ "_" ^ (string_of_int t.ctr) in
  let flag_out = "flag_out" ^ "_" ^ fn ^ "_" ^ (string_of_int t.ctr) in
  let r = { typ = typ; flag_prf = flag_prf; flag_out = flag_out } in
  t.ctr <- t.ctr + 1;
  r

let dup t =
  let l = create_vars t "dup" in
  let r = create_vars t "dup" in
  let x = Stack.pop_exn t.items in
  Queue.enqueue t.code ("\
;; DUP
(declare-const "^l.typ^" T)
(declare-const "^r.typ^" T)
(declare-const "^l.flag_prf^" Bool)
(declare-const "^l.flag_out^" Bool)
(declare-const "^r.flag_prf^" Bool)
(declare-const "^r.flag_out^" Bool)
(assert (= "^x.typ^" "^l.typ^" "^r.typ^"))
(assert (= (or "^l.flag_prf^" "^r.flag_prf^") "^x.flag_prf^"))
(assert (= (or "^l.flag_out^" "^r.flag_out^") "^x.flag_out^"))
(assert (= (and "^l.flag_prf^" "^r.flag_prf^") false))
(assert (= (and "^l.flag_out^" "^r.flag_out^") false))");
  Stack.push t.items r;
  Stack.push t.items l

let genrand t =
  let v = create_vars t "genrand" in
  Queue.enqueue t.code ("\
;; GENRAND
(declare-const "^v.typ^" T)
(declare-const "^v.flag_prf^" Bool)
(declare-const "^v.flag_out^" Bool)
(assert (and (= "^v.typ^" R) (= "^v.flag_prf^" "^v.flag_out^" true)))");
  Stack.push t.items v

let msg t =
  let v = create_vars t "m" in
  Queue.enqueue t.code ("\
;; M
(declare-const "^v.typ^" T)
(declare-const "^v.flag_prf^" Bool)
(declare-const "^v.flag_out^" Bool)
(assert (and (= "^v.typ^" B) (= "^v.flag_prf^" "^v.flag_out^" false)))");
  Stack.push t.items v

let nextiv t phase =
  let x = Stack.pop_exn t.items in
  let v = create_vars t "nextiv" in
  Queue.enqueue t.code ("\
;; NEXTIV
(declare-const "^v.typ^" T)
(declare-const "^v.flag_prf^" Bool)
(declare-const "^v.flag_out^" Bool)
(assert (and (= "^v.typ^" "^x.typ^")
             (= "^v.flag_prf^" "^x.flag_prf^")
             (= "^v.flag_out^" "^x.flag_out^")))");
  begin
    match phase with
    | Init -> ()
    | Block ->
       Queue.enqueue t.code ("\
(assert (= "^v.typ^" "^t.start_vars.typ^"))
(assert (= "^v.flag_out^" "^t.start_vars.flag_out^"))
(assert (= "^v.flag_prf^" "^t.start_vars.flag_prf^"))");
  end;
  Stack.push t.items v
(*   match phase with *)
(*     | Init -> *)
(*       let v = create_vars t "nextiv" in *)
(*       Queue.enqueue t.code ("\ *)
(* ;; NEXTIV *)
(* (declare-const "^v.typ^" T) *)
(* (assert (= "^v.typ^" "^x.typ^"))"); *)
(*       Stack.push t.nextivs v; *)
(*       Stack.push t.items v *)
(*     | Block -> *)
(*       let v = Stack.pop_exn t.nextivs in *)
(*       Queue.enqueue t.code ("\ *)
(* ;; NEXTIV *)
(* (assert (= "^x.typ^" "^v.typ^"))") *)

let out t =
  let x = Stack.pop_exn t.items in
  Queue.enqueue t.code ("\
;; OUT
(assert (and (= "^x.typ^" R) (= "^x.flag_out^" true)))")

let prf t =
  let x = Stack.pop_exn t.items in
  Queue.enqueue t.code ("\
;; PRF
(assert (and (= "^x.typ^" R)
             (= "^x.flag_prf^" true)))");
  genrand t

let start t =
  let x = Stack.pop_exn t.items in
  let v = create_vars t "start" in
  Queue.enqueue t.code ("\
;; START
(declare-const "^v.typ^" T)
(declare-const "^v.flag_prf^" Bool)
(declare-const "^v.flag_out^" Bool)
(assert (and (= "^v.typ^" "^x.typ^")
             (= "^v.flag_prf^" "^x.flag_prf^")
             (= "^v.flag_out^" "^x.flag_out^")))");
  t.start_vars <- v;
  Stack.push t.items v

let xor t =
  let v = create_vars t "xor" in
  let x = Stack.pop_exn t.items in
  let y = Stack.pop_exn t.items in
  Queue.enqueue t.code ("\
;; XOR
(declare-const "^v.typ^" T)
(declare-const "^v.flag_prf^" Bool)
(declare-const "^v.flag_out^" Bool)
(assert (or (= "^x.typ^" R) (= "^y.typ^" R)))
(assert (= "^v.typ^" R))
(assert (if (= "^x.typ^" R)
            (if (= "^y.typ^" R)
                (and
                 (= (or "^x.flag_prf^" "^y.flag_prf^") "^v.flag_prf^")
                 (= (or "^x.flag_out^" "^y.flag_out^") "^v.flag_out^"))
                (and (= "^x.flag_prf^" "^v.flag_prf^")
                     (= "^x.flag_out^" "^v.flag_out^")))
            (and (= "^y.flag_prf^" "^v.flag_prf^")
                 (= "^y.flag_out^" "^v.flag_out^"))))");
  Stack.push t.items v

let op t = function
  | Dup -> dup t
  | Genrand -> genrand t
  | M -> msg t
  | Nextiv_init -> nextiv t Init
  | Nextiv_block -> nextiv t Block
  | Out -> out t
  | Prf -> prf t
  | Start -> start t
  | Xor -> xor t

let check_sat_cmd t = Queue.enqueue t.code "(check-sat)"
let get_model_cmd t = Queue.enqueue t.code "(get-model)"

let write_to_file t f =
  Out_channel.write_lines f (Queue.to_list t.code);

(* let display_model g s = *)
(*   (\* XXX: complete hack! *\) *)
(*   let s = String.concat ~sep:" " (String.split s ~on:'\n') in *)
(*   let extract_int s = *)
(*     let n = String.length s in *)
(*     let r = Str.regexp "[0-9]+" in *)
(*     let a = Str.search_forward r s 0 in *)
(*     let b = Str.search_backward r s n in *)
(*     int_of_string (String.slice s a (b + 1)) *)
(*   in *)
(*   let rec loop s l = *)
(*     match String.prefix s 10 with *)
(*       | "define-fun" -> *)
(*         let fst = String.index_exn s ')' in *)
(*         let snd = String.index_from_exn s (fst + 1) ')' in *)
(*         let s' = String.slice s 0 snd in *)
(*         let space = String.rindex_exn s' ' ' in *)
(*         let tag = String.slice s' (space + 1) snd in *)
(*         let i = extract_int s' in *)
(*         loop (String.slice s (snd + 1) 0) ((i, tag) :: l) *)
(*       | _ -> begin *)
(*         let i = String.index s '(' in *)
(*         match i with *)
(*           | None -> l *)
(*           | Some i -> loop (String.slice s (i + 1) 0) l *)
(*       end *)
(*   in *)
(*   let l = loop s [] in *)
(*   let cmp (i, tag) (i', tag') = Int.compare i i' in *)
(*   let l = List.sort ~cmp:cmp l in *)
(*   MoGraph.display_model_with_feh g l *)

(* let validate graph = *)
(*   let save = Some "test.smt2" in *)
(*   let model = None in *)
(*   let t = create () in *)
(*   let f v = *)
(*     match G.V.label v with *)
(*     | Start -> start t *)
(*     | Genrand -> genrand t *)
(*     | M -> msg t *)
(*     | Dup -> dup t *)
(*     | Prf -> prf t *)
(*     | Xor -> xor t *)
(*     | _ -> raise (Failure "woah panic!") in *)
(*   G.iter_vertex f graph; *)
(*   check_sat_cmd t; *)
(*   get_model_cmd t; *)
(*   let tmp = Filename.temp_file "z3" ".smt2" in *)
(*   Out_channel.write_lines tmp (Queue.to_list t.code); *)
(*   begin *)
(*     match save with *)
(*       | Some fn -> Out_channel.write_lines fn (Queue.to_list t.code) *)
(*       | None -> () *)
(*   end; *)
(*   let s = MoUtils.run_proc ("z3 " ^ tmp) in *)
(*   let r = begin *)
(*     match List.hd_exn (String.split s ~on:'\n') with *)
(*       | "sat" -> begin *)
(*         (match model with *)
(*           | None -> () *)
(*           | Some g -> display_model g s); *)
(*         true *)
(*       end *)
(*       | "unsat" -> false *)
(*       | _ -> raise (Failure ("Fatal: unknown Z3 error: " ^ s)) *)
(*   end in *)
(*   Sys.remove tmp; *)
(*   r *)
       

(* let validate ?(save=None) ?(model=None) init block = *)
(*   let t = create () in *)
(*   let iter t l = List.iter l ~f:(op t) in *)
(*   iter t init; *)
(*   iter t block; *)
(*   check_sat_cmd t; *)
(*   get_model_cmd t; *)
(*   let tmp = Filename.temp_file "z3" ".smt2" in *)
(*   Out_channel.write_lines tmp (Queue.to_list t.code); *)
(*   begin *)
(*     match save with *)
(*       | Some fn -> Out_channel.write_lines fn (Queue.to_list t.code) *)
(*       | None -> () *)
(*   end; *)
(*   let s = MoUtils.run_proc ("z3 " ^ tmp) in *)
(*   let r = begin *)
(*     match List.hd_exn (String.split s ~on:'\n') with *)
(*       | "sat" -> begin *)
(*         (match model with *)
(*           | None -> () *)
(*           | Some g -> display_model g s); *)
(*         true *)
(*       end *)
(*       | "unsat" -> false *)
(*       | _ -> raise (Failure ("Fatal: unknown Z3 error: " ^ s)) *)
(*   end in *)
(*   Sys.remove tmp; *)
(*   r *)