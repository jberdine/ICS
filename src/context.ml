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

(** A {b logical context} consists of a set of atoms. Such a context is
  represented in terms of a 
    - {b partition} (see {!Partition.t}) and an 
    - {b equality set} (see {!Solution.t}) for each theory in {!Th.t}. 

  A partition represents variable equalities [x = y] and variable disequalities [x <> y], and
  the solution sets represent equalities [x = a], where [x] is a variable and [a]  
  is a pure term in some theory. An atom is added to a logical context by
  successively
    - Abstracting the atom to one which contains only pure terms using {!Context.abstract}, 
      this may involve the introduction of newly generated variables.
    - Canonization of terms using {!Context.can}, that is, computation of a normal form.
    - Processing of atoms using {!Context.equality} for merging two terms, {!Context.diseq}
      for adding a disequality, and {!Context.add} for adding a constraint.
    - Propagation of newly deduced facts to other components using {!Context.close}.

  For details see also: H. Ruess, N. Shankar, {i Combining Shostak Theories}, 
  published in the proceedings of RTA, 2002. 

  The operations above are all destructive in that they update logical
  contexts. A state is protected by first copying it {!Context.copy} and then
  updating the copy.

  We use the following conventions: [s] always denotes the logical state,
  [ctxt] denotes the set of atoms in the logical states, [p] denotes a partition, 
  and [eqs] stands for a set of equality sets. Furthermore, [a],[b] etc. are used for 
  terms, and whenever a term variable is intended, we use the names [x],[y],[z]. Theory
  names are denoted by [i],[j] etc.
 *)


open Mpa


(** {6 Logical context} *)

type t = {
  mutable ctxt : Atom.Set.t;      (* Current context. *)
  mutable p : Partition.t;        (* Variable partitioning. *)
  eqs : Combine.t;                    (* Theory-specific solution sets. *)
  mutable upper : int;            (* Upper bound on fresh variable index. *)
}


(** The empty logical context. *)
let empty = {
  ctxt = Atom.Set.empty;
  p = Partition.empty;
  eqs = Combine.empty;
  upper = 0
} 


(** Identity test. Do not take upper bounds into account. *)
let eq s1 s2 =              
  Partition.eq s1.p s2.p && 
  Combine.eq s1.eqs s2.eqs


(** Shallow copying. *)
let copy s = {
  ctxt = s.ctxt;
  p = Partition.copy s.p;
  eqs = Combine.copy s.eqs;
  upper = s.upper
}


(** Pretty-printing. *)
let pp fmt s =
  Partition.pp fmt s.p;
  Th.iter (fun i -> Combine.pp i fmt s.eqs)


(** {6 Accessors} *)

let ctxt_of s = s.ctxt
let p_of s = s.p
let v_of s = Partition.v_of s.p
let d_of s = Partition.d_of s.p
let eqs_of s = s.eqs
let partition_of s = s.p
let upper_of s = s.upper
let config_of s = (s.p, s.eqs)


(** {6 Accessing Partitions} *)
	       
let v s = Partition.find s.p
let d s = Partition.diseqs s.p

let diseqs s = Partition.diseqs s.p


(** Folding over equivalence class of [x]. *)
let fold s f x = 
  let (y, _) = v s x in 
    V.fold (v_of s) f y


(** {6 Parameterized operations on solution sets} *)

let is_dependent i s = Combine.is_dependent s.eqs i 
let dep i s = Combine.dep s.eqs i
let apply i s = Combine.apply s.eqs i
let find i s = Combine.find s.eqs i
let inv s = Combine.inv (s.p, s.eqs)
let is_empty i s = Combine.is_empty s.eqs i




(** Return a canonical variable [x] equal to [b]. If [b] is not a rhs in
  the equality set for theory [i], then such a variable [x] is newly created. *)
let name i s = 
  Justification.Eqtrans.compose 
    (v s) 
    (Combine.name (s.p, s.eqs) i)

let name_of_term s a =
  if Term.is_var a then v s a else 
    name (Th.of_sym (Term.App.sym_of a)) s a




(** {6 Abstractions} *)


(** Generate a term with all function symbols in [i], which is equal to [a]
  in [s] possibly extended with variables for subterms of (abstractions) of [a]
  as generated by {!Context.name}. In addition. if [i] is fully uninterpreted,
  then the abstraction of [a] is a flat term of the form [f(x_1,...,x_n)] with
  [x_i] a variable. *)
