%{
#include <iostream>
#include <string>
#include <unordered_map>

#define YYSTYPE atributos

using namespace std;

int var_temp_qnt;
int linha = 1;
string codigo_gerado;

unordered_map<string, string> tabela_simbolos;

struct atributos
{
	string label;
	string traducao;
	string tipo;
};

int yylex(void);
void yyerror(string);
string gentempcode();

void declarar_variavel(string nome, string tipo) {
	if (tabela_simbolos.count(nome)) {
		yyerror("Erro Semantico: Variavel '" + nome + "' ja declarada");
	} else {
		tabela_simbolos[nome] = tipo;
	}
}

string buscar_tipo(string nome) {
	if (tabela_simbolos.count(nome)) {
		return tabela_simbolos[nome];
	} else {
		yyerror("Erro Semantico: Variavel '" + nome + "' nao declarada.");
		return "erro";
	}
}

%}

%token TK_NUM
%token TK_FLOAT
%token TK_CHAR
%token TK_BOOL

%token TK_TIPO_INT
%token TK_TIPO_FLOAT
%token TK_TIPO_CHAR
%token TK_TIPO_BOOL

%token TK_ID

%start S

%left '+'

%%

S 			: BLOCO
			{
				codigo_gerado = "/*Compilador FOCA*/\n"
								"#include <stdio.h>\n"
								"int main(void) {\n";
				codigo_gerado += $1.traducao; 
				codigo_gerado += "\treturn 0;\n}\n";
			}
			;

BLOCO		: CMD BLOCO
			{
				$$.traducao = $1.traducao + $2.traducao;
			}
			|
			{
				$$.traducao = "";
			}
			;

TIPO		: TK_TIPO_INT   { $$.tipo = "int";   $$.traducao = "int "; }
			| TK_TIPO_FLOAT { $$.tipo = "float"; $$.traducao = "float "; }
			| TK_TIPO_CHAR  { $$.tipo = "char";  $$.traducao = "char "; }
			| TK_TIPO_BOOL  { $$.tipo = "bool";  $$.traducao = "int "; }
			;

CMD			: TIPO TK_ID ';' // Regra de DECLARAÇÃO 
			{
				declarar_variavel($2.label, $1.tipo);
				$$.traducao = "\t" + $1.traducao + $2.label + ";\n";
			}
			| TK_ID '=' E ';' // Regra de ATRIBUIÇÃO 
			{
				string tipo_var = buscar_tipo($1.label);
				
				if (tipo_var != "erro" && $3.tipo != "erro" && tipo_var != $3.tipo) {
					yyerror("Atribuicao invalida: '" + $1.label + "' (" + tipo_var + ") nao pode receber tipo '" + $3.tipo + "'.");
				}

				$$.traducao = $3.traducao + "\t" + $1.label + " = " + $3.label + ";\n";
			}
			;
			| E ';' 
            {
                $$.traducao = $1.traducao; 
            }
		    ;


E 			: TK_ID
			{
				$$.label = $1.label;
				$$.tipo = buscar_tipo($1.label);
				$$.traducao = ""; // Não gera código extra só por ler a variável
			}
			
			| TK_NUM

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
			$$.tipo = "bool";
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
