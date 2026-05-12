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

vector<string> variaveis_declaradas;
unordered_map<string, bool> tabela_simbolos;

struct atributos {
	string label;
	string traducao;
};

int yylex(void);
void yyerror(string);

string gentempcode() {
	var_temp_qnt++;
	return "t" + to_string(var_temp_qnt);
}

void registrar_variavel(string nome) {
	if (!tabela_simbolos.count(nome)) {
		tabela_simbolos[nome] = true;
		variaveis_declaradas.push_back(nome);
	}
}

//codigo c q vai no final
string runtime_c = 
"/* Compilador Dinamico FOCA */\n"
"#include <stdio.h>\n"
"#include <stdlib.h>\n"
"typedef enum { TIPO_INT, TIPO_FLOAT, TIPO_CHAR, TIPO_BOOL } TipoVar;\n"
"typedef struct {\n"
"    TipoVar tipo;\n"
"    union {\n"
"        int v_int;\n"
"        float v_float;\n"
"        char v_char;\n"
"        int v_bool;\n"
"    } valor;\n"
"} Var;\n"
"Var cria_int(int v) { Var res; res.tipo = TIPO_INT; res.valor.v_int = v; return res; }\n"
"Var cria_float(float v) { Var res; res.tipo = TIPO_FLOAT; res.valor.v_float = v; return res; }\n"
"Var cria_char(char v) { Var res; res.tipo = TIPO_CHAR; res.valor.v_char = v; return res; }\n"
"Var cria_bool(int v) { Var res; res.tipo = TIPO_BOOL; res.valor.v_bool = v; return res; }\n"
"void print_dinamico(Var v) {\n"
"    switch(v.tipo) {\n"
"        case TIPO_INT: printf(\"%d\\n\", v.valor.v_int); break;\n"
"        case TIPO_FLOAT: printf(\"%f\\n\", v.valor.v_float); break;\n"
"        case TIPO_CHAR: printf(\"%c\\n\", v.valor.v_char); break;\n"
"        case TIPO_BOOL: printf(\"%s\\n\", v.valor.v_bool ? \"true\" : \"false\"); break;\n"
"    }\n"
"}\n"
"void erro_runtime(const char* operacao) {\n"
"    printf(\"Erro de Execucao: Tipos incompativeis para a operacao '%s'.\\n\", operacao);\n"
"    exit(1);\n"
"}\n"
"Var soma_dinamica(Var a, Var b) {\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_INT) return cria_int(a.valor.v_int + b.valor.v_int);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_FLOAT) return cria_float(a.valor.v_float + b.valor.v_float);\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_FLOAT) return cria_float(a.valor.v_int + b.valor.v_float);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_INT) return cria_float(a.valor.v_float + b.valor.v_int);\n"
"    erro_runtime(\"+\"); return cria_int(0);\n"
"}\n"
"Var sub_dinamica(Var a, Var b) {\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_INT) return cria_int(a.valor.v_int - b.valor.v_int);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_FLOAT) return cria_float(a.valor.v_float - b.valor.v_float);\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_FLOAT) return cria_float(a.valor.v_int - b.valor.v_float);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_INT) return cria_float(a.valor.v_float - b.valor.v_int);\n"
"    erro_runtime(\"-\"); return cria_int(0);\n"
"}\n"
"Var mult_dinamica(Var a, Var b) {\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_INT) return cria_int(a.valor.v_int * b.valor.v_int);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_FLOAT) return cria_float(a.valor.v_float * b.valor.v_float);\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_FLOAT) return cria_float(a.valor.v_int * b.valor.v_float);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_INT) return cria_float(a.valor.v_float * b.valor.v_int);\n"
"    erro_runtime(\"*\"); return cria_int(0);\n"
"}\n"
"Var div_dinamica(Var a, Var b) {\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_INT) return cria_int(a.valor.v_int / b.valor.v_int);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_FLOAT) return cria_float(a.valor.v_float / b.valor.v_float);\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_FLOAT) return cria_float(a.valor.v_int / b.valor.v_float);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_INT) return cria_float(a.valor.v_float / b.valor.v_int);\n"
"    erro_runtime(\"/\"); return cria_int(0);\n"
"}\n"
"Var maior_dinamico(Var a, Var b) {\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_int > b.valor.v_int);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_float > b.valor.v_float);\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_int > b.valor.v_float);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_float > b.valor.v_int);\n"
"    erro_runtime(\">\"); return cria_bool(0);\n"
"}\n"
"Var menor_dinamico(Var a, Var b) {\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_int < b.valor.v_int);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_float < b.valor.v_float);\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_int < b.valor.v_float);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_float < b.valor.v_int);\n"
"    erro_runtime(\"<\"); return cria_bool(0);\n"
"}\n"
"Var maior_igual_dinamico(Var a, Var b) {\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_int >= b.valor.v_int);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_float >= b.valor.v_float);\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_int >= b.valor.v_float);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_float >= b.valor.v_int);\n"
"    erro_runtime(\">=\"); return cria_bool(0);\n"
"}\n"
"Var menor_igual_dinamico(Var a, Var b) {\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_int <= b.valor.v_int);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_float <= b.valor.v_float);\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_int <= b.valor.v_float);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_float <= b.valor.v_int);\n"
"    erro_runtime(\"<=\"); return cria_bool(0);\n"
"}\n"
"Var igual_dinamico(Var a, Var b) {\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_int == b.valor.v_int);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_float == b.valor.v_float);\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_int == b.valor.v_float);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_float == b.valor.v_int);\n"
"    if (a.tipo == TIPO_CHAR && b.tipo == TIPO_CHAR) return cria_bool(a.valor.v_char == b.valor.v_char);\n"
"    if (a.tipo == TIPO_BOOL && b.tipo == TIPO_BOOL) return cria_bool(a.valor.v_bool == b.valor.v_bool);\n"
"    erro_runtime(\"==\"); return cria_bool(0);\n"
"}\n"
"Var diferente_dinamico(Var a, Var b) {\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_int != b.valor.v_int);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_float != b.valor.v_float);\n"
"    if (a.tipo == TIPO_INT && b.tipo == TIPO_FLOAT) return cria_bool(a.valor.v_int != b.valor.v_float);\n"
"    if (a.tipo == TIPO_FLOAT && b.tipo == TIPO_INT) return cria_bool(a.valor.v_float != b.valor.v_int);\n"
"    if (a.tipo == TIPO_CHAR && b.tipo == TIPO_CHAR) return cria_bool(a.valor.v_char != b.valor.v_char);\n"
"    if (a.tipo == TIPO_BOOL && b.tipo == TIPO_BOOL) return cria_bool(a.valor.v_bool != b.valor.v_bool);\n"
"    erro_runtime(\"!=\"); return cria_bool(0);\n"
"}\n"
"Var and_dinamico(Var a, Var b) {\n"
"    if (a.tipo == TIPO_BOOL && b.tipo == TIPO_BOOL) return cria_bool(a.valor.v_bool && b.valor.v_bool);\n"
"    erro_runtime(\"&&\"); return cria_bool(0);\n"
"}\n"
"Var or_dinamico(Var a, Var b) {\n"
"    if (a.tipo == TIPO_BOOL && b.tipo == TIPO_BOOL) return cria_bool(a.valor.v_bool || b.valor.v_bool);\n"
"    erro_runtime(\"||\"); return cria_bool(0);\n"
"}\n"
"Var not_dinamico(Var a) {\n"
"    if (a.tipo == TIPO_BOOL) return cria_bool(!a.valor.v_bool);\n"
"    erro_runtime(\"!\"); return cria_bool(0);\n"
"}\n";

