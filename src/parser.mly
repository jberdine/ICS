
/*
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
 */

/*s Module [Parser]: parser for ICS syntactic categories. */

%{
  open Mpa
  open Tools

let out = Istate.outchannel

let pr str =  Format.fprintf (out()) str

let nl () = pr "\n"

let equal_width_of a b =
 match Istate.width_of a, Istate.width_of a with
   | Some(n), Some(m) when n = m -> n
   | Some(n), None -> n
   | None, Some(n) -> n
   | Some _, Some _ ->
       raise (Invalid_argument "Argument mismatch")
   | None, None -> 
       raise (Invalid_argument (Term.to_string a ^ " not a bitvector."))

let lastresult = ref(Result.Unit())

let name_of_nonstrict_slack = Name.of_string "k"
let name_of_strict_slack = Name.of_string "l"


%}

%token DROP CAN ASSERT EXIT SAVE RESTORE REMOVE FORGET RESET SYMTAB SIG VALID UNSAT
%token TYPE SIGMA
%token SOLVE HELP DEF PROP TOGGLE SET TRACE UNTRACE CMP FIND USE INV SOLUTION PARTITION MODEL
%token SHOW SIGN DOM SYNTAX COMMANDS SPLIT SAT ECHO
%token DISEQ CTXT 
%token IN TT FF DEF
%token EOF

%token ARITH TUPLE

%token <string> IDENT
%token <string> STRING
%token <int> INTCONST
%token <Mpa.Q.t> RATCONST
%token <Name.t> PROPVAR

%token IN
%token BOT INT REAL BV TOP
%token INF NEGINF
%token ALBRA ACLBRA CLBRA

%token LPAR RPAR LBRA RBRA LCUR RCUR PROPLPAR PROPRPAR UNDERSCORE KLAMMERAFFE
%token COLON COMMA DOT DDOT ASSIGN UNION TO ENDMARKER BACKSLASH

%token <string> BVCONST 
%token <string * int> FRESH
%token <int> FREE

%token CONC SUB BWITE BWAND BWOR BWXOR BWIMP BWIFF BWNOT
%token BVCONC 
%token EQUAL DISEQ
%token TRUE FALSE
%token PLUS MINUS TIMES DIVIDE EXPT
%token LESS GREATER LESSOREQUAL GREATEROREQUAL  
%token UNSIGNED APPLY LAMBDA
%token WITH CONS CAR CDR NIL
%token INL INR OUTL OUTR
%token INJ OUT 
%token HEAD TAIL LISTCONS
%token PROPVAR DISJ XOR IMPL BIIMPL CONJ NEG
%token IF THEN ELSE END
%token PROJ
%token CREATE

%right DISJ XOR IMPL
%left BIIMPL CONJ
%nonassoc EQUAL DISEQ LESS GREATER LESSOREQUAL GREATEROREQUAL
%left APPLY
%left UNION
%left MINUS PLUS 
%left DIVIDE
%left TIMES
%right EXPT
%left LISTCONS
%right BVCONC
%right BWOR BWXOR BWIMP
%left BWAND BWIFF
%nonassoc TO
%nonassoc IN NOTIN
%nonassoc LCUR
%nonassoc LBRA
%nonassoc prec_unary

%type <Term.t> termeof
%type <Atom.t> atomeof
%type <Result.t> commands
%type <Result.t> commandseof
%type <unit> commandsequence


%start termeof
%start atomeof
%start commands
%start commandsequence
%start commandseof



%%

termeof : term EOF           { $1 }
atomeof : atom EOF           { $1 }
commandseof : command EOF    { $1 }

commands : command DOT       { $1 }
| EOF                        { raise End_of_file }

commandsequence :
  command DOT commandsequence    {  lastresult := $1 }
| command DOT EOF                { lastresult := $1; raise(Result.Result(!lastresult)) }

    
int: 
  INTCONST  { $1 }

rat:
  int       { Q.of_int $1 }
