%{
#include <stdio.h>
#include <stdlib.h>
#include "env.h"
#include "code.h"

FILE *ofile;

int yylex();
int yyerror(const char * s);

int level = 0;
int offset = 0; 

typedef struct Codeval {
  // 
  cptr* code;
  // literal value
  int val;
  // variable name
  char * name;
} codeval;

#define YYSTYPE codeval

%}

%token VAR MAIN IF THEN ELSE BGN END ENDIF WHILE DO FOR ENDFOR RETURN
%token READ WRITE WRITELN
%token SEMICOLON COMMA
%token INC DEC PLUS MINUS MULT DIV ASN MOD POW EQ NE LT GT LE GE AND OR NOT
%token L_PAREN R_PAREN L_BRACKET R_BRACKET L_SQBRACKET R_SQBRACKET
%token NUMBER
%token IDENT
%token GOTO LABEL

%left ASN
%left AND OR
%left EQ NE LT GT LE GE
%left PLUS MINUS
%left MULT DIV MOD POW
%left NOT
%left INC DEC

%%
program
  : functions main {
    cptr * tmp;
		int label0;

		label0 = makelabel();

		tmp = makecode(O_JMP, 0, label0);
		tmp = mergecode(tmp, $1.code);
		tmp = mergecode(tmp, makecode(O_LAB, 0, label0));
		tmp = mergecode(tmp, makecode(O_INT, 0, $2.val + SYSTEM_AREA));
		tmp = mergecode(tmp, $2.code);
		tmp = mergecode(tmp, makecode(O_OPR, 0, 0));

		printcode(ofile, tmp);
  }
  ;

main
  : MAIN body {
    $$.code = $2.code;
    $$.val = $2.val;
  }
  ;

functions
  : functions function {
    $$.code = mergecode($1.code, $2.code);
  }
  | {
    $$.code = NULL;
  }
  ;

/* ===============
    Function
================= */
function
  : function_header body {
    cptr *tmp, *tmp2;

		tmp = makecode(O_LAB, 0, $1.val);
		tmp2 = makecode(O_INT, 0, $2.val + SYSTEM_AREA);
		$$.code = mergecode(mergecode(tmp, tmp2), $2.code);
		delete_block();
  }

function_header
  : function_ident L_PAREN parameters R_PAREN {
    int   label;
		int   i;
		list *tmp;

		label = makelabel();

		make_params($3.val+1, label);

		$$.val = label;
  }
  ;

function_ident
  : IDENT {
    if (search_all($1.name) == NULL){
			addlist($1.name, FUNC, 0, level, 0);
		}
		else {
			sem_error1("fid");
		}
		addlist("block", BLOCK, 0, 0, 0);
  }

parameters
  : parameters COMMA IDENT {
    if (search_block($3.name) == NULL){
			addlist($3.name, VARIABLE, 0, level, 0);
		}
		else {
			sem_error1("params");
		}

		$$.code = NULL;
		$$.val = $1.val + 1;
  }
  | IDENT {
    if (search_block($1.name) == NULL){
      addlist($1.name, VARIABLE, 0, level, 0);
    }
    else {
      sem_error1("params2");
    }

    $$.code = NULL;
    $$.val = 1;
  }
  | {
    $$.val = 0;
	  $$.code = NULL;
  }

body
  : L_BRACKET _decls stmts R_BRACKET {
    $$.code = $3.code;
	  $$.val = $2.val + $3.val;
	  offset = offset - $2.val;
  }
  ;

/* ======
  decls
=========*/
_decls
  : decls {
    int i;

    vd_backpatch($1.val, offset);

    $$.val = $1.val;
    offset = offset + $1.val;
  }
  ;

decls
  : decls decl {
    $$.val = $1.val + $2.val;
	  $$.code = NULL;
  }
  | {
    $$.val = 0;
  }

decl
  : VAR idents SEMICOLON {
    $$.val = $2.val;
	  $$.code = NULL;
  }
  ;

idents
  : idents COMMA IDENT {
    if (search_block($3.name) == NULL){
      addlist($3.name, VARIABLE, 0, level, 0);
    }
    else {
      sem_error1("var");
    }

    $$.code = NULL;
    $$.val = $1.val + 1;
  }
  | idents COMMA IDENT L_SQBRACKET NUMBER R_SQBRACKET {
    printf("%s val = %d\n", $3.name, $1.val);
    if (search_block($3.name) == NULL){
      addlist($3.name, VARIABLE, 0, level, 0);
    }
    else {
      sem_error1("var");
    }

    $$.code = NULL;
    $$.val = $1.val + yylval.val;
  }
  | IDENT {
    if (search_block($1.name) == NULL){
      addlist($1.name, VARIABLE, 0, level, 0);
    }
    else {
      sem_error1("var");
    }

    $$.code = NULL;
    $$.val = 1;
  }
  | IDENT L_SQBRACKET NUMBER R_SQBRACKET {
    if (search_block($1.name) == NULL){
      addlist($1.name, VARIABLE, 0, level, 0);
    }
    else {
      sem_error1("var");
    }

    $$.code = NULL;
    $$.val = yylval.val;
  }
  ;

