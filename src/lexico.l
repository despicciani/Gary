%{
#include <string>
#include <stack>
#include "y.tab.h"

using namespace std;

stack<int> pilha_indentacao;
int dedents_pendentes = 0;
int chaves_abertas = 0;
bool inicio_configurado = false;
bool enter_eof_emitido = false;

%}

%option noyywrap
%x CHECK_INDENT

DIGITO [0-9]

INT 0|[1-9]{DIGITO}*
FLOAT {INT}\.{DIGITO}+
ID [a-zA-Z_][a-zA-Z0-9_]*

%%

    /*
    exemplo do esquema de bloco por indentaçao:

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
        pilha_indentacao.push(0);
        inicio_configurado = true;
        BEGIN(CHECK_INDENT); 
    }

    if (dedents_pendentes > 0) {
        dedents_pendentes--;
        return TK_DEDENT;
    }
%}

<CHECK_INDENT>[ \t]+ {
    int indentacao_atual = 0;
    for (int i = 0; i < yyleng; i++) {
        if (yytext[i] == '\t') indentacao_atual += 4;
        else indentacao_atual += 1;
    }
    
    BEGIN(INITIAL); 
    
    if (indentacao_atual > pilha_indentacao.top()) {
        pilha_indentacao.push(indentacao_atual);
        return TK_INDENT;
    } 
    else if (indentacao_atual < pilha_indentacao.top()) {
        while (pilha_indentacao.top() > indentacao_atual) {
            pilha_indentacao.pop();
            dedents_pendentes++;
        }
        if (dedents_pendentes > 0) {
            dedents_pendentes--;
            return TK_DEDENT;
        }
    }
}

    
<CHECK_INDENT>\r?\n {
    linha++;
}

<CHECK_INDENT>. {
    yyless(0); 
    BEGIN(INITIAL); 

    int indentacao_atual = 0;
    if (indentacao_atual < pilha_indentacao.top()) {
        while (pilha_indentacao.top() > indentacao_atual) {
            pilha_indentacao.pop();
            dedents_pendentes++;
        }
        if (dedents_pendentes > 0) {
            dedents_pendentes--;
            return TK_DEDENT;
        }
    }
}

<CHECK_INDENT><<EOF>> {
    BEGIN(INITIAL);
}

\r?\n           { 
                    linha++; 
                    if (chaves_abertas == 0) {
                        BEGIN(CHECK_INDENT); 
                    }
                    return TK_NEWLINE; 
                }

[ \t]+          { }

    /*    Variáveis Globais e Locais   */
"global"    { return TK_GLOBAL; }
"local"     { return TK_LOCAL;  }

    /*         boolean         */
"true"|"false" { yylval.label = yytext; return TK_BOOL; }

    /*     entrada e saída     */
"print"     { return TK_PRINT; }
"input"     { return TK_INPUT; }

    /*         if-elif-else    */
"if"        { return TK_IF;   }
"else"      { return TK_ELSE; }
"elif"      { return TK_ELIF; }

    /*        do e while       */
"while"     { return TK_WHILE; }
"do"        { return TK_DO;    }

    /*         switch          */
"switch"    { return TK_SWITCH;  }
"case"      { return TK_CASE;    }
"default"   { return TK_DEFAULT; }

    /*           for           */
"for"       { return TK_FOR; }
"in"        { return TK_IN;  }
"to"        { return TK_TO;  }

    /*     break e continue    */
"break"     { return TK_BREAK;    }
"continue"  { return TK_CONTINUE; }

    /*        Incremento       */
"++"        { return TK_INC; }

    /*     Cast Explícito      */
"int"       { yylval.label = yytext; return TK_CAST_INT; }
"float"     { yylval.label = yytext; return TK_CAST_FLOAT; }
"str"       { yylval.label = yytext; return TK_CAST_STR; }
"bool"      { yylval.label = yytext; return TK_CAST_BOOL; }
"char"      { yylval.label = yytext; return TK_CAST_CHAR; }

    /*  Operadores Lógicos     */
"and"       { yylval.label = yytext; return TK_AND; }
"or"        { yylval.label = yytext; return TK_OR;  }
"not"       { yylval.label = yytext; return TK_NOT; }

    /* Números e Identificador */
{FLOAT}     { yylval.label = yytext; return TK_FLOAT; }
{INT}		{ yylval.label = yytext; return TK_INT;   }
{ID}        { yylval.label = yytext; return TK_ID;    }

    /*          Char           */
'[^']'      { yylval.label = yytext; return TK_CHAR; }

    /*          String         */
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

    /*    Chaves de Blocos     */
"{"                 { chaves_abertas++; return '{'; }
"}"                 { chaves_abertas--; return '}'; }

    /*       Parênteses        */
"("                 { return '('; }
")"                 { return ')'; }

.			        { fprintf(stderr, "Caractere nao reconhecido na linha %d: %s\n", linha, yytext); }

    /* Garante que todos os blocos abertos sejam fechados */
<<EOF>> {

        // lança uma linha (enter) antes de qualquer coisa para fechar a ultima linha
    if (!enter_eof_emitido) {
        enter_eof_emitido = true;
        return TK_NEWLINE;
    }

    if (pilha_indentacao.top() > 0) {
        pilha_indentacao.pop();
        return TK_DEDENT;
    }
    return 0; 
}

%%