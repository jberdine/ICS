
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
 * Author: Harald Ruess
 i*)

(*s Module [C]:  Database for onstraint declarations of the 
 form [x |-> c] where [x] is an uninterpreted term and [c] is
 a numerical constraint. *)
  
type t

(*s [mem x s] tests if there are conditions associated with variable [x]. *)

val mem : Term.t -> t -> bool

(*s Constraint context as a list. *)

val to_list : t -> (Term.t * Cnstrnt.t) list

(*s Accessors. *)

val cnstrnt : t -> Term.t -> Cnstrnt.t

(*s Pretty-printing. *)

val pp : t Pretty.printer


(*s Empty constraint map. *)

val empty : t


(*s Test for emptyness. *)

val is_empty : t -> bool


(*s Extend domain of constraint table. *)

val extend : Term.t * Cnstrnt.t -> t -> t


(*s Restricting domain of constraint table. *)

val restrict : Term.t -> t -> t


(*s [add (a,c) s] adds a constraint [a in c] to [s]. *)

val add : Term.t * Cnstrnt.t -> t -> t * (Term.t * Term.t) list