| RATCONST  { $1 }
;


name: IDENT            { Name.of_string $1 }

namelist : name        { [$1] }
| namelist COMMA name  { $3 :: $1 }

funsym: 
  name                                   { Sym.Uninterp($1) }
| PLUS                                   { Sym.Arith(Sym.Add) }
| TIMES                                  { Sym.Pp(Sym.Mult) }
| EXPT LBRA int RBRA                     { Sym.Pp(Sym.Expt($3)) }
| CONS                                   { Sym.Pair(Sym.Cons) }
| CAR                                    { Sym.Pair(Sym.Car) }
| CDR                                    { Sym.Pair(Sym.Cdr) }
| UNSIGNED                               { Sym.Bvarith(Sym.Unsigned) }
| CONC LBRA INTCONST COMMA INTCONST RBRA               { Sym.Bv(Sym.Conc($3, $5)) }
| SUB LBRA INTCONST COMMA INTCONST COMMA INTCONST RBRA { Sym.Bv(Sym.Sub($3, $5, $7)) }
| BWITE LBRA INTCONST RBRA                             { Sym.Bv(Sym.Bitwise($3)) }
| APPLY range                            { Sym.Fun(Sym.Apply($2)) }
| LAMBDA                                 { Sym.Fun(Sym.Abs) }
;

range:                              { None }

constsym: 
  rat       { Sym.Arith(Sym.Num($1)) }
| TRUE      { Sym.Bv(Sym.Const(Bitv.from_string "1")) }
| FALSE     { Sym.Bv(Sym.Const(Bitv.from_string "0")) }  
| BVCONST   { Sym.Bv(Sym.Const(Bitv.from_string $1)) }
;



term:
  var              { $1 }
| app              { $1 }
| LPAR term RPAR   { $2 }
| arith            { $1 }     /* infix/mixfix syntax */
| array            { $1 }
| bv               { $1 }
| coproduct        { $1 }
| list             { $1 }
| apply            { $1 }
;

var:
  name  { try
	    match Symtab.lookup $1 (Istate.symtab()) with
	      | Symtab.Def(Symtab.Term(a)) -> a
	      | Symtab.Type(d)  -> Term.mk_var $1 (Some(d))
	      | _ -> Term.mk_var $1 None
	  with
	      Not_found -> Term.mk_var $1 None }
| name LCUR dom RCUR { Term.mk_var $1 (Some($3))}
| FRESH optdom  { let (x, k) = $1 in 
		  let n = Name.of_string x in
		    if Name.eq n name_of_strict_slack then
		      Term.mk_slack (Some(k)) false $2
		    else if Name.eq n name_of_nonstrict_slack then
		      Term.mk_slack (Some(k)) true $2
		    else 
		      Term.mk_rename n (Some(k)) $2 }
| FREE   { Term.Var(Var.mk_free $1) }
;

varlist : var        { [$1] }
| varlist COMMA var  { $3 :: $1 }


optdom:   { None }
| LCUR dom RCUR { Some($2) }


app: 
  funsym LPAR termlist RPAR     { Th.sigma $1 (List.rev $3) }
| constsym                      { Th.sigma $1 [] }

list: 
  term LISTCONS term            { Coproduct.mk_inj 1 (Pair.mk_cons $1 $3) }
| HEAD LPAR term RPAR           { Pair.mk_car (Coproduct.mk_out 1 $3) }
| TAIL LPAR term RPAR           { Pair.mk_cdr (Coproduct.mk_out 1 $3) }
| NIL                           { Coproduct.mk_inj 0 (Bitvector.mk_eps) }

apply: 
  term APPLY term               { Apply.mk_apply
				    Th.sigma
                                     None $1 [$3] }

     
arith:
| term PLUS term                { Arith.mk_add $1 $3 }
| term MINUS term               { Arith.mk_sub $1 $3 }
| MINUS term %prec prec_unary   { Arith.mk_neg $2 }
| term TIMES term               { Sig.mk_mult $1 $3 }
| term DIVIDE term              { Sig.mk_div $1 $3 }
| term EXPT int                 { Sig.mk_expt $3 $1 }
;

