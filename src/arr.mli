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

(** Functional arrays decision procedure

  @author Harald Ruess
  @author N. Shankar
*)

type t
  (** Representing sets of equalities of the form [x = a]
    with [a] restricted to {i flat} array terms, that is [a]
    is an term application of the form [f(x1,...,xn)] with [f]
    a function symbol in the theory {!Th.arr} of arrays and
    all arguments are variables. *)

val eq : t -> t -> bool
  (** [eq s1 s2] succeeds if [s1] and [s2] are identical. If
    [eq s1 s2] holds, then [s1] and [s2] are logically equivalent. *)

val pp : t Pretty.printer
  (** Pretty-printing an array equality set} *)

val empty : t
  (** The empty array equality set. *)

val is_empty : t -> bool
  (** [is_empty s] succeeds iff [s] represents the empty equality set. *)


(** {6 Accessors} *)

val apply : t -> Jst.Eqtrans.t
  (** [apply s x] returns [a] if [x = a] is in [s]; otherwise
    [Not_found] is raised. *)

val find : t -> Jst.Eqtrans.t
  (** [find s x] returns [a] if [x = a] is in [s], and [x] otherwise. *)

val inv : t -> Jst.Eqtrans.t
  (** [inv s a] returns [x] if [x = a] is in [s]; otherwise
    [Not_found] is raised. *)

val dep : t -> Term.t -> Term.Var.Set.t
  (** [dep s y] returns the set of [x] such that [x = a] in [s]
    and [y] occurs in [a]. *)

val is_dependent : t -> Term.t -> bool
  (** [is_dependent s x] holds iff there is an [a] such that [x = a] in [s]. *)

val is_independent : t -> Term.t -> bool
  (** [is_independent s y] holds iff [y] occurs in some [a] such that
    [x = a] in [s]. *)


type config = Partition.t * t
    (** A {i configuration} consists of a pair [(p, s)] with
      [p] a partitioning and [s] an array equality set. *)

val interp : config -> Jst.Eqtrans.t
val uninterp : config -> Jst.Eqtrans.t


(** {6 Iterators} *)

val fold : (Term.t -> Term.t * Jst.t -> 'a -> 'a) -> t -> 'a -> 'a
  (** [fold f s e] applies [f x (a, rho)] for each [x = a] with justification
    [rho] in [s] and accumulates the result starting with [e]. The order of
    application is unspecified. *)


(** {6 Processing} *)

val copy : t -> t
  (** The update functions {!Arr.name}, {!Arr.merge},
    and {!Arr.dismerge} {b destructively} update equality
    sets. The function [copy s] can be used to protect state [s]
    against these updates. *)

    
val name : config -> Jst.Eqtrans.t
  (** [name (p, s) a] returns a canonical variable [x] 
    with [x = a] in [s].  If there is no such variable,
    it creates a fresh variable [v] and updates [s] to 
    include the equality [v = a]. *)


val merge : config -> Fact.Equal.t -> unit
  (** [merge (p, s) e] conjoins an array solution
    set [s] with an equality [e] over {i flat} array terms.
    If [e] conjoined with [s] and [p] is {i inconsistent},
    then {!Jst.Inconsistent} is raised.  Besides 
    {i destructively} updating [s], all generated variable 
    equalities and disequalities are propagated into the 
    partitioning [p].  Notice, however, that not all variable
    equalities implied by [e] conjoined with
    [p] and [s] are generated. Also, a full case split over
    the variable pairs generated by {!Arr.split} is needed
    in general to detect every inconsistency. *)

    
val dismerge : config -> Fact.Diseq.t -> unit
 (** [dismerge (p, s) d] conjoins an array solution
   set [s] with a disequality [d] over variables.
   If [d] conjoined with [s] and [p] is {i inconsistent},
   then {!Jst.Inconsistent} is raised.  Besides 
   {i destructively} updating [s], all generated variable 
   equalities and disequalities are propagated into the 
   partitioning [p].  Notice, however, that not all variable
   equalities implied by [d] conjoined with
   [p] and [s] are generated.  Also, a full case split over
   the variable pairs generated by {!Arr.split} is needed
   in general to detect every inconsistency. *)


val split : config -> Term.t * Term.t
  (** [split (p, s)] generates a case splits necessary
    to make the procedure complete for the theory of arrays. 
    Here, a pair of variables [(i, j)] represents a case split
    on [i = j] or [i <> j]. *)






