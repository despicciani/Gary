%{
#include <iostream>
#include <string>
#include <vector>
#include <unordered_map>
#include <stack>

#define YYSTYPE atributos

using namespace std;

int var_temp_qnt;
int var_cond_qnt = 0;
int label_qnt = 0;
int linha = 1;
int id_escopo = 0;
string codigo_gerado;

// Pilhas para switch
stack<string> switch_var_stack;
stack<string> switch_fim_stack;

// Pilha para elif
stack<string> elif_fim_stack;

// Pilhas para Break e Continue
stack<string> loop_break_stack;
stack<string> loop_continue_stack;

struct atributos {
	string label;
	string traducao;
};

struct Simbolo {
	string label;
};

vector<string> variaveis_declaradas;
vector<string> variaveis_globais;
vector<unordered_map<string, Simbolo>> pilha_tabela_simbolos;

int yylex(void);
void yyerror(string);

string gentempcode() {
	var_temp_qnt++;
	return "t" + to_string(var_temp_qnt);
}

string gencondcode() {
	var_cond_qnt++;
	return "c" + to_string(var_cond_qnt);
}

string gen_label() {
    label_qnt++;
    return "LBL_CTRL_" + to_string(label_qnt);
}

void registrar_variavel(string nome) {
	bool ja_existe = false;

	for (auto tabela_simbolos = pilha_tabela_simbolos.rbegin(); tabela_simbolos != pilha_tabela_simbolos.rend(); ++tabela_simbolos)
		if (tabela_simbolos->count(nome)) {
			ja_existe = true;
			break;
		}

	if (!ja_existe) {
		Simbolo s;
		
		// Caso esteja no escopo padrão
		if (pilha_tabela_simbolos.size() == 1) {
			s.label = "var_0_" + nome;
		}
		else {
		s.label = "var_" + to_string(id_escopo) + "_" + nome;
		}
		
		pilha_tabela_simbolos.back()[nome] = s;
		variaveis_declaradas.push_back(s.label);
	}
}

void registrar_variavel_global(string nome) {
	if (!pilha_tabela_simbolos.front().count(nome)) {
		Simbolo s;
		s.label = "global_" + nome;

		// Injeta na base da pilha (escopo 0) para que ela não morra 
		// quando o bloco atual terminar.
		pilha_tabela_simbolos.front()[nome] = s;
	
		// Adiciona no vetor de globais
		variaveis_declaradas.push_back(s.label);
	}

	// Salva no vetor de globais (verificando para não duplicar)
    bool ja_existe = false;
    for (string g : variaveis_globais) {
        if (g == nome) {
            ja_existe = true;
            break;
        }
    }

    if (!ja_existe) {
        variaveis_globais.push_back(nome);
    }
}

void registrar_variavel_local(string nome) {	
	if (!pilha_tabela_simbolos.back().count(nome)) {
		Simbolo s;
		s.label = "var_" + to_string(id_escopo) + "_" + nome;

		pilha_tabela_simbolos.back()[nome] = s;
		variaveis_declaradas.push_back(s.label);
	}
}

Simbolo buscar_Simbolo(string nome) {
	for (auto tabela_simbolos = pilha_tabela_simbolos.rbegin(); tabela_simbolos != pilha_tabela_simbolos.rend(); ++tabela_simbolos)
		if (tabela_simbolos->count(nome)) {
			return tabela_simbolos->at(nome);
		}
	yyerror("Erro Semantico: Variavel '" + nome + "' nao inicializada.");
	exit(1);
	
}

// Código C que vai antes da main
string runtime_c = 
	"#include <stdio.h>\n"
	"#include <stdlib.h>\n"
	"#include <string.h>\n\n"

	// Função para Saber Tamanho da String
	"int lenstr(const char* str) {\n"
		"    int len;\n"
		"	 int t1;\n"
		"    char c;\n"
		"    len = 0;\n"
		"L_LOOP:\n"
		"    c = str[len];\n"
		"    t1 = (c == '\\0');\n"
		"    if (t1) goto L_FIM;\n"
		"    len = len + 1;\n"
		"    goto L_LOOP;\n"
		"L_FIM:\n"
		"    return len;\n"
	"}\n"
	"\n"

	"typedef enum { TIPO_INT, TIPO_FLOAT, TIPO_CHAR, TIPO_BOOL, TIPO_STRING } TipoVar;\n"

	// Estrutura de Dados Principal
	"typedef struct {\n"
		"    TipoVar tipo;\n"
		"    union {\n"
		"        int v_int;\n"
		"        float v_float;\n"
		"        char v_char;\n"
		"        int v_bool;\n"
		"        char* v_string;\n"
		"    } valor;\n"
		"\n"
	"} Var;\n"

	// Funções que Criam Valores dos Tipos
	"Var cria_int(int v) { Var res; res.tipo = TIPO_INT; res.valor.v_int = v; return res; }\n"
	"Var cria_float(float v) { Var res; res.tipo = TIPO_FLOAT; res.valor.v_float = v; return res; }\n"
	"Var cria_char(char v) { Var res; res.tipo = TIPO_CHAR; res.valor.v_char = v; return res; }\n"
	"Var cria_bool(int v) { Var res; res.tipo = TIPO_BOOL; res.valor.v_bool = v; return res; }\n"
	"\n"
	"Var cria_string(const char* v) {\n"
		"    Var res; int len; char* ptr;\n"
		"    res.tipo = TIPO_STRING;\n"
		"    len = lenstr(v);\n"
		"    len = len + 1;\n"
		"    ptr = (char*)malloc(len);\n"
		"    strcpy(ptr, v);\n"
		"    res.valor.v_string = ptr;\n"
		"    return res;\n"
	"}\n"
	"\n"

	// Função de Erro de Execução
	"void erro_runtime(const char* operacao) {\n"
		"    printf(\"Erro de Execucao: Tipos incompativeis para a operacao '%s'.\\n\", operacao);\n"
		"    exit(1);\n"
	"}\n"
	"\n"

	// Função que Verifica se a Variável é Considerada Verdadeira
	"int eh_verdadeiro(Var v) {\n"
		"    int c;\n"
		"    int t;\n"
		"    c = (v.tipo != TIPO_BOOL);\n"
		"    if (c) goto L_INT;\n"
		"    return v.valor.v_bool;\n"
		"L_INT:\n"
		"    c = (v.tipo != TIPO_INT);\n"
		"    if (c) goto L_FLOAT;\n"
		"    t = (v.valor.v_int != 0);\n"
		"    return t;\n"
		"L_FLOAT:\n"
		"    c = (v.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L_STR;\n"
		"    t = (v.valor.v_float != 0.0);\n"
		"    return t;\n"
		"L_STR:\n"
		"    c = (v.tipo != TIPO_STRING);\n"
		"    if (c) goto L_CHAR;\n"
		"    t = lenstr(v.valor.v_string);\n"
		"    c = (t > 0);\n"
		"    return c;\n"
		"L_CHAR:\n"
		"    c = (v.tipo != TIPO_CHAR);\n"
		"    if (c) goto L_FIM;\n"
		"    t = (v.valor.v_char != '\\0');\n"
		"    return t;\n"
		"L_FIM:\n"
		"    return 1;\n"
	"}\n"
	"\n"

	// Função para Printar
	"void print_dinamico(Var v) {\n"
		"    int cond;\n"
		"L_PRINT_INT:\n"
		"    cond = (v.tipo != TIPO_INT);\n"
		"    if (cond) goto L_PRINT_FLOAT;\n"
		"    printf(\"%d\\n\", v.valor.v_int);\n"
		"    goto L_PRINT_FIM;\n"
		"L_PRINT_FLOAT:\n"
		"    cond = (v.tipo != TIPO_FLOAT);\n"
		"    if (cond) goto L_PRINT_CHAR;\n"
		"    printf(\"%f\\n\", v.valor.v_float);\n"
		"    goto L_PRINT_FIM;\n"
		"L_PRINT_CHAR:\n"
		"    cond = (v.tipo != TIPO_CHAR);\n"
		"    if (cond) goto L_PRINT_BOOL;\n"
		"    printf(\"%c\\n\", v.valor.v_char);\n"
		"    goto L_PRINT_FIM;\n"
		"L_PRINT_BOOL:\n"
		"    cond = (v.tipo != TIPO_BOOL);\n"
		"    if (cond) goto L_PRINT_STRING;\n"
		"    cond = (v.valor.v_bool != 1);\n"
		"    if (cond) goto L_PRINT_FALSE;\n"
		"    printf(\"true\\n\");\n"
		"    goto L_PRINT_FIM;\n"
		"L_PRINT_STRING:\n" 
		"    cond = (v.tipo != TIPO_STRING);\n"
		"    if (cond) goto L_PRINT_FIM;\n"
		"    printf(\"%s\\n\", v.valor.v_string);\n"
		"    goto L_PRINT_FIM;\n"
		"L_PRINT_FALSE:\n"
		"    printf(\"false\\n\");\n"
		"L_PRINT_FIM:\n"
		"    return;\n"
	"}\n"
	"\n"
  
	// Função de Input
	"Var input_dinamico() {\n"
		"    char* buffer;\n"
		"    char* new_buf;\n"
		"    int cap;\n"
		"    int len;\n"
		"    int ch;\n"
		"    int t1;\n"
		"    int t2;\n"
		"    int t_int;\n"       
		"    float t_float;\n"
	  	"    char t_char;\n"
		"    char* endptr;\n"
		"    long val_int;\n"
		"    double val_float;\n"
		"    Var res;\n"
		"\n"
		"    cap = 32;\n"
		"    buffer = (char*)malloc(cap);\n"
		"    len = 0;\n"
		"\n"
		"L_READ:\n"
		"    ch = fgetc(stdin);\n" // Lê caracter por caracter
		"    t1 = (ch == EOF);\n"
		"    if (t1) goto L_FIM_READ;\n"
		"    t1 = (ch == '\\n');\n"
		"    if (t1) goto L_FIM_READ;\n"
		"    t1 = (ch == '\\r');\n" 
		"    if (t1) goto L_READ;\n" // Ignora o /r q vem antes do /n no windows
		"\n"
		"	 t_char = (char)ch;\n"
		"    buffer[len] = t_char;\n"
		"    len = len + 1;\n"
		"    t1 = (len < cap);\n"
		"    if (t1) goto L_READ;\n"
		"\n"
		"    cap = cap * 2;\n"
		"    new_buf = (char*)realloc(buffer, cap);\n"
		"    buffer = new_buf;\n"
		"    goto L_READ;\n"
		"\n"
		"L_FIM_READ:\n"
		"    buffer[len] = '\\0';\n"
		"\n"
		"    t1 = strcmp(buffer, \"true\");\n"
		"    t2 = (t1 != 0);\n"
		"    if (t2) goto L_FALSE;\n"
		"    res = cria_bool(1);\n"
		"    goto FIM;\n"
		"L_FALSE:\n"
		"    t1 = strcmp(buffer, \"false\");\n"
		"    t2 = (t1 != 0);\n"
		"    if (t2) goto L_INT;\n"
		"    res = cria_bool(0);\n"
		"    goto FIM;\n"
		"L_INT:\n"
		"    val_int = strtol(buffer, &endptr, 10);\n"
		"    t1 = (endptr == buffer);\n"
		"    if (t1) goto L_FLOAT;\n"
		"    t2 = (*endptr != '\\0');\n"
		"    if (t2) goto L_FLOAT;\n"
		"    t_int = (int)val_int;\n"
		"    res = cria_int(t_int);\n"
		"    goto FIM;\n"
		"L_FLOAT:\n"
		"    val_float = strtod(buffer, &endptr);\n"
		"    t1 = (endptr == buffer);\n"
		"    if (t1) goto L_CHAR;\n"
		"    t2 = (*endptr != '\\0');\n"
		"    if (t2) goto L_CHAR;\n"
		"    t_float = (float)val_float;\n"
		"    res = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L_CHAR:\n"
		"    t1 = (len != 1);\n"
		"    if (t1) goto L_STR;\n"
		"    t_char = buffer[0];\n"
		"    res = cria_char(t_char);\n"
		"    goto FIM;\n"
		"L_STR:\n"
		"    res = cria_string(buffer);\n"
		"FIM:\n"
		"    free(buffer);\n"
		"    return res;\n"
	"}\n"
	"\n"

	// Função de Soma
	"Var soma_dinamica(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    int t_int;\n"
		"    int len_a;\n"
		"    int len_b;\n"
		"	 int len_tot;\n"
		"    float t_float;\n"
		"    char* tmp_str;\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    t_int = a.valor.v_int + b.valor.v_int;\n"
		"    r = cria_int(t_int);\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    t_float = a.valor.v_float + b.valor.v_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L3;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L3;\n"
		"    t_float = (float)a.valor.v_int;\n"
		"    t_float = t_float + b.valor.v_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L4;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L4;\n"
		"    t_float = (float)b.valor.v_int;\n"
		"    t_float = a.valor.v_float + t_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L4:\n"
		"    c = (a.tipo != TIPO_STRING);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_STRING);\n"
		"    if (c) goto L_ERR;\n"
		"    len_a = lenstr(a.valor.v_string);\n"
		"    len_b = lenstr(b.valor.v_string);\n"
		"    len_tot = len_a + len_b;\n"
		"    len_tot = len_tot + 1;\n"
		"    tmp_str = (char*)malloc(len_tot);\n"
		"    strcpy(tmp_str, a.valor.v_string);\n"
		"    strcat(tmp_str, b.valor.v_string);\n"
		"    r = cria_string(tmp_str);\n"
		"    free(tmp_str);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"+\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de Subtração
	"Var sub_dinamica(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"	 int t_int;\n"
		"    float t_float;\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    t_int = a.valor.v_int - b.valor.v_int;\n"
		"    r = cria_int(t_int);\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    t_float = a.valor.v_float - b.valor.v_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L3;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L3;\n"
		"    t_float = (float)a.valor.v_int;\n"
		"    t_float = t_float - b.valor.v_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L_ERR;\n"
		"    t_float = (float)b.valor.v_int;\n"
		"    t_float = a.valor.v_float - t_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"-\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de Multiplicação
	"Var mult_dinamica(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    int t_int;\n"
		"    float t_float;\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    t_int = a.valor.v_int * b.valor.v_int;\n"
		"    r = cria_int(t_int);\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    t_float = a.valor.v_float * b.valor.v_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L3;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L3;\n"
		"    t_float = (float)a.valor.v_int;\n"
		"    t_float = t_float * b.valor.v_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L_ERR;\n"
		"    t_float = (float)b.valor.v_int;\n"
		"    t_float = a.valor.v_float * t_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"*\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de Divisão
	"Var div_dinamica(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c, t_int;\n"
		"    float t_float;\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    t_int = a.valor.v_int / b.valor.v_int;\n"
		"    r = cria_int(t_int);\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    t_float = a.valor.v_float / b.valor.v_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L3;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L3;\n"
		"    t_float = (float)a.valor.v_int;\n"
		"    t_float = t_float / b.valor.v_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L_ERR;\n"
		"    t_float = (float)b.valor.v_int;\n"
		"    t_float = a.valor.v_float / t_float;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"/\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de ==
	"Var igual_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (a.valor.v_int == b.valor.v_int);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (a.valor.v_float == b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L3;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L3;\n"
		"    t_float = (float)a.valor.v_int;\n"
		"    c = (t_float == b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L4;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L4;\n"
		"    t_float = (float)b.valor.v_int;\n"
		"    c = (a.valor.v_float == t_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L4:\n"
		"    c = (a.tipo != TIPO_CHAR);\n"
		"    if (c) goto L5;\n"
		"    c = (b.tipo != TIPO_CHAR);\n"
		"    if (c) goto L5;\n"
		"    c = (a.valor.v_char == b.valor.v_char);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L5:\n"
		"    c = (a.tipo != TIPO_BOOL);\n"
		"    if (c) goto L6;\n"
		"    c = (b.tipo != TIPO_BOOL);\n"
		"    if (c) goto L6;\n"
		"    c = (a.valor.v_bool == b.valor.v_bool);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L6:\n"
		"    c = (a.tipo != TIPO_STRING);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_STRING);\n"
		"    if (c) goto L_ERR;\n"
		"    c = strcmp(a.valor.v_string, b.valor.v_string);\n"
		"    c = (c == 0);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"==\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de &&
	"Var and_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    c = (a.tipo != TIPO_BOOL);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_BOOL);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (a.valor.v_bool && b.valor.v_bool);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"&&\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de >
	"Var maior_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (a.valor.v_int > b.valor.v_int);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (a.valor.v_float > b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L3;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L3;\n"
		"    t_float = (float)a.valor.v_int;\n"
		"    c = (t_float > b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L_ERR;\n"
		"    t_float = (float)b.valor.v_int;\n"
		"    c = (a.valor.v_float > t_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\">\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de <
	"Var menor_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (a.valor.v_int < b.valor.v_int);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (a.valor.v_float < b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L3;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L3;\n"
		"    t_float = (float)a.valor.v_int;\n"
		"    c = (t_float < b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L_ERR;\n"
		"    t_float = (float)b.valor.v_int;\n"
		"    c = (a.valor.v_float < t_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"<\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de >=
	"Var maior_igual_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (a.valor.v_int >= b.valor.v_int);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (a.valor.v_float >= b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L3;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L3;\n"
		"    t_float = (float)a.valor.v_int;\n"
		"    c = (t_float >= b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L_ERR;\n"
		"    t_float = (float)b.valor.v_int;\n"
		"    c = (a.valor.v_float >= t_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\">=\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de <=
	"Var menor_igual_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (a.valor.v_int <= b.valor.v_int);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (a.valor.v_float <= b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L3;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L3;\n"
		"    t_float = (float)a.valor.v_int;\n"
		"    c = (t_float <= b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L_ERR;\n"
		"    t_float = (float)b.valor.v_int;\n"
		"    c = (a.valor.v_float <= t_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"<=\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de !=
	"Var diferente_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    c = (a.valor.v_int != b.valor.v_int);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    c = (a.valor.v_float != b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L3;\n"
		"    c = (b.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L3;\n"
		"    t_float = (float)a.valor.v_int;\n"
		"    c = (t_float != b.valor.v_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L4;\n"
		"    c = (b.tipo != TIPO_INT);\n"
		"    if (c) goto L4;\n"
		"    t_float = (float)b.valor.v_int;\n"
		"    c = (a.valor.v_float != t_float);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L4:\n"
		"    c = (a.tipo != TIPO_CHAR);\n"
		"    if (c) goto L5;\n"
		"    c = (b.tipo != TIPO_CHAR);\n"
		"    if (c) goto L5;\n"
		"    c = (a.valor.v_char != b.valor.v_char);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L5:\n"
		"    c = (a.tipo != TIPO_BOOL);\n"
		"    if (c) goto L6;\n"
		"    c = (b.tipo != TIPO_BOOL);\n"
		"    if (c) goto L6;\n"
		"    c = (a.valor.v_bool != b.valor.v_bool);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L6:\n"
		"    c = (a.tipo != TIPO_STRING);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_STRING);\n"
		"    if (c) goto L_ERR;\n"
		"    c = strcmp(a.valor.v_string, b.valor.v_string);\n"
		"    c = (c != 0);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"!=\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de ||
	"Var or_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    c = (a.tipo != TIPO_BOOL);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (b.tipo != TIPO_BOOL);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (a.valor.v_bool || b.valor.v_bool);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"||\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de !
	"Var not_dinamico(Var a) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    c = (a.tipo != TIPO_BOOL);\n"
		"    if (c) goto L_ERR;\n"
		"    c = (!a.valor.v_bool);\n"
		"    r = cria_bool(c);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"!\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n";

%}