/* =======
 stmts
=========*/
stmts
  : stmts stmt {
    $$.code = mergecode($1.code, $2.code);
    if ($1.val < $2.val){
      $$.val = $2.val;
    }
    else {
      $$.val = $1.val;
    }
  }
  | stmt {
    $$.code = $1.code;
	  $$.val = $1.val;
  }

stmt
  : WRITE expr SEMICOLON {
    $$.code = mergecode($2.code, makecode(O_CSP, 0, 1));
	  $$.val = 0;
  }
  | WRITELN SEMICOLON {
    $$.code = makecode(O_CSP, 0, 2);
	  $$.val = 0;
  }
  | READ IDENT SEMICOLON {
    cptr *tmp;
    list *tmp2;

    tmp2 = search_all($2.name);

    if (tmp2 == NULL){
      sem_error2("read");
    }

    if (tmp2->kind != VARIABLE){
      sem_error2("as function");
    }

    $$.code = mergecode(makecode(O_CSP, 0, 0),
      makecode(O_STO, level - tmp2->l, tmp2->a));
    $$.val = 0;
  }
  | if_stmt
  | while_stmt
  | for_stmt
  | GOTO IDENT {
    // TODO search label index
    $$.code = makecode(O_JMP, 0, 1);
  }
  | LABEL IDENT {
    $$.code = makecode(O_LAB, 0, makelabel());
  }
  | {
    addlist("block", BLOCK, 0, 0, 0);
  }
  | RETURN expr SEMICOLON {
    list* tmp2;

    tmp2 = searchf(level);

    $$.code = mergecode($2.code, makecode(O_RET, 0, tmp2->params));
    $$.val = 0;
  }
  | expr SEMICOLON {
    $$.code = $1.code;
  }
  ;

if_stmt
  : IF expr THEN stmt ENDIF SEMICOLON {
    cptr *tmp;
    int label0, label1;

    label0 = makelabel();

    tmp = mergecode($2.code, makecode(O_JPC, 0, label0));
    tmp = mergecode(tmp, $4.code);

    $$.code = mergecode(tmp, makecode(O_LAB, 0, label0));
    $$.val = 0;
  }
  | IF expr THEN stmt ELSE stmt ENDIF SEMICOLON {
    cptr *tmp;
    int label0, label1;

    label0 = makelabel();
    label1 = makelabel();

    tmp = mergecode($2.code, makecode(O_JPC, 0, label0));
    tmp = mergecode(tmp, $4.code);
    tmp = mergecode(tmp, makecode(O_JMP, 0, label1));
    tmp = mergecode(tmp, makecode(O_LAB, 0, label0));
    tmp = mergecode(tmp, $6.code);

    $$.code = mergecode(tmp, makecode(O_LAB, 0, label1));
    $$.val = 0;
  }
  ;

while_stmt
  : WHILE expr DO stmt {
    int label0, label1;
    cptr *tmp;

    label0 = makelabel();
    label1 = makelabel();

    tmp = makecode(O_LAB, 0, label0);
    tmp = mergecode(tmp, $2.code);
    tmp = mergecode(tmp, makecode(O_JPC, 0, label1));
    tmp = mergecode(tmp, $4.code);
    tmp = mergecode(tmp, makecode(O_JMP, 0, label0));
    tmp = mergecode(tmp, makecode(O_LAB, 0, label1));

    $$.code = tmp; 
    
    $$.val = 0;
  }
  ;

/* ======================
        FOR
======================= */
for_stmt
  : FOR init SEMICOLON expr SEMICOLON expr DO stmts ENDFOR {
    int label0 = makelabel(), label1 = makelabel();
    cptr * tmp;
    tmp = makecode(O_LAB, 0, label0);
    tmp = mergecode(tmp, $4.code);
    tmp = mergecode(tmp, makecode(O_JPC, 0, label1));
    tmp = mergecode(tmp, $8.code);
    tmp = mergecode(tmp, $6.code);
    tmp = mergecode(tmp, makecode(O_JMP, 0, label0));
    tmp = mergecode(tmp, makecode(O_LAB, 0, label1));
    $$.code = tmp;
    $$.val = 0;
  }
  ;

