%{
#include <iostream>
#include <string>
#include <vector>
#include <unordered_map>

#define YYSTYPE atributos

using namespace std;

int var_temp_qnt;
int linha = 1;
string codigo_gerado;
vector<string> tipos_dos_temporarios;

struct atributos
{
	string label;
	string traducao;
	string tipo;
};

struct Simbolo {
	string tipo;
    string label;
};

unordered_map<string, Simbolo> tabela_simbolos;

int yylex(void);
void yyerror(string);
string gentempcode(string tipo);
void declarar_variavel(string nome, string tipo);
Simbolo buscar_simbolo(string nome);

%}

// Literais
%token TK_INT
%token TK_FLOAT
%token TK_CHAR
%token TK_BOOL

// Tipos
%token TK_TIPO_INT
%token TK_TIPO_FLOAT
%token TK_TIPO_CHAR
%token TK_TIPO_BOOL

// Identificador
%token TK_ID

// Tokens Relacionais
%token TK_GE TK_LE TK_EQ TK_DIF

// Tokens Lógicos
%token TK_AND TK_OR

// Símbolo Inicial
%start PROGRAMA

// Precedência
%left TK_OR
%left TK_AND
%left TK_EQ TK_DIF
%left '>' '<' TK_GE TK_LE 
%left '+' '-'
%left '*' '/'
%right '!'

%%
	/* 		   Início			*/
PROGRAMA 	: LISTA_COMANDOS
			{
				codigo_gerado = "/*Compilador FOCA*/\n"
								"#include <stdio.h>\n\n"
								"#define true 1\n"
								"#define false 0\n"
								"#define bool int\n\n"
								"int main(void) {\n";

				for (int i = 0; i < tipos_dos_temporarios.size(); i++) {
					codigo_gerado += "\t" + tipos_dos_temporarios[i] + " t" + to_string(i+1) + ";\n";
				}

				codigo_gerado += "\n" + $1.traducao;

				codigo_gerado += "\treturn 0;"
							"\n}\n";
			}
			;

	/* Recursão à esquerda para ter vários comandos */
LISTA_COMANDOS		: LISTA_COMANDOS CMD
					{
						$$.traducao = $1.traducao + $2.traducao;
					}
					| 
					{
						$$.traducao = "";
					}
					;

	/* Tipos */
TIPO		: TK_TIPO_INT   { $$.tipo = "int";   }
			| TK_TIPO_FLOAT { $$.tipo = "float"; }
			| TK_TIPO_CHAR  { $$.tipo = "char";  }
			| TK_TIPO_BOOL  { $$.tipo = "bool";  }
			;

	/* Comando */
CMD			: TIPO TK_ID ';' // Regra de DECLARAÇÃO 
			{
				declarar_variavel($2.label, $1.tipo);
				$$.traducao = "";
			}
			| TK_ID '=' E ';' // Regra de ATRIBUIÇÃO 
			{
				Simbolo s = buscar_simbolo($1.label);
				
				if (s.tipo != $3.tipo) {
					yyerror("Atribuicao invalida: '" + $1.label + "' (" + s.tipo + ") nao pode receber tipo '" + $3.tipo + "'.");
					exit(1);
				}

				$$.traducao = $3.traducao + "\t" + s.label + " = " + $3.label + ";\n";
			}
			| E ';' 
            {
                $$.traducao = $1.traducao; 
            }
		    ;

	/* 		  Expressão 		*/
	/* 		Identificador		*/
