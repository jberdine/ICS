
(*i
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
 * Author: Harald Ruess, N. Shankar
i*)

(*s Module [V]: Equalities over variables. *)

type t

(*s [partition s] returns a partitioning of the set of variables
 in the form of a map with a domain consisting of canonical
 representatives and the corresponding equivalence class in
 the codomain. *)

val partition : t -> Term.Set.t Term.Map.t

(*s Remove all internal variables. *)

val external_of : t -> t

(*s [find s x] returns the canonical representative of [x]
 with respect ot the partitioning of the variables in [s].
 In addition, [find'] performs dynamic path compression as
 a side effect. *)

val find : t -> Term.t -> Term.t

val find' : t -> Term.t -> t * Term.t

(*s Variable equality modulo [s]. *)

val eq : t -> Term.t -> Term.t -> bool

(*s The empty context. *)

val empty : t


(*s A representation of the set of variables whose [find] changes. *)

type focus

module Focus: sig
  val empty : focus
  val is_empty : focus -> bool
  val singleton : Term.t * t -> focus
  val add : Term.t * t ->  focus -> focus
  val union : focus -> focus -> focus
  val fold : (Term.t -> 'a -> 'a) -> focus -> 'a -> 'a
end

(*s Adding a variable equality [x = y] to a context [s]. *)

val merge : Fact.equal -> t -> t * focus

(*s Pretty-printing. *)

val pp : t Pretty.printer

(*s Folding over the members of a specific equivalence class. *)

val fold : t -> (Term.t -> 'a -> 'a) -> Term.t -> 'a -> 'a

(*s Iterate over the extension of an equivalence class. *)

val iter : t -> (Term.t -> unit) -> Term.t -> unit

(*s [exists s p x] holds if [p y] holds for some [y] congruent
 to [x] modulo [s]. *)

val exists : t -> (Term.t -> bool) -> Term.t -> bool

(*s [for_all s p x] holds if [p y] holds for all [y] congruent
 to [x] modulo [s]. *)

val for_all : t -> (Term.t -> bool) -> Term.t -> bool

(*s [choose s p x] chooses a [y] which is congruent to [x] modulo [s]
  which satisfies [p]. If there is no such [y], the exception [Not_found]
  is raised. *)

val choose : t -> (Term.t -> bool) -> Term.t -> Term.t