// Literais
%token TK_INT
%token TK_FLOAT
%token TK_CHAR
%token TK_BOOL
%token TK_STRING

// Entrada e Saída
%token TK_PRINT
%token TK_INPUT

// Comandos
%token TK_IF TK_ELSE TK_ELIF TK_WHILE TK_DO TK_FOR TK_SWITCH TK_CASE TK_DEFAULT
%token TK_IN TK_TO TK_INC
%token TK_BREAK TK_CONTINUE

// Variável GLobal e Local
%token TK_GLOBAL
%token TK_LOCAL

// Identificador
%token TK_ID

// tokens da identacao por tabulacao
%token TK_INDENT TK_DEDENT TK_NEWLINE

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

				// Declara Temporárias
				for (int i = 1; i <= var_temp_qnt; i++) {
					codigo_gerado += "\tVar t" + to_string(i) + ";\n";
				}

				// Declara Variáveis de Condição
				for (int i = 1; i <= var_cond_qnt; i++) {
					codigo_gerado += "\tint c" + to_string(i) + ";\n";
				}

				// Declara Variáveis do Usuário
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

	/* Bloco aceita Indentação ou Chaves */
BLOCO		: TK_NEWLINE TK_INDENT LISTA_COMANDOS TK_DEDENT 
			{ 
				$$.traducao = $3.traducao; 
			}
			;

	/* Prefixo do IF, evita possíveis conflitos futuros */