init
  : expr {
    $$.code = $1.code;
  }

/* =======
   expr
========= */
expr
  : IDENT ASN expr {
    list *tmp;

    tmp = search_all($1.name);

    printf("%s at %d\n", tmp->name, tmp->a);

    if (tmp == NULL){
      sem_error2("assignment");
    }

    if (tmp->kind != VARIABLE){
      sem_error2("assignment2");
    }

    $$.code = mergecode($3.code,
      makecode(O_STO, level - tmp->l, tmp->a));
    $$.val = 0;
  }
  | IDENT L_SQBRACKET expr R_SQBRACKET ASN expr {
    list *tmp;

    tmp = search_all($1.name);

    printf("%s at %d\n", tmp->name, tmp->a);

    if (tmp == NULL){
      sem_error2("assignment");
    }

    if (tmp->kind != VARIABLE){
      sem_error2("assignment2");
    }

    printf("%s base %d + offset ?\n", tmp->name, tmp->a);

    cptr *address_node = mergecode(mergecode($3.code, makecode(O_LIT, 0, tmp->a)), makecode(O_OPR, 0, 2));

    dump_node(address_node);

    $$.code = mergecode(mergecode($6.code, address_node), makecode(O_DST, 0, 0));
    $$.val = 0;
  }
  | expr PLUS expr {
    $$.code = mergecode(mergecode($1.code, $3.code),makecode(O_OPR, 0, 2));
  }
  | expr MINUS expr {
    $$.code = mergecode(mergecode($1.code, $3.code),makecode(O_OPR, 0, 3));
  }
  | expr MULT expr {
    $$.code = mergecode(mergecode($1.code, $3.code),makecode(O_OPR, 0, 4));
  }
  | expr DIV expr {
    $$.code = mergecode(mergecode($1.code, $3.code),makecode(O_OPR, 0, 5));
  }
  | expr MOD expr {
    // a % b == a - b * (a // b)
    // (a (b (a b /) *) -)
    // [NOTE]
    // cannot use mergecode args twice
    // because in mergecode() free() args
    /*
    cptr *tmp;
    tmp = mergecode(mergecode($1.code, $3.code),makecode(O_OPR, 0, 5));
    tmp = mergecode(mergecode($3.code, tmp), makecode(O_OPR, 0, 4));
    tmp = mergecode(mergecode($1.code, tmp), makecode(O_OPR, 0, 3));
    $$.code = tmp;
    */
    $$.code = mergecode(mergecode($1.code, $3.code), makecode(O_OPR, 0, 7));
  }
  | expr GT expr {
    $$.code = mergecode(mergecode($1.code, $3.code),makecode(O_OPR, 0, 12));
  }
  | expr GE expr {
    $$.code = mergecode(mergecode($1.code, $3.code),makecode(O_OPR, 0, 11));
  }
  | expr LT expr {
    $$.code = mergecode(mergecode($1.code, $3.code),makecode(O_OPR, 0, 10));
  }
  | expr LE expr {
    $$.code = mergecode(mergecode($1.code, $3.code),makecode(O_OPR, 0, 13));
  }
  | expr NE expr {
    $$.code = mergecode(mergecode($1.code, $3.code),makecode(O_OPR, 0, 9));
  }
  | expr EQ expr {
    $$.code = mergecode(mergecode($1.code, $3.code),makecode(O_OPR, 0, 8));  
  }
  | expr AND expr {
    $$.code = mergecode(mergecode($1.code, $3.code), makecode(O_OPR, 0, 14));
  }
  | expr OR expr {
    $$.code = mergecode(mergecode($1.code, $3.code), makecode(O_OPR, 0, 15));
  }
  | NOT expr {
    $$.code = mergecode($2.code, makecode(O_OPR, 0, 16));
  }
  | INC IDENT {
    // ++i -> i := i + 1; i;
    list * v = search_all($1.name);
    if (v == NULL){
      sem_error2("inc");
    }

    cptr * t = mergecode(makecode(O_LOD, level - v->l, v->a), makecode(O_LIT, 0, 1));
    t = mergecode(t, makecode(O_OPR, 0, 2));
    t = mergecode(t, makecode(O_STO, level - v->l, v->a));
    t = mergecode(t, makecode(O_LOD, level - v->l, v->a));
    $$.code = t;
  }
  | DEC IDENT {
    list * v = search_all($1.name);
    if (v == NULL){
      sem_error2("dec");
    }

    cptr * t = mergecode(makecode(O_LOD, level - v->l, v->a), makecode(O_LIT, 0, 1));
    t = mergecode(t, makecode(O_OPR, 0, 3));
    t = mergecode(t, makecode(O_STO, level - v->l, v->a));
    t = mergecode(t, makecode(O_LOD, level - v->l, v->a));
    $$.code = t;
  }
  | IDENT INC {
    // i++ -> i := i + 1; i - 1;
    list * v = search_all($1.name);
    if (v == NULL){
      sem_error2("inc");
    }

    cptr * t = mergecode(makecode(O_LOD, level - v->l, v->a), makecode(O_LIT, 0, 1));
    t = mergecode(t, makecode(O_OPR, 0, 2));
    t = mergecode(t, makecode(O_STO, level - v->l, v->a));
    t = mergecode(t, makecode(O_LOD, level - v->l, v->a));
    t = mergecode(mergecode(t, makecode(O_LIT, 0, 1)), makecode(O_OPR, 0, 3));
    $$.code = t;
  }
  | IDENT DEC {
    // i-- -> i := i - 1; i + 1;
    list * v = search_all($1.name);
    if (v == NULL){
      sem_error2("dec");
    }

    cptr * t = mergecode(makecode(O_LOD, level - v->l, v->a), makecode(O_LIT, 0, 1));
    t = mergecode(t, makecode(O_OPR, 0, 3));
    t = mergecode(t, makecode(O_STO, level - v->l, v->a));
    t = mergecode(t, makecode(O_LOD, level - v->l, v->a));
    t = mergecode(mergecode(t, makecode(O_LIT, 0, 1)), makecode(O_OPR, 0, 2));
    $$.code = t;
  }
  | L_PAREN expr R_PAREN {
    $$.code = $2.code;
  }
  | expr COMMA expr {
    $$.code = mergecode($1.code, $3.code);
  }
  | NUMBER {
    $$.code = makecode(O_LIT, 0, yylval.val);
  }
  | IDENT {
    cptr *tmpc;
    list* tmpl;

    tmpl = search_all($1.name);
    if (tmpl == NULL){
      sem_error2("id");
    }

    if (tmpl->kind == VARIABLE){
      $$.code = makecode(O_LOD, level - tmpl->l, tmpl->a);
    }
    else {
      sem_error2("id as variable");
    }
  }
  | IDENT L_SQBRACKET expr R_SQBRACKET {
    cptr* tmpc;
    list* tmpl;

    tmpl = search_all($1.name);
    if (tmpl == NULL){
      sem_error2("id");
    }

    if (tmpl->kind == VARIABLE){
      $$.code = mergecode($3.code,
        makecode(O_DLD, 0, 0));
    }
    else {
      sem_error2("id as variable");
    }
  }
  | IDENT L_PAREN f_parameters R_PAREN {
    list* tmpl;

    tmpl = search_all($1.name);
    if (tmpl == NULL){
      sem_error2("id as function");
    }

    if (tmpl->kind != FUNC){
      sem_error2("id as function2");
    }

    if (tmpl->params != $3.val){
      sem_error3(tmpl->name, tmpl->params, $3.val);
    }

    $$.code = mergecode($3.code,
      makecode(O_CAL,
      level - tmpl->l,
      tmpl->a));
  }
  ;

