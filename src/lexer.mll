
(*i
 * ICS - Integrated Canonizer and Solver
 * Copyright (C) 2001-2004 SRI International
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the ICS license as published at www.icansolve.com
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * ICS License for more details.
 i*)

(*s Module [Lexer]: lexical analysis for ICS command interpreter. *)

(*i*)
{
open Lexing
open Parser
(*i*)

(*s A lexer for terms. *)

let keyword =
  let kw_table = Hashtbl.create 17 in
  List.iter 
    (fun (s,tk) -> Hashtbl.add kw_table s tk)
    [ "can", CAN; "simp", SIMP; "sigma", SIGMA; "solve", SOLVE; "solution", SOLUTION; "reset", RESET;
      "for", FOR; "drop", DROP; "assert", ASSERT; "find", FIND; "ext", EXT; "current", CURRENT;
      "use", USE;
      "uninterp", UNINTERP;
      "check", CHECK; "verbose", VERBOSE; "norm", NORM; "ctxt", CTXT;
      "commands", COMMANDS; "syntax", SYNTAX;
      "cnstrnt", CNSTRNT; "help", HELP;
      "proj", PROJ; "floor", FLOOR;
      "int", INT; "real", REAL; "nonintreal", NONINTREAL;
      "neg", NEG; "nonneg", NONNEG; "pos", POS;
      "nonpos", NONPOS;
      "in", IN; "notin", NOTIN; "compl", COMPL; "inter", INTER; "union", UNION; "sub", SUB;
      "diff", DIFF; "symdiff", SYMDIFF; "empty", EMPTY; "full", FULL;
      "unsigned", UNSIGNED;
      "true", TRUE; "false", FALSE; "if", IF; "then", THEN; "else", ELSE; "end", END;
      "setif", SETIF; "bvif", BVIF;
      "conc", BV_CONC; "extr", BV_EXTR; "bvor", BV_OR; "bvand", BV_AND; "bvxor", BV_XOR; "bvcompl", BV_COMPL;
      "integer", INTEGER_PRED;
      "forall", FORALL; "exists", EXISTS
    ];
  fun s ->
    try Hashtbl.find kw_table s with Not_found -> IDENT s

(*i*)
}
(*i*)

(*s The lexer it-self is quite simple. *)

let ident = ['A'-'Z' 'a'-'z'] ['A'-'Z' 'a'-'z' '\'' '0'-'9']*

let space = [' ' '\t' '\r' '\n']

rule token = parse
  | space+     { token lexbuf }
  | '%' [^ '\n']* {token lexbuf }
  | "-inf"     { NEGINF }
  | "inf"      { POSINF }
  | ident      { keyword (lexeme lexbuf) }
  | ['0'-'9']+ { INTCONST (int_of_string (lexeme lexbuf)) }
  | ['0'-'9']+ '/' ['0'-'9']+ { RATCONST (Ics.num_of_string (lexeme lexbuf)) }
  | "0b" ['0'-'1']+ { let s = lexeme lexbuf in 
		      BV_CONST (String.sub s 2 (String.length s - 2)) }
  | ','        { COMMA }
  | '('        { LPAR }
  | ')'        { RPAR }
  | '['        { LBRA }
  | ']'        { RBRA }
  | '{'        { LCUR }
  | '}'        { RCUR }
  | '+'        { PLUS }
  | '-'        { MINUS }
  | '*'        { TIMES }
  | '/'        { DIVIDE }
  | '='        { EQUAL }
  | "=="       { SETEQ }
  | "::"       { CONV }
  | ":="       { ASSIGN }
  | "<>"       { DISEQ }
  | "<"        { LESS }
  | "<="       { LESSOREQUAL }
  | ">"        { GREATER }
  | ">="       { GREATEROREQUAL }
  | '&'        { AND }
  | '|'        { OR }
  | '#'        { XOR }
  | '~'        { NOT }
  | "=>"       { IMPLIES }
  | "->"       { IMPLIES }
  | "<=>"      { IFF }
  | "<->"      { IFF }
  | ".."       { DOTDOT }
  | "<<"       { CMP }
  | "[" ['0'-'9']+ "]" { let s = lexeme lexbuf in
			 let str = String.sub s 1 (String.length s - 2) in
			 WIDTH (int_of_string str) }
  | ":"        { COLON}
  | ';'        { SEMI }
  | '.'        { DOT }
  | _          { raise Parsing.Parse_error }
  | eof        { raise End_of_file }

(*i*)
{
(*i*)

(*s Parse terms and equations from strings and channels. *)

  let term_of_string s =
    let lb = from_string s in Parser.term token lb

  let term_of_channel c =
    let lb = from_channel c in Parser.term token lb

  let eqn_of_string s = 
    let lb = from_string s in Parser.equation token lb

  let eqn_of_channel c =
    let lb = from_channel c in Parser.equation token lb

(*i*)
}
(*i*)