IF_PREFIXO	: TK_IF E ':'
			{
				pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
				id_escopo++;

				$$.label = $2.label;
				$$.traducao = $2.traducao; 
			}
			;

	/* Prefixo do ELIF (Abre o escopo e evita possíveis conflitos futuros) */
ELIF_PREFIXO: TK_ELIF E ':'
			{
				pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
				id_escopo++;
				
				$$.label = $2.label;
				$$.traducao = $2.traducao;
			}
			;
	
	/* Cascata de alternativas: Pode ser vários ELIFs, um ELSE no final, ou nada */
BLOCOS_ALTERNATIVOS : ELIF_PREFIXO BLOCO
					{
						pilha_tabela_simbolos.pop_back();
					}
					BLOCOS_ALTERNATIVOS
					{
						string l_falso = gen_label();
						string l_fim = elif_fim_stack.top(); // Pega o label de fim
						string cond = gencondcode();

						$$.traducao = $1.traducao +
									  "\t" + cond + " = eh_verdadeiro(" + $1.label + ");\n" + 
									  "\t" + cond + " = !" + cond + ";\n" +
									  "\tif (" + cond + ") goto " + l_falso + ";\n" +
									  $2.traducao + // Comandos deste ELIF
									  "\tgoto " + l_fim + ";\n" +
									  l_falso + ":\n" +
									  $4.traducao; // Próximos ELIFs ou ELSE
					}
					| TK_ELSE ':'
					{
						pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
						id_escopo++;
					}
					BLOCO
					{
						pilha_tabela_simbolos.pop_back();
						$$.traducao = $4.traducao; // O else só joga a tradução pra cima
					}
					| /* Vazio (Encerra a cascata) */
					{
						$$.traducao = "";
					}
					;

	/* Comando */
	/* Atribuição */
