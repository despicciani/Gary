%{
#include <string>
%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]

DELIM {ESPACO}+
NUM {DIGITO}+

%%

"\n"		        { linha++; }

{DELIM} 	        {}


    /* Operadores Aritméticos */
"+"		            { return '+'; }
"-"		            { return '-'; }
"*"		            { return '*'; }
"/"		            { return '/'; }

    /* Operadores Relacionais */
">="                { return TK_GE;   } 
"<="                { return TK_LE;   }
"=="                { return TK_EQ;   }
"!="                { return TK_DIF;  }
">"                 { return '>';     }
"<"                 { return '<';     }

    /*  Operadores Lógicos    */

"&&"                { return TK_AND; }
"||"                { return TK_OR;  }
"!"                 { return '!';    } 

    /*       Parênteses       */
"("                 { return '('; }
")"                 { return ')'; }

{NUM}		        { yylval.label = yytext; return TK_NUM; }

.			        { fprintf(stderr, "Caractere nao reconhecido na linha %d: %s\n", linha, yytext); }

%%
