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
 *)

open Mpa
open Sym
open Term

(** {6 Symbols} *)

let num q = Arith(Num(q))

let multq q = Arith(Multq(q))

let add = Arith(Add)


(** {6 Theory-specific recognizers} *)

let is_interp a =
  match a with
    | App(Arith _, _) -> true
    | _ -> false


(** {6 Destructors} *)

let d_num = function
  | App(Arith(Num(q)), []) -> Some(q)
  | _ -> None

let d_multq = function
  | App(Arith(Multq(q)), [x]) -> Some(q, x)
  | _ -> None

let d_add = function
  | App(Arith(Add), xl) -> Some(xl)
  | _ -> None


let monomials = function
  | App(Arith(Add), xl) -> xl
  | x -> [x]


(** {6 Recognizers} *)

let is_num = function
  | App(Arith(Num _), []) -> true
  | _ -> false

let is_zero = function
  | App(Arith(Num(q)), []) -> Q.is_zero q
  | _ -> false

let is_one = function
  | App(Arith(Num(q)), []) -> Q.is_one q
  | _ -> false

let is_q q = function
  | App(Arith(Num(p)), []) -> Q.equal q p
  | _ -> false

let is_multq = function
  | App(Arith(Multq(_)), _) -> true
  | _ -> false

let rec is_diophantine = function
  | App(Arith(Num _), []) -> true
  | App(Arith(Multq(_)), [x]) -> is_intvar x
  | App(Arith(Add), xl) -> List.for_all is_diophantine xl
  | a -> is_intvar a


(** {6 Constants} *)

let mk_num = Term.mk_num

let mk_zero = mk_num(Q.zero)
let mk_one = mk_num(Q.one)
let mk_two = mk_num(Q.of_int 2)


(** {6 Normalizations} *)

let poly_of = Term.poly_of

let of_poly q l =
  let m = if  Q.is_zero q then l else mk_num q :: l in
    match m with 
      | [] -> mk_zero
      | [x] -> x
      | _ -> Term.mk_app add m

let mono_of = function
  | App(Arith(Multq(q)), [x]) -> (q, x)
  | a -> (Q.one, a)

let of_mono q x =
  if Q.is_zero q then
    mk_zero
  else if Q.is_one q then 
    x
  else 
    match x with
      | App(Arith(Num(p)), []) ->
	  mk_num (Q.mult q p) 
      | _ -> 
	  mk_app (multq q) [x]

let fold f a e =
  let (_, ml) = poly_of a in
    List.fold_left
      (fun acc m ->
	 let (q, x) = mono_of m in
	   f q x acc)
      e ml

(** {6 Constructors} *)

let rec mk_multq q a =
  let rec multq q = function
    | [] -> []
    | m :: ml ->
	let (p,x) = mono_of m in
	  (of_mono (Q.mult q p) x) :: (multq q ml)
  in
    if Q.is_zero q then 
      mk_zero
    else if Q.is_one q then 
      a
    else 
      let (p, ml) = poly_of a in
	of_poly (Q.mult q p) (multq q ml)

