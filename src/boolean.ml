
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

(*s Boolean constants. *)

let mk_true = Term.mk_const Sym.mk_true
let mk_false = Term.mk_const Sym.mk_false

let is_true a = Term.eq a mk_true
let is_false a = Term.eq a mk_false

let is_interp a = is_true a || is_false a

let sigma f l =
  match f, l with
    | Sym.True, [] -> mk_true
    | Sym.False, [] -> mk_false
    | _ -> assert false

let solve (a,b) =
  if Term.eq a b then []
  else if is_true a && is_false b then
    raise Exc.Inconsistent
  else if is_false a && is_true b then
    raise Exc.Inconsistent
  else if is_interp a then
    [(b,a)]
  else if is_interp b then
    [(a,b)]
  else 
    [Term.orient (a,b)]