CMD			: TK_ID '=' E TK_NEWLINE
			{
				registrar_variavel($1.label);
				Simbolo s = buscar_Simbolo($1.label);
				$$.traducao = $3.traducao + "\t" + s.label + " = " + $3.label + ";\n";
			}

	/* Absorve linhas sobrando no código */
			| TK_NEWLINE
			{
				$$.traducao = ""; 
			}

	/* Regra para Print */
			| TK_PRINT '(' E ')' TK_NEWLINE
			{
				$$.traducao = $3.traducao + "\tprint_dinamico(" + $3.label + ");\n";
			}

	/* Expressões soltas */
			| E TK_NEWLINE
			{
                $$.traducao = $1.traducao;
			}

	/*	Variáveis Globais   */
			| TK_GLOBAL TK_ID TK_NEWLINE
			{
				registrar_variavel_global($2.label);
				$$.traducao = "";
			}

	/*    Variável Local    */		
			| TK_LOCAL TK_ID TK_NEWLINE
			{
				registrar_variavel_local($2.label);
				$$.traducao = "";
			}

	/* Bloco Anônimo por Identação */
			| TK_INDENT 
			{
				// Abre um escopo temporário para o bloco solto
				pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
				id_escopo++;
			}
			LISTA_COMANDOS TK_DEDENT
			{
				// Fecha o escopo temporário
				pilha_tabela_simbolos.pop_back();

				$$.traducao = $3.traducao; 
			}

	/* Bloco Anônimo por Chaves   */
			| '{' 
			{
				pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
				id_escopo++;
			}
			LISTA_COMANDOS '}'
			{
				pilha_tabela_simbolos.pop_back();
				$$.traducao = $3.traducao; 
			}

	/* x++ */
			| TK_ID TK_INC TK_NEWLINE
			{
				Simbolo s = buscar_Simbolo($1.label);
				
				string temp_um = gentempcode();

				// TAC: x = soma_dinamica(x, 1);
				$$.traducao = "\t" + temp_um + " = cria_int(1);\n" +
							  "\t" + s.label + " = soma_dinamica(" + s.label + ", " + temp_um + ");\n";
			}

	/* Break */
			| TK_BREAK TK_NEWLINE
			{
				if (loop_break_stack.empty()) {
					yyerror("Erro Semantico: 'break' fora de um laco de repeticao.");
					exit(1);
				}
				$$.traducao = "\tgoto " + loop_break_stack.top() + ";\n";
			}

	/* Continue */
			| TK_CONTINUE TK_NEWLINE
			{
				if (loop_continue_stack.empty()) {
					yyerror("Erro Semantico: 'continue' fora de um laco de repeticao.");
					exit(1);
				}
				$$.traducao = "\tgoto " + loop_continue_stack.top() + ";\n";
			}

	/* if Genérico (Absorve if isolado, if-else, if-elif-else) */
			| IF_PREFIXO BLOCO 
			{
				pilha_tabela_simbolos.pop_back();
				elif_fim_stack.push(gen_label());
			}
			BLOCOS_ALTERNATIVOS
			{
				string l_falso = gen_label();
				string l_fim = elif_fim_stack.top(); // Resgata o label de fim
				elif_fim_stack.pop(); // Limpa a pilha
				string cond = gencondcode();

				$$.traducao = $1.traducao + 
							  "\t" + cond + " = eh_verdadeiro(" + $1.label + ");\n" + 
							  "\t" + cond + " = !" + cond + ";\n" +
							  "\tif (" + cond + ") goto " + l_falso + ";\n" +
							  $2.traducao + // Comandos do IF principal
							  "\tgoto " + l_fim + ";\n" +
							  l_falso + ":\n" +
							  $4.traducao + // Toda a cascata de ELIFs e ELSE
							  l_fim + ":\n";
			}

	/* while */
			| TK_WHILE E ':'
			{
				pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
				id_escopo++;

				/* Break e Continue */
				loop_break_stack.push(gen_label());
				loop_continue_stack.push(gen_label());
			}
			BLOCO
			{
				pilha_tabela_simbolos.pop_back();

				string l_inicio = loop_continue_stack.top();
				string l_fim = loop_break_stack.top();
				loop_continue_stack.pop();
				loop_break_stack.pop();
				string cond = gencondcode();
				
				$$.traducao = l_inicio + ":\n" +
							  $2.traducao +
							  "\t" + cond + " = eh_verdadeiro(" + $2.label + ");\n" + 
							  "\t" + cond + " = !" + cond + ";\n" +
							  "\tif (" + cond + ") goto " + l_fim + ";\n" +
							  $5.traducao +
							  "\tgoto " + l_inicio + ";\n" +
							  l_fim + ":\n";
			}

	/* do while (executa o bloco e testa se eh true no final) */
			| TK_DO ':'
			{
				pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
				id_escopo++;

				/* Break e Continue */
				loop_break_stack.push(gen_label());
				loop_continue_stack.push(gen_label());
			}	
			BLOCO TK_WHILE E TK_NEWLINE
			{
				pilha_tabela_simbolos.pop_back();

				string l_inicio = gen_label();
				string l_continue = loop_continue_stack.top();
				string l_fim = loop_break_stack.top();
				loop_continue_stack.pop();
				loop_break_stack.pop();
				string cond = gencondcode();
				
				$$.traducao = l_inicio + ":\n" +
							  $4.traducao +
							  l_continue + ":\n" +
							  $6.traducao +
							  "\t" + cond + " = eh_verdadeiro(" + $6.label + ");\n" + 
							  "\tif (" + cond + ") goto " + l_inicio + ";\n" +
							  l_fim + ":\n";
			}

	/* for i in x to y: */
			| TK_FOR TK_ID TK_IN E TK_TO E ':'
			{
				pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
				id_escopo++;

				// registra a variavel iteradora (i)
				registrar_variavel($2.label);
				
				/* Break e Continue */
				loop_break_stack.push(gen_label());
				loop_continue_stack.push(gen_label());
			}
			BLOCO
			{
				// Busca Simbolo de i
				Simbolo s;
				s = buscar_Simbolo($2.label);
				
				pilha_tabela_simbolos.pop_back();

				string l_inicio = gen_label();
				string l_continue = loop_continue_stack.top();
				string l_fim = loop_break_stack.top();
				loop_continue_stack.pop();
				loop_break_stack.pop();

				// Temporária que avalia a condição
				string temp_cond = gentempcode();
				
				// Temporária com o valor 1, para somar (i=i+1)
				string temp_um = gentempcode();
				
				// inicializa i com o valor de x
				string trad_init = $4.traducao + "\t" + s.label + " = " + $4.label + ";\n";
				
				string cond = gencondcode();

				// monta o laço
				$$.traducao = trad_init + 
							  l_inicio + ":\n" +
							  $6.traducao + // avalia o teto (y)
							  "\t" + temp_cond + " = menor_igual_dinamico(" + s.label + ", " + $6.label + ");\n" +
							  "\t" + cond + " = eh_verdadeiro(" + temp_cond + ");\n" + 
							  "\t" + cond + " = !" + cond + ";\n" +
							  "\tif (" + cond + ") goto " + l_fim + ";\n" +
							  $9.traducao + // corpo do for
							  l_continue + ":\n" + 
							  "\t" + temp_um + " = cria_int(1);\n" + 
							  "\t" + s.label + " = soma_dinamica(" + s.label + ", " + temp_um + ");\n" + // i = i+1
							  "\tgoto " + l_inicio + ";\n" +
							  l_fim + ":\n";
			}

	/* switch case (basicamente uma cascata de ifs) */
			| TK_SWITCH E ':'
			{ 
				switch_var_stack.push($2.label); 
				switch_fim_stack.push(gen_label()); 
			} 
			BLOCO_CASOS
			{
				$$.traducao = $2.traducao + $5.traducao + switch_fim_stack.top() + ":\n";
				switch_var_stack.pop();
				switch_fim_stack.pop();
			}
		    ;

	/* regras relacionadas ao switch */
