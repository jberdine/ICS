(*
 * The contents of this file are subject to the ICS(TM) Community Research
 * License Version 1.0 (the ``License''); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.icansolve.com/license.html.  Software distributed under the
 * License is distributed on an ``AS IS'' basis, WITHOUT WARRANTY OF ANY
 * KIND, either express or implied. See the License for the specific language
 * governing rights and limitations under the License.  The Licensed Software
 * is Copyright (c) SRI International 2001, 2002.  All rights reserved.
 * ``ICS'' is a trademark of SRI International, a California nonprofit public
 * benefit corporation.
 * 
 * Author: Harald Ruess
 *)

open Name.Map

(** Global state. *)

type t = {
  mutable current : Context.t;
  mutable symtab : Symtab.t;
  mutable inchannel : in_channel;
  mutable outchannel : Format.formatter;
  mutable eot : string;
  mutable counter : int
}

let init () = {
  current = Context.empty;
  symtab = Symtab.empty;
  inchannel = Pervasives.stdin;
  outchannel = Format.std_formatter;
  eot = "";
  counter = 0
}

let s = init ()

(** Initialize. *)

let initialize pp eot inch outch =
  Term.pretty := pp;
  s.eot <- eot;
  s.inchannel <- inch;
  s.outchannel <- outch
  

(** Accessors to components of global state. *)

let current () = s.current
let symtab () = s.symtab
let eot () = s.eot
let inchannel () = s.inchannel
let outchannel () = s.outchannel


(** Adding to symbol table *)

let def n a =
  let e = Symtab.Def(a) in
    s.symtab <- Symtab.add n e s.symtab
  
let sgn n a =
  let e = Symtab.Arity(a) in
  s.symtab <- Symtab.add n e s.symtab

let typ nl c =
  let e = Symtab.Type(c) in
    List.iter
      (fun n ->
	 s.symtab <- Symtab.add n e s.symtab)
      nl

let entry_of n = 
  try
    Some(Symtab.lookup n s.symtab)
  with
      Not_found -> None
			   
(** Type from the symbol table. *)

let type_of n =
  match Symtab.lookup n s.symtab with
    | Symtab.Type(c) -> Some(c)
    | _ -> None

(** Get context for name in symbol table *)

let context_of n = 
  match Symtab.lookup n s.symtab with
    | Symtab.State(c) -> c
    | _ -> raise (Invalid_argument("No context of name " ^ (Name.to_string n)))

(** Getting the width of bitvector terms from the signature. *)

let width_of a =
  if Term.is_var a then
    let n = Term.name_of a in
    try
      match Symtab.lookup n s.symtab with
	| Symtab.Arity(i) -> Some(i)
	| _ -> None
    with
	Not_found -> None
  else
    Bitvector.width a

(** Resetting all of the global state. *)

let reset () = 
  Tools.do_at_reset ();
  s.current <- Context.empty;
  s.symtab <- Symtab.empty;
  s.counter <- 0

(** Getting either current context or explicitly specified context. *)

let get_context = function
  | None -> s.current
  | Some(n) -> context_of n

(** Set input and output channels. *)

let set_inchannel ch = 
  s.inchannel <- ch

let set_outchannel fmt = 
  s.outchannel <- fmt

let flush () = Format.fprintf s.outchannel "@?"
let nl () = Format.fprintf s.outchannel "\n"


(** Context. *)

let ctxt_of = function
  | None -> Context.ctxt_of s.current
  | Some(n) -> Context.ctxt_of (context_of n)

(** Canonization w.r.t current state. *)

let can a = 
  Context.can s.current a

let sigma f l = Context.sigma s.current f l


(** Create a fresh name for a state. *)

let rec fresh_state_name () =
  s.counter <- s.counter + 1;
  let n = Name.of_string ("s" ^ (string_of_int s.counter)) in
  try
    let _ = Symtab.lookup n s.symtab in  (* make sure state name is really fresh. *)
    fresh_state_name ()
  with
      Not_found -> 
	n

(** Change current state. *)

let save arg =
  let n = match arg with
    | None -> fresh_state_name ()
    | Some(n) -> n
  in
  let e = Symtab.State s.current in
  s.symtab <- Symtab.add n e s.symtab;
  n

let restore n =
  try
    match Symtab.lookup n s.symtab with
      | Symtab.State(t) -> s.current <- t
      | _ -> raise Not_found
  with
      Not_found -> raise (Invalid_argument "Not a state name")

let remove n =      
  s.symtab <- Symtab.remove n s.symtab

let forget () =
  s.current <- Context.empty

(** Adding a new fact *)

let process n =
  let t = (get_context n) in
    (fun a -> 
       let status = Context.add t a in
	 match status with  (* Update state and install new name in symbol table *)
	   | Context.Status.Ok(t') -> 
	       s.current <- t';
	       let n = save None in
		 Context.Status.Ok(n)
	   | Context.Status.Valid -> Context.Status.Valid
	   | Context.Status.Inconsistent -> Context.Status.Inconsistent)

let valid n a =
  match Context.add (get_context n) a with 
    | Context.Status.Valid -> true
    | _ -> false

let unsat n a =
  match Context.add (get_context n) a with 
    | Context.Status.Inconsistent -> true
    | _ -> false

let model n xs =
  let m = Context.model (get_context n) xs in
    Term.Map.fold (fun x a acc -> (x, a) :: acc) m []

(** Accessors. *)

let diseq n a =
  let s = get_context n in
  let a' = Context.can s a in
  try
    List.fold_right Term.Set.add (Context.d s a') Term.Set.empty
  with
      Not_found -> Term.Set.empty

let sign n a =
  let s = get_context n in
  let a' = Context.can s a in
    try
      Some(Context.cnstrnt s a')
    with
	Not_found -> None

let dom n a =
  let s = get_context n in
  let a' = Context.can s a in
    try
      Some(Context.dom s a')
    with
	Not_found -> None

(** Applying maps. *)


let find n i x = Context.find i (get_context n) x
let inv n i b = Context.inv i (get_context n) b
let use n i = Context.use i (get_context n)

(** Solution sets. *)

let solution n i = 
  Solution.fold
    (fun x (a, _) acc -> (x, a) :: acc)
    (Context.eqs_of (get_context n) i)
    []


(** Solver. *)

let solve i (a, b) = 
  try
    let e = Fact.mk_equal a b None in
      List.map (fun e' -> 
		  let (x, b, _) = Fact.d_equal e' in
		    (x, b))
	(Th.solve i e)
  with
    | Exc.Inconsistent -> raise(Invalid_argument("Unsat"))
 
(** Equality/disequality test. *)

let is_equal a b =
  Context.is_equal s.current a b


(** Sat solver *)

let sat p =
  match Prop.sat s.current p with
    | None -> 
	None
    | Some(rho, s') -> 
	let n = fresh_state_name () in
	  s.symtab <- Symtab.add n (Symtab.State(s')) s.symtab;
	  Some(rho, n)
	

(** Splitting. *)

let split () = Context.split s.current