E 			: TK_ID
			{
				Simbolo s = buscar_simbolo($1.label);
				$$.label = s.label;
				$$.tipo = s.tipo;
				$$.traducao = "";
			}
	
	/*		  Literais			*/
			| TK_INT

			{
			$$.label = gentempcode("int");
			$$.tipo = "int";
			$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
			}

			| TK_FLOAT
			{
			$$.label = gentempcode("float");
			$$.tipo = "float";
			$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
			}

			| TK_CHAR
			{
			$$.label = gentempcode("char");
			$$.tipo = "char";
			$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
			}

			| TK_BOOL
			{
			$$.label = gentempcode("bool");
			$$.tipo = "bool";
			$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n"; 
			}

	/* 	Operadores Aritméticos	*/ 
			| E '+' E
			{
				$$.label = gentempcode($1.tipo);
				$$.tipo = $1.tipo;
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " + " + $3.label + ";\n";
			}

			| E '-' E
			{
				$$.label = gentempcode($1.tipo);
				$$.tipo = $1.tipo;
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label + 
					" = " + $1.label + " - " + $3.label + ";\n";	
			}

			| E '*' E
			{
				$$.label = gentempcode($1.tipo);
				$$.tipo = $1.tipo;
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " * " + $3.label + ";\n";
			}

			| E '/' E
			{
				$$.label = gentempcode($1.tipo);
				$$.tipo = $1.tipo;
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " / " + $3.label + ";\n";	
			}

	/* 	Operadores Relacionais	*/ 
			| E '>' E
			{
				$$.label = gentempcode("bool");
				$$.tipo = "bool";
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " > " + $3.label + ";\n";		
			}

			| E '<' E
			{
				$$.label = gentempcode("bool");
				$$.tipo = "bool";
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " < " + $3.label + ";\n";		
			}

			| E TK_GE E
			{
				$$.label = gentempcode("bool");
				$$.tipo = "bool";
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " >= " + $3.label + ";\n";		
			}

			| E TK_LE E
			{
				$$.label = gentempcode("bool");
				$$.tipo = "bool";
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " <= " + $3.label + ";\n";		
			}

			| E TK_EQ E
			{
				$$.label = gentempcode("bool");
				$$.tipo = "bool";
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " == " + $3.label + ";\n";		
			}

			| E TK_DIF E
			{
				$$.label = gentempcode("bool");
				$$.tipo = "bool";
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " != " + $3.label + ";\n";		
			}

	/* 	  Operadores Lógicos    */ 
			| E TK_AND E
			{
				$$.label = gentempcode("bool");
				$$.tipo = "bool";
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " && " + $3.label + ";\n";		
			}

			| E TK_OR E
			{
				$$.label = gentempcode("bool");
				$$.tipo = "bool";
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " || " + $3.label + ";\n";		
			}

			| '!' E
			{
				$$.label = gentempcode("bool");
				$$.tipo = "bool";
				$$.traducao = $2.traducao + "\t" + $$.label + " = " + 
					"!" + $2.label + ";\n";
			}

	/*        Parênteses		*/ 
			| '(' E ')'
			{
				$$.label = $2.label;
				$$.tipo = $2.tipo;
				$$.traducao = $2.traducao;
			}
			;

%%

#include "lex.yy.c"

int yyparse();

string gentempcode(string tipo) {
	var_temp_qnt++;
	tipos_dos_temporarios.push_back(tipo);

	return "t" + to_string(var_temp_qnt);
}

void declarar_variavel(string nome, string tipo) {
	if (tabela_simbolos.count(nome)) {
		yyerror("Erro Semantico: Variavel '" + nome + "' ja declarada");
		exit(1);
	} else {
		string temp_label = gentempcode(tipo);
        Simbolo s;
        s.tipo = tipo;
        s.label = temp_label;
        tabela_simbolos[nome] = s;
	}
}

Simbolo buscar_simbolo(string nome) {
	if (tabela_simbolos.count(nome)) {
		return tabela_simbolos[nome];
	} else {
		yyerror("Erro Semantico: Variavel '" + nome + "' nao declarada.");
		exit(1);
	}
}


int main(int argc, char* argv[]) {
	var_temp_qnt = 0;

	if (yyparse() == 0)
		cout << codigo_gerado;

	return 0;
}

void yyerror(string MSG) {
	cerr << "Erro na linha " << linha << ": " << MSG << endl;
}
