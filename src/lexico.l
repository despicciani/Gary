%{
#include <string>
#include "y.tab.h"
%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]

DELIM {ESPACO}+
NUM {DIGITO}+
FLOAT {DIGITO}+\.{DIGITO}+
ID [a-zA-Z_][a-zA-Z0-9_]*

%%

"\n"		{ linha++; }
"\r"        {}

{DELIM} 	{}

"int"       { return TK_TIPO_INT; }
"float"     { return TK_TIPO_FLOAT; }
"char"      { return TK_TIPO_CHAR; }
"boolean"   { return TK_TIPO_BOOL; }
"true"|"false" { yylval.label = yytext; return TK_BOOL; }

{FLOAT}     { yylval.label = yytext; return TK_FLOAT; }
{NUM}		{ yylval.label = yytext; return TK_NUM; }
{ID}        { yylval.label = yytext; return TK_ID; }
[=;]		{ return *yytext; }
'[^']'      { yylval.label = yytext; return TK_CHAR; }

[+]			{ return *yytext; }

.			{ fprintf(stderr, "Caractere nao reconhecido na linha %d: %s\n", linha, yytext); }

%%
