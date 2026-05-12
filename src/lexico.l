%{
#include <string>
#include "y.tab.h"
%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]

DELIM {ESPACO}+
INT {DIGITO}+
FLOAT {DIGITO}+\.{DIGITO}+
ID [a-zA-Z_][a-zA-Z0-9_]*

%%

"\n"		        { linha++; }

{DELIM} 	        {}


    /*          Tipos          */
"true"|"false" { yylval.label = yytext; return TK_BOOL; }

"print"     { return TK_PRINT; }

    /* Números e Identificador */
{FLOAT}     { yylval.label = yytext; return TK_FLOAT; }
{INT}		{ yylval.label = yytext; return TK_INT; }
{ID}        { yylval.label = yytext; return TK_ID; }

    /*          Char           */
'[^']'      { yylval.label = yytext; return TK_CHAR; }

    /*   Atribuição e ;        */
[=;]		{ return *yytext; }

    /* Operadores Aritméticos  */
"+"		            { return '+'; }
"-"		            { return '-'; }
"*"		            { return '*'; }
"/"		            { return '/'; }

    /* Operadores Relacionais  */
">="                { return TK_GE;   } 
"<="                { return TK_LE;   }
"=="                { return TK_EQ;   }
"!="                { return TK_DIF;  }
">"                 { return '>';     }
"<"                 { return '<';     }

    /*  Operadores Lógicos     */

"&&"                { return TK_AND; }
"||"                { return TK_OR;  }
"!"                 { return '!';    } 

    /*       Parênteses        */
"("                 { return '('; }
")"                 { return ')'; }

.			        { fprintf(stderr, "Caractere nao reconhecido na linha %d: %s\n", linha, yytext); }

%%