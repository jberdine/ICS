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

(** Lexical analysis for ICS syntactic categories such as terms.
  @author Jean-Christophe Filliatre
  @author Harald Ruess
*)

{
open Parser

(** A lexer for terms. *)

let keyword =
  let kw_table = Hashtbl.create 31 in
  List.iter 
    (fun (s,tk) -> Hashtbl.add kw_table s tk)
    [ "arith", ARITH; "tuple", TUPLE;
      "in", IN; "inf", INF;
      "bot", BOT; "int", INT; "real", REAL; "top", TOP;
      "bitvector", BV; "with", WITH;
      "proj", PROJ;
      "cons", CONS; "car", CAR; "cdr", CDR;
      "conc", CONC; "sub", SUB; "ite", BWITE;
      "drop", DROP; "can", CAN; "assert", ASSERT; "exit", EXIT; 
      "valid", VALID; "unsat", UNSAT;
      "save", SAVE; "restore", RESTORE; "remove", REMOVE; "forget", FORGET;
      "reset", RESET; "sig", SIG; "type", TYPE; "def", DEF; "prop", PROP;
      "sigma", SIGMA; "solve", SOLVE; "help", HELP;
      "set", SET; "toggle", TOGGLE; "trace", TRACE;  "untrace", UNTRACE; 
      "find", FIND; "inv", INV; "use", USE; "solution", SOLUTION; "partition", PARTITION;
      "syntax", SYNTAX; "commands", COMMANDS; "ctxt", CTXT; "diseq", DISEQ; "echo", ECHO;
      "show", SHOW; "symtab", SYMTAB; "sign", SIGN; "dom", DOM; "split", SPLIT; "sat", SAT;
      "true", TRUE; "false", FALSE;
      "tt", TT; "ff", FF;
      "inr", INR; "inl", INL; "outr", OUTR; "outl", OUTL;
      "inj", INJ; "out", OUT;
      "hd", HEAD; "tl", TAIL;
      "unsigned", UNSIGNED; "apply", APPLY;
      "lambda", LAMBDA;
      "if", IF; "then", THEN; "else", ELSE; "end", END;
      "create", CREATE
    ];
  fun s ->
    try Hashtbl.find kw_table s with Not_found -> IDENT s

}

let ident = ['A'-'Z' 'a'-'z'] ['A'-'Z' 'a'-'z' '\'' '_' '0'-'9']*

let int =  ['0'-'9']+  

rule token = parse 
    [' ' '\t'] { token lexbuf }
  | '\n'       { Tools.linenumber := !Tools.linenumber + 1;
  	         token lexbuf }
  | '%' [^ '\n']* {token lexbuf }
  | ident      { keyword (Lexing.lexeme lexbuf) }
  | "-inf"     { NEGINF }
  | ['0'-'9']+ { INTCONST (int_of_string (Lexing.lexeme lexbuf)) }
  | ['0'-'9']+ '/' ['0'-'9']+ 
               { RATCONST (Mpa.Q.of_string (Lexing.lexeme lexbuf)) }
  | '-' ['0'-'9']+ '/' ['0'-'9']+ 
               { let s = Lexing.lexeme lexbuf in
		   RATCONST(Mpa.Q.of_string (String.sub s 1 (String.length s - 1))) }
  | "0b" ['0'-'1']*
               { let s = Lexing.lexeme lexbuf in 
		 BVCONST (String.sub s 2 (String.length s - 2)) }
  | ident '!' int  { let s = Lexing.lexeme lexbuf in
		     let n = String.length s in
                     let i = String.rindex s '!' in
                     let x = String.sub s 0 i in
		     let k = int_of_string (String.sub s (i + 1) (n - i - 1)) in
		       FRESH (x, k) }
  | '!' int    { let s = Lexing.lexeme lexbuf in
		 let n = String.length s in
		 let k = int_of_string (String.sub s 1 (n - 1)) in
		   FREE k }
  | '"' [^ '"']* '"' { STRING(Lexing.lexeme lexbuf) }
  | ','        { COMMA }
  | '('        { if !Tools.mode = Tools.Prop then PROPLPAR else LPAR }
  | ')'        { if !Tools.mode = Tools.Prop then PROPRPAR else RPAR }
  | '['        { LBRA }
  | ']'        { RBRA }
  | '{'        { LCUR }
  | '}'        { RCUR }
  | '+'        { PLUS }
  | '-'        { MINUS }
  | '*'        { TIMES }
  | '/'        { DIVIDE }
  | '\\'       { BACKSLASH }
  | '='        { EQUAL }
  | ":="       { ASSIGN }
  | "<>"       { DISEQ }
  | "<"        { LESS }
  | "<="       { LESSOREQUAL }
  | ">"        { GREATER }
  | ">="       { GREATEROREQUAL }
  | "->"       { TO }
  | ':'        { COLON }
  | '^'        { EXPT }
  | ".."       { DDOT }
  | "++"       { BVCONC }
  | "&&"       { BWAND }
  | "||"       { BWOR }
  | "##"       { BWXOR }
  | '&'        { CONJ }
  | '|'        { DISJ }
  | '#'        { XOR }
  | "<=>"      { BIIMPL }
  | "=>"       { IMPL }
  | '~'        { NEG }
  | '_'        { UNDERSCORE } 
  | "<<"       { CMP }
  | "::"       { LISTCONS }
  | "[]"       { NIL }
  | '.'        { DOT }
  | '$'        { APPLY }
  | '@'        { KLAMMERAFFE } 
  | eof        { EOF }
  | _          { raise Parsing.Parse_error }
