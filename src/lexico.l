%{
#include <string>
#include <stack>
#include "y.tab.h"

using namespace std;

stack<int> pilhas_indentacao;
int dedents_pendentes = 0;
bool inicio_configurado = false;

bool enter_eof_emitido = false;

%}

%option noyywrap

DIGITO [0-9]

INT {DIGITO}+
FLOAT {DIGITO}+\.{DIGITO}+
ID [a-zA-Z_][a-zA-Z0-9_]*

%%

    /*
    exemplo do esquema de tabulaçao por identaçao:

    print("inicio")
    if (teste):
        x = 1
        y = 2
    print("fim")

    começa com a inicializaçao da pilha em 0.
    primeira linha: 0 espaços no começo, com a pilha sendo 0. nao acontece nd.
    segunda linha: msm coisa.
    terceira linha: 4 espaços -> 1 tab. o lex vê a pilha e vê q o 4 é maior que o topo, que é 0, oq significa que abriu um bloco, 
    cuspindo o tk_indent, que é como se fosse uma chave abrindo (o yacc vai ver assim)
    quarta linha: 4 espaços -> 1 tab. o lex olha a pilha e ve q 4 é igual 4. nao faz nada.
    quinta e ultima linha: 0 espaços. o lex olha a pilha e ve q 0 é menor que 4 (q eh o topo), logo ele emite um tk_dedent, q eh como
    a chave fechando (o yacc vai ver assim tb)

    quando ha mais de um bloco, como um if dentro de um while ou um if aninhado, há os dedents pendentes, q sao resolvidos abaixo
    */

%{
    if (!inicio_configurado) {
        pilhas_indentacao.push(0);
        inicio_configurado = true;
    }

    if (dedents_pendentes > 0) {
        dedents_pendentes--;
        return TK_DEDENT;
    }
%}

    //ignora as linhas em branco, mas conta a linha

^[ \t]*\r?\n    { linha++; }

    
^[ \t]*         {
    int indentacao_atual = 0;
    
        //1 tab = 4 espacos
    for (int i = 0; i < yyleng; i++) {
        if (yytext[i] == '\t') indentacao_atual += 4;
        else indentacao_atual += 1;
    }

    if (indentacao_atual > pilhas_indentacao.top()) {
        pilhas_indentacao.push(indentacao_atual);
        return TK_INDENT;
    } 
    //calcula quantos dedents tem q ser emitidos
    else if (indentacao_atual < pilhas_indentacao.top()) {
        while (pilhas_indentacao.top() > indentacao_atual) {
            pilhas_indentacao.pop();
            dedents_pendentes++;
        }

        if (dedents_pendentes > 0) {
            dedents_pendentes--;
            return TK_DEDENT;
        }
    }
}

\r?\n           { linha++; return TK_NEWLINE; }

[ \t]+  {}


        /*          Tipos          */
"true"|"false" { yylval.label = yytext; return TK_BOOL; }

"print"     { return TK_PRINT; }
"input"     { return TK_INPUT; }

"if"        { return TK_IF; }
"else"      { return TK_ELSE; }
"while"     { return TK_WHILE; }
"do"        { return TK_DO; }
"switch"    { return TK_SWITCH; }
"case"      { return TK_CASE; }
"default"   { return TK_DEFAULT; } 

"for"       { return TK_FOR; }
"in"        { return TK_IN; }
"to"        { return TK_TO; }
"++"        { return TK_INC; }

    /* Números e Identificador */
{FLOAT}     { yylval.label = yytext; return TK_FLOAT; }
{INT}		{ yylval.label = yytext; return TK_INT; }
{ID}        { yylval.label = yytext; return TK_ID; }

    /*          Char           */
'[^']'      { yylval.label = yytext; return TK_CHAR; }

    /*          String           */
\"[^\"]*\"  { yylval.label = yytext; return TK_STRING; }

    /*   Atribuição e ;        */
[=;]		{ return *yytext; }

":"         { return ':'; }

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

    /* garante que todos os blocos abertos sejam fechados */
<<EOF>> {

        // lança uma linha (enter) antes de qualquer coisa para fechar a ultima linha
    if (!enter_eof_emitido) {
        enter_eof_emitido = true;
        return TK_NEWLINE;
    }

    if (pilhas_indentacao.top() > 0) {
        pilhas_indentacao.pop();
        return TK_DEDENT;
    }
    return 0; 
}

%%