let abstract s a =   
  let rec of_args j al =
    let rhol = ref [] in       (* collect nontrivial equations used. *)
    let trans a =
      let (b, rho) = of_term j a in
	if not(a == b) then rhol := rho :: !rhol; 
	b
    in
    let bl = Term.mapl trans al in
      (bl, !rhol)
  and of_term i a =
    match a with
      | Term.Var _ ->  
	  v s a
      | Term.App(f, al) ->
	  let j = Th.of_sym f in
	  let (bl, rhol) = of_args j al in    (* roughly, [rhok |- bk = ak] *) 
	  let (c, rho) =                      (* [rho |- c = f(b1,...,bn)] *)
	    if Term.eql al bl then 
	      (a, Justification.refl a)
	    else 
	      Combine.sigma (config_of s) f bl 
	  in
	    if i = Th.u || i = Th.arr || i <> j then
	      let (x, tau) = name j s c in    (* [tau |- x = c] *)
	      let sigma = Justification.subst_equal (x, a) tau (rho :: rhol) in
		(x, sigma)                    (* [sigma |- x = a] *)
	    else 
	      (c, rho)
  in
    match a with 
      | Term.Var _ -> Justification.Eqtrans.id a
      | Term.App(f, _) -> of_term (Th.of_sym f) a


(** {6 Facts} *)

let cheap = ref false

module Fct = struct

  let is_equal s = Combine.is_equal (config_of s)

  let is_nonneg0 = 
    let yes = Justification.Three.Yes(Justification.dependencies0) 
    and no = Justification.Three.No(Justification.dependencies0) in
      fun a -> 
	match Arith.is_nonneg a with
	  | Three.Yes -> yes
	  | Three.No -> no
	  | Three.X -> Justification.Three.X

	      
  let is_pos0 = 
    let yes = Justification.Three.Yes(Justification.dependencies0) 
    and no = Justification.Three.No(Justification.dependencies0) in
      fun a -> 
	match Arith.is_pos a with
	  | Three.Yes -> yes
	  | Three.No -> no
	  | Three.X -> Justification.Three.X

  let is_nonneg s a = 
    if !cheap then
      is_nonneg0 a
    else 
      Combine.is_nonneg (config_of s) a

  let is_pos s a = 
    if !cheap then
      is_pos0 a
    else 
      Combine.is_pos (config_of s) a

  let mk_equal s = Fact.mk_equal (is_equal s)
  let mk_diseq s = Fact.mk_diseq (is_equal s)
  let mk_nonneg s = Fact.mk_nonneg (is_nonneg s)
  let mk_pos s = Fact.mk_pos (is_pos s)

  let map s =
    Fact.map (is_equal s, is_nonneg s, is_pos s)
	  
end

let simplify s =
  Trace.func "rule" "Simplify" Fact.pp Fact.pp
    (Fct.map s (Combine.can (config_of s)))

let abst s = 
  Trace.func "rule" "Abstract" Fact.pp Fact.pp
    (Fct.map s (abstract s))


(** Processing} *)

let rec process s ((atm, rho) as fct) =
  Trace.msg "rule" "Process" atm Atom.pp;
  match atm with
    | Atom.True -> ()
    | Atom.False -> 
	raise(Justification.Inconsistent(rho))
    | Atom.Equal(a, b) -> 
	process_equal s (Fact.Equal.make (a, b, rho))
    | Atom.Diseq(a, b) -> 
	process_diseq s (Fact.Diseq.make (a, b, rho))
    | Atom.Nonneg(a) -> 
	process_nonneg s (Fact.Nonneg.make (a, rho))
    | Atom.Pos(a) -> 
	process_pos s (Fact.Pos.make (a, rho))
	
and process_nonneg s c =
  Combine.process_nonneg (s.p, s.eqs) c

and process_pos s c = 
  Combine.process_pos (s.p, s.eqs) c

and process_diseq s d =
  if Fact.Diseq.is_diophantine d then
    Combine.process_diseq (s.p, s.eqs) d
  else 
    let d' = Fact.Diseq.map (name_of_term s) d in
      Partition.dismerge s.p d'

and process_equal s e =              
  match Fact.Equal.lhs_of e, Fact.Equal.rhs_of e with
    | Term.Var _, Term.Var _ -> 
	Partition.merge s.p e
    | Term.App(f, _), Term.Var _ -> 
	Combine.process_equal (s.p, s.eqs) (Th.of_sym f) e
    | Term.Var _, Term.App(f, _) -> 
	Combine.process_equal (s.p, s.eqs) (Th.of_sym f) e
    | Term.App(f, _), Term.App(g, _) ->
	let i = Th.of_sym f 
	and j = Th.of_sym g in
	  if i = j then 
	    Combine.process_equal (s.p, s.eqs) i e
	  else
	    let e' = Fact.Equal.map2 (name i s, name j s) e in
	      Partition.merge s.p e'