%}

// Literais
%token TK_INT
%token TK_FLOAT
%token TK_CHAR
%token TK_BOOL

%token TK_PRINT

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
	/* Início			*/
PROGRAMA 	: LISTA_COMANDOS
			{
				codigo_gerado = runtime_c + "\nint main(void) {\n";

				for (int i = 1; i <= var_temp_qnt; i++) {
					codigo_gerado += "\tVar t" + to_string(i) + ";\n";
				}

				for (const string& nome_var : variaveis_declaradas) {
					codigo_gerado += "\tVar " + nome_var + ";\n";
				}

				codigo_gerado += "\n" + $1.traducao;

				codigo_gerado += "\treturn 0;\n}\n";
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

/* Comando */
CMD			: TK_ID '=' E ';'
			{
				registrar_variavel($1.label);
				$$.traducao = $3.traducao + "\t" + $1.label + " = " + $3.label + ";\n";
			}
			| TK_PRINT '(' E ')' ';'
			{
				$$.traducao = $3.traducao + "\tprint_dinamico(" + $3.label + ");\n";
			}
			| E ';'
			{
                $$.traducao = $1.traducao;
			}
		    ;

/* Expressão 		*/
	/* Identificador		*/
E 			: TK_ID
			{
				$$.label = gentempcode();
				$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
			}
	
	/*		  Literais			*/
			| TK_INT
			{
				$$.label = gentempcode();
				$$.traducao = "\t" + $$.label + " = cria_int(" + $1.label + ");\n";
			}

			| TK_FLOAT
			{
				$$.label = gentempcode();
				$$.traducao = "\t" + $$.label + " = cria_float(" + $1.label + ");\n";
			}

			| TK_CHAR
			{
				$$.label = gentempcode();
				$$.traducao = "\t" + $$.label + " = cria_char(" + $1.label + ");\n";
			}

			| TK_BOOL
			{
				$$.label = gentempcode();
				string valor_c = ($1.label == "true") ? "1" : "0";
				$$.traducao = "\t" + $$.label + " = cria_bool(" + valor_c + ");\n"; 
			}

	/* Operadores Aritméticos	*/ 
			| E '+' E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + 
					"\t" + $$.label + " = soma_dinamica(" + $1.label + ", " + $3.label + ");\n";
			}

			| E '-' E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + 
					"\t" + $$.label + " = sub_dinamica(" + $1.label + ", " + $3.label + ");\n";
			}

			| E '*' E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + 
					"\t" + $$.label + " = mult_dinamica(" + $1.label + ", " + $3.label + ");\n";
			}

			| E '/' E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + 
					"\t" + $$.label + " = div_dinamica(" + $1.label + ", " + $3.label + ");\n";
			}

	/* Operadores Relacionais	*/ 
			| E '>' E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao +
				"\t" + $$.label + " = maior_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E '<' E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao +
				"\t" + $$.label + " = menor_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E TK_GE E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao +
				"\t" + $$.label + " = maior_igual_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E TK_LE E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao +
				"\t" + $$.label + " = menor_igual_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E TK_EQ E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + 
				"\t" + $$.label + " = igual_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E TK_DIF E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao +
				"\t" + $$.label + " = diferente_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

	/* Operadores Lógicos    */ 
			| E TK_AND E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = and_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E TK_OR E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = or_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| '!' E
			{
				$$.label = gentempcode();
				$$.traducao = $2.traducao + "\t" + $$.label + " = not_dinamico(" + $2.label + ");\n";
			}

	/* Parênteses		*/ 
			| '(' E ')'
			{
				$$.label = $2.label;
				$$.traducao = $2.traducao;
			}
			;

%%

#include "lex.yy.c"



int yyparse();

int main(int argc, char* argv[]) {
	var_temp_qnt = 0;

	if (yyparse() == 0)
		cout << codigo_gerado;

	return 0;
}

void yyerror(string MSG) {
	cerr << "Erro na linha " << linha << ": " << MSG << endl;
}
