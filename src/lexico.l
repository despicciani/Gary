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
">="                { return TK_MaI; }
"<="                { return TK_MeI; }
"=="                { return TK_IG;  }
"!="                { return TK_DF;  }
">"                 { return '>';    }
"<"                 { return '<';    }

{NUM}		        { yylval.label = yytext; return TK_NUM; }

.			        { fprintf(stderr, "Caractere nao reconhecido na linha %d: %s\n", linha, yytext); }

%%