and mk_addq q a =
  if Q.is_zero q then a else
    match a with
      | App(Arith(Num(p)), []) ->
	  mk_num (Q.add q p)
      | App(Arith(Multq(_)), [_]) ->
	  mk_app add [mk_num q; a]
      | App(Arith(Add), xl) ->
	  (match xl with
	     | App(Arith(Num(p)), []) :: xl' ->
		 let q_plus_p = Q.add q p in
		   if Q.is_zero q_plus_p then
		     mk_app add xl'
		   else 
		     mk_app add (mk_num q_plus_p :: xl')
	     | _ -> 
		 mk_app add (mk_num q :: xl))
      | _ ->
	  mk_app add [mk_num q; a]

and mk_add a b =
  let rec map2 l1 l2 =      (* Add two polynomials *)
    match l1, l2 with
      | [], _ -> l2
      | _ , [] -> l1
      | m1 :: l1', m2 :: l2' ->
	  let (q1, x1) =  mono_of m1 in
	  let (q2, x2) = mono_of m2 in
	  let cmp = Term.cmp x1 x2 in
	    if cmp = 0 then
	      let q = Q.add q1 q2 in
		if Q.is_zero q then 
		  map2 l1' l2'
		else 
		  (of_mono q x1) :: (map2 l1' l2')
	    else if cmp < 0 then
	      m2 :: map2 l1 l2'
	  else (* cmp > 0 *)
	    m1 :: map2 l1' l2
  in
  let (q, l) = poly_of a in
  let (p, m) = poly_of b in
    of_poly (Q.add q p) (map2 l m) 

and mk_addl l =
  match l with
    | [] -> mk_zero
    | [x] -> x
    | [x; y] -> mk_add x y
    | x :: xl -> mk_add x (mk_addl xl)
 
and mk_incr a =
  let (q, l) = poly_of a in
  of_poly (Q.add q Q.one) l

and mk_neg a =
  mk_multq (Q.minus (Q.one)) a

and mk_sub a b =
  mk_add a (mk_neg b)
 

(** Mapping a term transformer [f] over [a]. *)
let rec map f a =
  match a with
    | App(Arith(op), l) ->
	(match op, l with
	   | Num _, [] -> 
	       a
	   | Multq(q), [x] ->
	       let x' = map f x in
		 if x == x' then a else 
		   mk_multq q x'
	   | Add, [x; y] -> 
	       let x' = map f x and y' = map f y in
		 if x == x' && y == y' then a else 
		   mk_add x' y'
	   | Add, xl -> 
	       let xl' = Term.mapl (map f) xl in
		 if xl == xl' then a else
		   mk_addl xl'
	   | _ -> 
	       assert false)
    | _ ->
	f a

(** Replacing a variable with a term. *)
let replace a x e =
  map (fun y -> if Term.eq x y then e else y) a


(** Interface for sigmatizing arithmetic terms. *)
let rec sigma op l =
  match op, l with
    | Num(q), [] -> mk_num q
    | Add, [x; y] -> mk_add x y
    | Add, _ :: _ :: _ -> mk_addl l
    | Multq(q), [x] -> mk_multq q x
    | _ ->  assert false


(** Domain interpretation. *)
let rec tau = function
  | App(Arith(Num(q)), []) -> Dom.of_q q
  | App(Arith(Multq(q)), [x]) -> Dom.union (Dom.of_q q) (tau x)
  | App(Arith(Add), xl) -> 
      if List.for_all (fun x -> Dom.eq (tau x) Dom.Int) xl then Dom.Int else Dom.Real
  | a -> if is_intvar a then Dom.Int else Dom.Real


let rec qsolve (a, b) =
  let p, ml = poly_of (mk_sub a b) in
    match ml with
      | [] -> 
	  if Q.is_zero p then None else raise Exc.Inconsistent
      | m :: ml -> 
	  let (q, x) = mono_of m in         (* [p + q * x + ml = 0] *)
	  let b = mk_addq (Q.minus (Q.div p q))
		    (mk_multq (Q.minus (Q.inv q))
		       (mk_addl ml))
	  in
	    Some(x, b)

	

(** {6 Integer solver} *)

let mk_fresh =
  let name = Name.of_string "a"
  and d = Some(Dom.Int) in
    fun () -> Term.mk_fresh name None d


module Euclid = Euclid.Make(
  struct
   type q = Q.t
   let eq = Q.equal
   let ( + ) = Q.add
   let inv = Q.minus
   let zero = Q.zero
   let ( * ) = Q.mult
   let one = Q.one
   let ( / ) = Q.div
   let floor q = Q.of_z (Q.floor q)
   let is_int = Q.is_integer
  end)


let rec zsolve (a, b) =    
  if Term.eq a b then [] else
    if is_var a && is_var b then
      [Term.orient(a, b)]
    else 
      let (q, ml) = poly_of (mk_sub a b) in   (* [q + ml = 0] *)
	if ml = [] then
	  if Q.is_zero q then [] else raise(Exc.Inconsistent)
	else
	  let (cl, xl) = vectorize ml in     (* [cl * xl = ml] in vector notation *)
	    match Euclid.solve cl (Q.minus q) with
	      | None -> raise Exc.Inconsistent
	      | Some(d, pl) -> 
		  let (kl, gl) = general cl (d, pl) in
		    List.combine xl gl
	     
and vectorize ml =
  let rec loop (ql, xl) = function
    | [] -> 
	(List.rev ql, List.rev xl) 
    | m :: ml ->
	let (q, x) = mono_of m in
	  loop (q :: ql, x :: xl) ml
  in
    loop ([], []) ml


(** Compute the general solution of a linear Diophantine
  equation with coefficients [al], the gcd [d] of [al]
  and a particular solution [pl]. In the case of four
  coeffients, compute, for example,
   [(p0 p1 p2 p3) + k0/d * (a1 -a0 0 0) + k1/d * (0 a2 -a1 0) + k2/d * (0 0 a3 -a2)]
  Here, [k0], [k1], and [k2] are fresh variables. Note that
  any basis of the vector space of solutions [xl] of the 
  equation [al * xl = 0] would be appropriate. *)
and general al (d, pl) =
  let fl = ref [] in
  let rec loop al zl =
    match al, zl with
      | [_], [_] -> zl
      | a0 :: ((a1 :: al'') as al'),  z0 :: z1 :: zl'' ->
          let k = mk_fresh () in
	    fl := k :: !fl;
            let e0 = mk_add z0 (mk_multq (Q.div a1 d) k) in
            let e1 = mk_add z1 (mk_multq (Q.div (Q.minus a0) d) k) in
              e0 :: loop al' (e1 :: zl'')
      | _ -> assert false
  in
    (!fl, loop al (List.map mk_num pl))


let integer_solve = ref false

let solve e =
  let (a, b, prf) = Fact.d_equal e in 
  let prf' =  Fact.mk_rule "Arith.solve" [prf] in
    if !integer_solve && is_diophantine a && is_diophantine b then
      let sl = zsolve (a, b) in
	List.map (fun (c, d) -> Fact.mk_equal c d prf') sl
    else 
      match qsolve (a, b) with
	| None -> []
	| Some(c, d) -> [Fact.mk_equal c d prf']


(** Isolate [y] in a solved equality [x = a]. *)
let isolate y (x, a) = 
  let rec destructure pre post =     (* [pre + post = 0]. *)
    match post with
      | [m] ->
	  let (q, y') = mono_of m in
	    if Term.eq y y' then
	      (pre, q, y, [])
	    else 
	      raise Not_found
      | m :: post' ->
	  let (q, y') = mono_of m in
	    if Term.eq y y' then
	      (pre, q, y, post')
	    else 
	      destructure (m :: pre) post'
      | [] ->
	  assert false
  in                              (* [pre + q * y + post = a]. *)
  let (pre, q, y, post) = destructure [] (monomials a) in
    assert(not(Q.is_zero q));
    mk_multq (Q.inv q)
      (mk_sub x (mk_addl (pre @ post)))