let process s =
  Trace.proc "rule" "Process" Fact.pp (process s)


(** {6 Close} *)

(** Propagate newly deduced facts. *)   
let rec close_star s =
  close_star_e s;
  close_star_d s

and close_star_e s =
  while not(Fact.Eqs.is_empty()) do
    close_e s (Fact.Eqs.pop())
  done

and close_e s (_, e) =
  Trace.msg "rule" "Close" e Fact.Equal.pp;
  if Fact.Equal.is_var e then
    Th.iter (fun j -> Combine.merge (s.p, s.eqs) j e)
  else if Fact.Equal.is_pure Th.a e then
    Combine.propagate (s.p, s.eqs) e (Th.a, Th.nl)

and close_star_d s = 
  while not(Fact.Diseqs.is_empty()) do
      close_d s (Fact.Diseqs.pop())
  done

and close_d s (i, d) = 
  Trace.msg "rule" "Close" d Fact.Diseq.pp; 
  let (a, b, _) = Fact.Diseq.destruct d in
  match i with
    | None -> 
	Th.iter (fun j -> Combine.dismerge (s.p, s.eqs) j d)
    | Some(i) ->
	Th.iter (fun j -> if not(i = j) then Combine.dismerge (s.p, s.eqs) j d)

  
(** Garbage collection. Remove all variables [x] which are are scheduled
 for removal in the partitioning. Check also that this variable [x] does
 not occur in any of the solution sets. Since [x] is noncanonical, this
 check only needs to be done for the [u] part, since all other solution
   sets are kept in canonical form. *)


let compactify = ref true

let rec normalize s =
  if !compactify then gc s

and gc s =
  let filter x =  
    not (Th.exists (fun i -> is_dependent i s x))
  in
    Partition.gc filter s.p


(** {6 Adding new atoms} *)

module Status = struct

  type 'a t = 
    | Valid of Justification.t
    | Inconsistent of Justification.t
    | Ok of 'a

  let pp_justification = ref true

  let pp pp fmt status =
    let ppj rho =
      if !pp_justification then
	begin
	  Format.fprintf fmt "\n";
	  Justification.pp fmt rho
	end
    in
      match status with
	| Valid(rho) -> 
	    Format.fprintf fmt ":valid"; ppj rho
	| Inconsistent(rho) -> 
	    Format.fprintf fmt ":unsat"; ppj rho
	| Ok(x) -> 
	    Format.fprintf fmt ":ok "; pp fmt x

end

let add s atm =
  let ((atm', rho') as fct) = 
    simplify s (Fact.mk_axiom atm)
  in
    if Atom.is_true atm' then
      Status.Valid(rho')
    else if Atom.is_false atm' then
      Status.Inconsistent(rho')
    else 
      let k' = !Term.Var.k in                  (* Save global variable. *)
	(try 
	   Term.Var.k := s.upper;
	   let s' = copy s in                  (* Protect state against updates *)
	     Fact.Eqs.clear();                 (* Clear out stacks before processing *)
	     Fact.Diseqs.clear();
	     process s' (abst s' fct);
             close_star s';
	     normalize s';
	     s'.ctxt <- Atom.Set.add atm s'.ctxt;
	     s'.upper <- !Term.Var.k;          (* Install variable counter. *)
	     Term.Var.k := k';                 (* Restore old value of variable counter. *)
	     Status.Ok(s')
	 with
	   | Justification.Inconsistent(rho) -> 
	       Term.Var.k := k';               (* Restore global variable. *)
	       Status.Inconsistent(rho)
	   | exc ->
	       Term.Var.k := k'; raise exc)


let add_unprotected s atm =
  let ((atm', rho') as fct) = 
    simplify s (Fact.mk_axiom atm)
  in
    if Atom.is_true atm' then
      Status.Valid(rho')
    else if Atom.is_false atm' then
      Status.Inconsistent(rho')
    else 
      (try 
	 Fact.Eqs.clear();                 (* Clear out stacks before processing *)
	 Fact.Diseqs.clear();
	 process s (abst s fct);
         close_star s;
	 normalize s;
	 s.ctxt <- Atom.Set.add atm s.ctxt;
	 Status.Ok(s)
       with
	 | Justification.Inconsistent(rho) -> 
	     Status.Inconsistent(rho))