coproduct:
  INL LPAR term RPAR                    { Coproduct.mk_inl $3 }
| INR LPAR term RPAR                    { Coproduct.mk_inr $3 }
| OUTL LPAR term RPAR                   { Coproduct.mk_outl $3 }
| OUTR LPAR term RPAR                   { Coproduct.mk_outr $3 }
| INJ LBRA INTCONST RBRA LPAR term RPAR { Coproduct.mk_inj $3 $6 }
| OUT LBRA INTCONST RBRA LPAR term RPAR { Coproduct.mk_out $3 $6 }


array:
  CREATE LPAR term RPAR      { Arr.mk_create $3 }
| term LBRA term ASSIGN term RBRA { Arr.mk_update Istate.is_equal $1 $3 $5 }
| term LBRA term RBRA        { Arr.mk_select Istate.is_equal $1 $3 }
;


bv:
  term BVCONC term   { match Istate.width_of $1, Istate.width_of $3 with
			  | Some(n), Some(m) -> 
			      if n < 0 then
				raise (Invalid_argument ("Negative length of " ^ Term.to_string $1))
			      else if m < 0 then
				raise (Invalid_argument ("Negative length of " ^ Term.to_string $3))
			      else 
				Bitvector.mk_conc n m $1 $3
			  | Some _, _ -> 
			      raise (Invalid_argument (Term.to_string $3 ^ " not a bitvector."))
			  | _ -> 
			      raise (Invalid_argument (Term.to_string $1 ^ " not a bitvector.")) }
| term LBRA INTCONST COLON INTCONST RBRA 
                      { match Istate.width_of $1 with
			  | Some(n) -> 
			      if n < 0 then
				raise(Invalid_argument ("Negative length of " ^ Term.to_string $1))
			      else if not(0 <= $3 && $3 <= $5 && $5 < n) then
				raise(Invalid_argument ("Invalid extraction from " ^ Term.to_string $1))
			      else 
				Bitvector.mk_sub n $3 $5 $1
			  | None ->  
			      raise (Invalid_argument (Term.to_string $1 ^ " not a bitvector.")) }
| term BWAND term     { Bitvector.mk_bwconj (equal_width_of $1 $3) $1 $3 }
| term BWOR term      { Bitvector.mk_bwdisj (equal_width_of $1 $3) $1 $3 }
| term BWIMP term     { Bitvector.mk_bwimp (equal_width_of $1 $3) $1 $3 }
| term BWIFF term     { Bitvector.mk_bwiff (equal_width_of $1 $3) $1 $3 }
;

prop:
  LPAR prop RPAR                { $2 } 
| LBRA prop RBRA                { $2 } 
| name                            { try
				      match Symtab.lookup $1 (Istate.symtab()) with
					| Symtab.Def(Symtab.Prop(p)) -> p
					| _ -> Prop.mk_var $1
				      with
					  Not_found -> Prop.mk_var $1 }
| atom                            { Prop.mk_poslit $1 }
| prop CONJ prop                  { Prop.mk_conj [$1; $3] }
| prop DISJ prop                  { Prop.mk_disj [$1; $3] }
| prop BIIMPL prop                { Prop.mk_iff $1 $3 }
| prop XOR prop                   { Prop.mk_neg (Prop.mk_iff $1 $3) }
| prop IMPL prop                  { Prop.mk_disj [Prop.mk_neg $1; $3] }
| NEG prop %prec prec_unary       { Prop.mk_neg $2 }
| IF prop THEN prop ELSE prop END { Prop.mk_ite $2 $4 $6 }
;

atom: 
  FF                       { Atom.mk_false }
