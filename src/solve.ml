(*i*)
open Term
open Hashcons
(*i*)

let arith_solve x s (a,b) =
  let is_int a =
    Cnstrnt.is_int(State.cnstrnt s a)
  in
  if Arith.is_diophantine is_int a && Arith.is_diophantine is_int b then
    let (kl,rho) = Arith.zsolve (a,b) in
    rho @ (List.map (fun k -> (Cnstrnt.app Cnstrnt.int k, Bool.tt ())) kl)
  else
    Arith.qsolve x (a,b)


let set_solve s e =
  match Sets.solve 0 e with
    | Some l -> l
    | None -> raise(Exc.Inconsistent "Set solver")

let tuple_solve s e =
  match Tuple.solve e with
    | Some l -> l
    | None -> raise(Exc.Inconsistent "Tuple solver")

let bv_solve s e =
  match Bv.solve e with
    | Some l -> l
    | None -> raise(Exc.Inconsistent "Tuple solver")

let bool_ite_solve e =
  match Bool.solve e with
    | Some l -> l
    | None -> raise(Exc.Inconsistent "Bool solver")
  

let solve x s e =
  let rec solvel rho el =
    match el with
    | [] -> rho
    | (a,b) :: el -> 
	Trace.call 5 "Solve(rec)" (a,b) Pretty.eqn;
	let rho' = solve1 rho (a,b) el in
	Trace.exit 5 "Solve(rec)" rho' Subst.pp;
	rho'

  and solve_equal rho (a1,a2) b el =              (*s Solve equations of the form [(a1 = a2) = b] *)
    match b.node with
      | Bool(True) ->
	  solvel rho ((a1,a2) :: el)
      | Bool(False) ->
	  solve_diseq rho (a1,a2) el
      | Bool(Equal(b1,b2)) ->                     (*s to do: check for trivial inconsistencies etc. *)
	  let rho' = Subst.add (Bool.equal a1 a2) b rho in
	  solvel rho' el
      | Bool(Ite _) ->
	  let a = Bool.equal a1 a2 in
	  if Term.occurs_interpreted a b then
	    solvel rho (bool_ite_solve (a,b) @ el)
	  else
	    solvel (Subst.add a b rho) el
      | _ ->
	  solvel (Subst.add b (Bool.equal a1 a2) rho) el

  and solve_diseq rho (a,b) el =                (* Solve disequalities [a <> b]. *)
    match a.node, b.node with
      | Arith(Num q1), Arith(Num q2) ->
	  if Mpa.Q.equal q1 q2 then
	    raise(Exc.Inconsistent "Inconsistent constants")
	  else
	    solvel rho el
      | Arith(Num q1), _ -> 
	  solvel (Subst.add (Cnstrnt.app (Cnstrnt.diseq q1) b) (Bool.tt()) rho) el
      | _, Arith(Num q2) -> 
	  solvel (Subst.add (Cnstrnt.app (Cnstrnt.diseq q2) a) (Bool.tt()) rho) el
      | _ ->
	  solvel (Subst.add (Bool.equal a b) (Bool.ff()) rho) el

  and bool_solve rho (a,b) el =
    match a with
      | True -> true_solve rho b el
      | False -> false_solve rho b el
      | Equal(x,y) -> solve_equal rho (x,y) b el
      | Ite _ -> solvel rho (bool_ite_solve (hc(Bool(a)),b) @ el)
      | _ -> assert false

  and true_solve rho b el =      (*s Solve equations of the form [true = b] *)  
    match b.node with
      | Bool(True) -> 
	  solvel rho el
      | Bool(False) ->
	  raise(Exc.Inconsistent "Different constants.")
      | Bool(Equal(x,y)) ->
	  solvel rho ((x,y) :: el)
      | Bool(Ite _) ->
	  solvel rho (bool_ite_solve(b,Bool.tt()) @ el)
      | App({node=Set(Cnstrnt(c))}, [x]) ->
	  cnstrnt_solve rho c x el
      | _ ->
	  solvel (Subst.add b (Bool.tt()) rho) el

  and false_solve rho b el =  (*s Solve equations of the form [false = b] *)
    match b.node with
      | Bool(False) ->
	  solvel rho el
      | Bool(True) ->
	  raise(Exc.Inconsistent "Different constants.")
      | Bool(Equal(x,y)) ->
	  solve_diseq rho (x,y) el
      | App({node=Set(Cnstrnt(c))}, [x]) ->
	  cnstrnt_solve rho (Cnstrnt.compl c) x el
      | Bool(Ite _) ->
	   solvel rho (bool_ite_solve(b,Bool.ff()) @ el)
      | _ ->
	  solvel (Subst.add b (Bool.tt()) rho) el 
	
  and cnstrnt_solve rho c x el =               (* solve equalities of the form [(x in c) = true] *)
    match x.node with
      | Arith(Multq _ | Mult _ | Div _ | Add _) -> 
	  let k = Var.create "z" in
	  (match Arith.qsolve None (k,x) with
	     | [(a,b)] -> 
		 solvel (Subst.add a b (Subst.add (Cnstrnt.app c k) (Bool.tt()) rho)) el
	     | _ -> assert false)
      | _ ->
	  solvel (Subst.add (Cnstrnt.app c x) (Bool.tt()) rho) el
    
  and solve1 rho (a,b) el =
	let a' = Subst.norm rho a and b' = Subst.norm rho b in
	if a' === b' then
	  solvel rho el
	else match a'.node,b'.node with
	  | Bool x, _ ->
	      bool_solve rho (x,b) el
	  | _, Bool y ->
	      bool_solve rho (y,a) el
	  | Update (u,i,s), Update (v,j,t) when u === v && i === j ->
	      if u === v && i === j then
		solvel rho ((s,t) :: el)
	      else
		solvel (Subst.add a' b' rho) el
	  | (Var _ | App _ | Update _ | Arith(Mult _) | Arith(Div _) | Bv(BvToNat _) | Set(Finite _) | Set(Cnstrnt _)) , _  when not(Term.occurs_interpreted a' b') ->
		solvel (Subst.add a' b' rho) el
	  | Arith(Num _ | Multq _ | Add _), _ ->
	      solvel rho (arith_solve x s (a,b) @ el)
	  | _, Arith(Num _ | Multq _ | Add _) ->
	      solvel rho (arith_solve x s (b,a) @ el)
	  | Set _, _ ->
	      solvel rho (set_solve s (a,b) @ el)
	  | _, Set _ ->
	      solvel rho (set_solve s (b,a) @ el)
	  | Tuple _, _ ->
	      solvel rho (tuple_solve s (a,b) @ el)
	  | _, Tuple _ ->
	      solvel rho (tuple_solve s (b,a) @ el)
	  | Bv _, _ ->
	      solvel rho (bv_solve s (a,b) @ el)
	  | _, Bv _ ->
	      solvel rho (bv_solve s (b,a) @ el)
	  | _ -> assert false
		
  in
  solvel Subst.empty [e]
   
let solve x s ((a,b) as e) =
  Trace.call 3 "Solve" e Pretty.eqn;
  try
    let rho = solve x s e in
    (* assert(Subst.norm rho a === Subst.norm rho b); *)
    Trace.exit 3 "Solve" rho Subst.pp;
    rho
  with
      Exc.Inconsistent str ->
	Trace.exc 3 "Solve" e Pretty.eqn;
	raise (Exc.Inconsistent str)