BLOCO_CASOS	: TK_NEWLINE TK_INDENT LISTA_CASOS TK_DEDENT 
			{ 
				$$.traducao = $3.traducao;
			}
			;

LISTA_CASOS	: CASO LISTA_CASOS 
			{ 
				$$.traducao = $1.traducao + $2.traducao; 
			}
			| DEFAULT 
			{ 
				$$.traducao = $1.traducao; 
			}
			| 
			{ 
				$$.traducao = ""; 
			}
			;

CASO		: TK_CASE E ':'
			{
				pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
				id_escopo++;
			}
			BLOCO
			{
				pilha_tabela_simbolos.pop_back();

				string l_prox_caso = gen_label();
				string var_switch = switch_var_stack.top();
				string l_fim = switch_fim_stack.top();
				string var_teste = gentempcode();
				string cond = gencondcode();

				$$.traducao = $2.traducao +
							  "\t" + var_teste + " = igual_dinamico(" + var_switch + ", " + $2.label + ");\n" +
							  "\t" + cond + " = eh_verdadeiro(" + var_teste + ");\n" + 
							  "\t" + cond + " = !" + cond + ";\n" + 
							  "\tif (" + cond + ") goto " + l_prox_caso + ";\n" +
							  $5.traducao +
							  "\tgoto " + l_fim + ";\n" +
							  l_prox_caso + ":\n";
			}
			;

