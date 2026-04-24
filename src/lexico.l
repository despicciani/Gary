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

%%

"\n"		{ linha++; }

{DELIM} 	{}

"int"       { return TK_TIPO_INT; }
"float"     { return TK_TIPO_FLOAT; }
"char"      { return TK_TIPO_CHAR; }
"boolean"   { return TK_TIPO_BOOL; }
"true"|"false" { yylval.label = yytext; return TK_BOOL; }

{FLOAT}     { yylval.label = yytext; return TK_FLOAT; }
{NUM}		{ yylval.label = yytext; return TK_NUM; }
'[^']'      { yylval.label = yytext; return TK_CHAR; }

[+]			{ return *yytext; }

.			{ fprintf(stderr, "Caractere nao reconhecido na linha %d: %s\n", linha, yytext); }

%%