f_parameters
  : ac_parameters {
    $$.val = $1.val;
	  $$.code = $1.code;
  }
  | {
    $$.val = 0;
	  $$.code = NULL;
  }
  ;

ac_parameters
  : ac_parameters COMMA f_parameter {
    $$.val = $1.val + 1;
	  $$.code = mergecode($1.code, $3.code);
  }
  | f_parameter {
    $$.val = 1;
	  $$.code = $1.code;
  }
  ;

f_parameter
  : expr {
    $$.code = $1.code;
  }
  ;
%%

#include "lex.yy.c"

// int yyerror(const char * s) {
//   extern char * yytext;
//   fprintf(stderr, "parser error near %s\n", yytext);
//   return 0;
// }

int main(int argc, char * argv[]) {
  ofile = fopen("a.out", "w");
  if (ofile == NULL){
    perror("ofile");
    exit(EXIT_FAILURE);
  }

  extern FILE * yyin;

  // printf("[Compile] %s\n", argv[1]);
  if((yyin = fopen(argv[1], "r")) == NULL) {
    fprintf(stderr, "%s not found\n", argv[1]);
    exit(1);
  }

  initialize();
  yyparse();

  // printf("[Success] %s\n", argv[1]);

  fclose(yyin);
  fclose(ofile);
  return 0;
}