| TT                       { Atom.mk_true }
| term EQUAL term          { Atom.mk_equal($1, $3)}
| term DISEQ term          { Atom.mk_diseq($1, $3) }
| term LESS term           { Atom.mk_lt ($1, $3) }
| term GREATER term        { Atom.mk_gt ($1, $3) }
| term LESSOREQUAL term    { Atom.mk_le ($1, $3) }
| term GREATEROREQUAL term { Atom.mk_ge ($1, $3) }


dom:
  INT          { Dom.Int }
| REAL         { Dom.Real }
;


termlist:             { [] }
| term                { [$1] }
| termlist COMMA term { $3 :: $1 }
;

signature:
  BV LBRA INTCONST RBRA     { $3 }
;

command: 
  CAN term                  { Result.Term(Istate.can $2) }
| ASSERT optname atom       { Result.Process(Istate.process $2 $3) }
| DEF name ASSIGN term      { Result.Unit(Istate.def $2 (Symtab.Term($4))) }
| PROP name ASSIGN prop     { Result.Unit(Istate.def $2 (Symtab.Prop($4))) }
| SIG name COLON dom        { Result.Unit(Istate.typ [$2] $4) }
| SIG name COLON signature  { Result.Unit(Istate.sgn $2 $4) }
| RESET                     { Result.Unit(Istate.reset ()) }
| SAVE name                 { Result.Name(Istate.save(Some($2))) }
| SAVE                      { Result.Name(Istate.save(None)) }        
| RESTORE name              { Result.Unit(Istate.restore $2) }
| REMOVE name               { Result.Unit(Istate.remove $2) }
| FORGET                    { Result.Unit(Istate.forget()) }
| VALID optname atom        { Result.Bool(Istate.valid $2 $3) }
| UNSAT optname atom        { Result.Bool(Istate.unsat $2 $3) }
| EXIT                      { raise End_of_file }
| DROP                      { failwith "drop" }
| SYMTAB                    { Result.Symtab(Istate.symtab()) }
| SYMTAB name               { match Istate.entry_of $2 with
				| Some(e) -> Result.Entry(e)
				| None -> raise (Invalid_argument (Name.to_string $2 ^ "not in symbol table")) }
| CTXT optname              { Result.Atoms(Istate.ctxt_of $2) }
| SIGMA term                { Result.Term($2) }
| term CMP term             { Result.Int(Term.cmp $1 $3) }
| SHOW optname              { Result.Context(Istate.get_context $2) }
| FIND optname th term      { Result.Term(Istate.find $2 $3 $4) }
| INV optname th term       { try Result.Optterm(Some(Istate.inv $2 $3 $4))
		 	      with Not_found -> Result.Optterm(None) }
| USE optname th term       { Result.Terms(Istate.use $2 $3 $4) }
| SIGN optname term         { Result.Cnstrnt(Istate.sign $2 $3) }
| DOM optname term          { Result.Dom(Istate.dom $2 $3) }
| DISEQ optname term        { Result.Terms(Istate.diseq $2 $3) }
| SPLIT optname             { Result.Atoms(Istate.split()) }
| SOLVE th term EQUAL term  { Result.Solution(Istate.solve $2 ($3, $5)) }		
| TRACE identlist           { Result.Unit(List.iter Trace.add $2) }
| UNTRACE                   { Result.Unit(Trace.reset ()) }
| SAT prop                  { Result.Sat(Istate.sat $2) }
| MODEL optname varlist     { Result.Solution(Istate.model $2 $3) }
| ECHO STRING               { Result.Unit(Format.eprintf "%s@." $2) }
| help                      { Result.Unit($1) }
;
  

identlist :
  IDENT                     { [$1] }
| identlist COMMA IDENT     { $3 :: $1 }

		
th: IDENT  { Th.of_string $1 } /* may raise [Invalid_argument]. */

help:
  HELP                      { Help.on_help () }
| HELP SYNTAX               { Help.syntax () }
| HELP COMMANDS             { Help.commands () }
;


optname:                    { None }
| KLAMMERAFFE name          { Some($2) }
;


%%