DEFAULT		: TK_DEFAULT ':' 
			{
				pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
				id_escopo++;
			}
			BLOCO
			{
				pilha_tabela_simbolos.pop_back();
			
				string l_fim = switch_fim_stack.top();
				$$.traducao = $4.traducao + "\tgoto " + l_fim + ";\n";
			}
			;

	/* Expressão 			*/
	/* Identificador		*/
E 			: TK_ID
			{
				Simbolo s = buscar_Simbolo($1.label);
				$$.label = s.label;
				$$.traducao = "";
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

			| TK_STRING
			{
				$$.label = gentempcode();
				$$.traducao = "\t" + $$.label + " = cria_string(" + $1.label + ");\n";
			}

			| TK_BOOL
			{
				$$.label = gentempcode();
				string valor_c = ($1.label == "true") ? "1" : "0";
				$$.traducao = "\t" + $$.label + " = cria_bool(" + valor_c + ");\n"; 
			}

	/* Função Input */
			| TK_INPUT '(' ')'
			{
				$$.label = gentempcode();
				$$.traducao = "\t" + $$.label + " = input_dinamico();\n";
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

	pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());

	if (yyparse() == 0)
		cout << codigo_gerado;

	return 0;
}

void yyerror(string MSG) {
	cerr << "Erro na linha " << linha << ": " << MSG << endl;
}
