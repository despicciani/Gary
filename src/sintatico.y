%{
#include <iostream>
#include <string>

#define YYSTYPE atributos

using namespace std;

int var_temp_qnt;
int linha = 1;
string codigo_gerado;

struct atributos
{
	string label;
	string traducao;
	string tipo;
};

int yylex(void);
void yyerror(string);
string gentempcode();
%}

%token TK_NUM
%token TK_FLOAT
%token TK_CHAR
%token TK_BOOL

%token TK_TIPO_INT
%token TK_TIPO_FLOAT
%token TK_TIPO_CHAR
%token TK_TIPO_BOOL

%start S

%left '+'

%%

S 			: E
			{
				codigo_gerado = "/*Compilador FOCA*/\n"
								"#include <stdio.h>\n"
								"int main(void) {\n";

				codigo_gerado += $1.traducao;

				codigo_gerado += "\treturn 0;"
							"\n}\n";
			}
			;

E 			: TK_NUM

			{
			$$.label = gentempcode();
			$$.tipo = "int";
			$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
			}
			
			| TK_FLOAT
			{
			$$.label = gentempcode();
			$$.tipo = "float";
			$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
			}

			| TK_CHAR
			{
			$$.label = gentempcode();
			$$.tipo = "char";
			$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
			}
			

			| TK_BOOL
			{
			$$.label = gentempcode();
			$$.tipo = "boolean";
			$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
			}
			
 			| E '+' E
			{
				$$.label = gentempcode();

				if ($1.tipo != $3.tipo) {
					string erro = "tipos incompativeis na soma (" + $1.tipo + " + " + $3.tipo + ")";
					yyerror(erro);
					
					$$.tipo = "erro"; 
				} else {
					$$.tipo = $1.tipo;
				}


				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " + " + $3.label + ";\n";
			}
			;
			

%%

#include "lex.yy.c"

int yyparse();

string gentempcode()
{
	var_temp_qnt++;
	return "t" + to_string(var_temp_qnt);
}

int main(int argc, char* argv[])
{
	var_temp_qnt = 0;

	if (yyparse() == 0)
		cout << codigo_gerado;

	return 0;
}

void yyerror(string MSG)
{
	cerr << "Erro na linha " << linha << ": " << MSG << endl;
}
