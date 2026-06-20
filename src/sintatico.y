%{
#include <iostream>
#include <string>
#include <vector>
#include <unordered_map>
#include <stack>
#include <algorithm>

#define YYSTYPE atributos

using namespace std;

// Variáveis que criam temporárias
int var_temp_qnt = 0;
int var_cond_qnt = 0;

// Variáveis que Criam Labels Personalizados
int label_qnt = 0;
int if_qnt = 0;
int for_qnt = 0;
int while_qnt = 0;
int do_while_qnt = 0;
int switch_qnt = 0;

// Pilhas de ID para aninhamento seguro
stack<int> if_id_stack;
stack<int> do_while_id_stack;
stack<int> for_id_stack;

// Variável que guarda qual Linha está atualmente
int linha = 1;

// Variável que guarda quantos escopos já foram abertos
int id_escopo = 0;

// Código Gerado pela Análise Sintática
string codigo_gerado;

// Pilhas para switch
stack<string> switch_var_stack;
stack<string> switch_fim_stack;

// Pilha para elif
stack<string> elif_fim_stack;

// Pilhas para Break e Continue
stack<string> loop_break_stack;
stack<string> loop_continue_stack;

// Pilha para erro no for
stack<int> for_linha_stack;

// Struct que pertence aos Terminais e Não Terminais da Gramática
struct atributos {
	string label;
	string traducao;
	int linha_token;
	vector<string> array_labels; // guarda os temporarios dos itens do array
};

// Struct para Tabela de Símbolos
struct Simbolo {
	string label;
};

// Vetor para Imprimir as Variáveis na Ordem em que Foram Declaradas
vector<string> variaveis_declaradas;

vector<string> variaveis_globais;

// Pilha (Vetor) de Tabela de Símbolos
vector<unordered_map<string, Simbolo>> pilha_tabela_simbolos;

// Vetor para não permitir que comandos aninhados usem a mesma variável iteradora
vector<string> iteradores_ativos;

bool em_funcao = false;
vector<string> variaveis_main;
vector<string> variaveis_func_atual;
vector<string> parametros_atuais;

int temp_start_func = 0;
int cond_start_func = 0;

vector<int> temporarias_main;
vector<int> cond_main;

string codigo_funcoes = "";
string codigo_headers_funcoes = ""; // Protótipos para permitir recursão/chamada fora de ordem

int yylex(void);
void yyerror(string);

// Gera Código para Temporária
string gentempcode() {
	var_temp_qnt++;
	if (!em_funcao) temporarias_main.push_back(var_temp_qnt);
	return "t" + to_string(var_temp_qnt);
}

string gencondcode() {
	var_cond_qnt++;
	if (!em_funcao) cond_main.push_back(var_cond_qnt);
	return "c" + to_string(var_cond_qnt);
}

// Gera Label
string gen_label(string prefixo = "CRTL") {
    label_qnt++;
    return "LBL_" + prefixo + "_" + to_string(label_qnt);
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
		if (pilha_tabela_simbolos.size() == 1) {
			s.label = "var_0_" + nome;
		} else {
			s.label = "var_" + to_string(id_escopo) + "_" + nome;
		}
		pilha_tabela_simbolos.back()[nome] = s;
		
		// Direciona a variável para a RAM local da função ou para o Main
		if (em_funcao) variaveis_func_atual.push_back(s.label);
		else variaveis_main.push_back(s.label);
	}
}

void registrar_variavel_global(string nome) {
	if (!pilha_tabela_simbolos.front().count(nome)) {
		Simbolo s;
		s.label = "global_" + nome;
		
		// Injeta na base da pilha (escopo 0)
		pilha_tabela_simbolos.front()[nome] = s;
	}

    // Usamos o label com "global_" para verificar e salvar
    string label_global = "global_" + nome;
    bool ja_existe = false;
    
	for (string g : variaveis_globais) {
        if (g == label_global) {
            ja_existe = true;
            break;
        }
    }

    if (!ja_existe) {
        variaveis_globais.push_back(label_global);
    }
}

void registrar_variavel_local(string nome) {	
	if (!pilha_tabela_simbolos.back().count(nome)) {
		Simbolo s;
		s.label = "var_" + to_string(id_escopo) + "_" + nome;

		pilha_tabela_simbolos.back()[nome] = s;
		
		// Direciona para a memória da função atual ou para o Main
		if (em_funcao) {
			variaveis_func_atual.push_back(s.label);
		} else {
			variaveis_main.push_back(s.label);
		}
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
	"int linha_execucao = 1;\n\n"

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

	"typedef enum { TIPO_INT, TIPO_FLOAT, TIPO_CHAR, TIPO_BOOL, TIPO_STRING, TIPO_ARRAY } TipoVar;\n"

	// Estrutura de dados principal
	"struct Var_struct;\n"
	"typedef struct Var_struct {\n"
	"    TipoVar tipo;\n"
	"    union {\n"
	"        int v_int;\n"
	"        float v_float;\n"
	"        char v_char;\n"
	"        int v_bool;\n"
	"        char* v_string;\n"
	"        struct {\n"
	"            int tamanho;\n"
	"            struct Var_struct* elementos;\n"
	"        } v_array;\n"
	"    } valor;\n"
	"} Var;\n"

	"void erro_runtime(const char* operacao);\n"
	"\n"

	// Arrays

	"Var cria_array(Var tamanho) {\n"
	"    Var res;\n"
	"    int c, tam;\n"
	"    c = (tamanho.tipo != TIPO_INT);\n"
	"    if (c) goto L_ERR;\n"
	"    tam = tamanho.valor.v_int;\n"
	"    res.tipo = TIPO_ARRAY;\n"
	"    res.valor.v_array.tamanho = tam;\n"
	"    res.valor.v_array.elementos = (struct Var_struct*)malloc(tam * sizeof(struct Var_struct));\n"
	"    return res;\n"
	"L_ERR:\n"
	"    erro_runtime(\"Array Size\");\n"
	"}\n"
	"\n"
	"Var get_array(Var arr, Var indice) {\n"
	"    int c;\n"
	"    c = (arr.tipo != TIPO_ARRAY);\n"
	"    if (c) goto L_ERR1;\n"
	"    c = (indice.tipo != TIPO_INT);\n"
	"    if (c) goto L_ERR2;\n"
	"    c = (indice.valor.v_int < 0);\n"
	"    if (c) goto L_ERR3;\n"
	"    c = (indice.valor.v_int >= arr.valor.v_array.tamanho);\n"
	"    if (c) goto L_ERR4;\n"
	"    return arr.valor.v_array.elementos[indice.valor.v_int];\n"
	"L_ERR1:\n"
	"    erro_runtime(\"[] (Nao e um Array)\");\n"
	"L_ERR2:\n"
	"    erro_runtime(\"[] (Indice nao e INT)\");\n"
	"L_ERR3:\n"
	"    erro_runtime(\"Index < 0\");\n"
	"L_ERR4:\n"
	"    erro_runtime(\"Index Out of Bounds\");\n"
	"}\n"
	"\n"
	"void set_array(Var arr, Var indice, Var valor) {\n"
	"    int c;\n"
	"    c = (arr.tipo != TIPO_ARRAY);\n"
	"    if (c) goto L_ERR1;\n"
	"    c = (indice.tipo != TIPO_INT);\n"
	"    if (c) goto L_ERR2;\n"
	"    c = (indice.valor.v_int < 0);\n"
	"    if (c) goto L_ERR3;\n"
	"    c = (indice.valor.v_int >= arr.valor.v_array.tamanho);\n"
	"    if (c) goto L_ERR4;\n"
	"    arr.valor.v_array.elementos[indice.valor.v_int] = valor;\n"
	"    return;\n"
	"L_ERR1:\n"
	"    erro_runtime(\"[]= (Nao e um Array)\");\n"
	"L_ERR2:\n"
	"    erro_runtime(\"[]= (Indice nao e INT)\");\n"
	"L_ERR3:\n"
	"    erro_runtime(\"Index < 0\");\n"
	"L_ERR4:\n"
	"    erro_runtime(\"Index Out of Bounds\");\n"
	"}\n"

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
		"    printf(\"Erro de Execucao na linha %d: Tipos incompativeis para a operacao '%s'.\\n\", linha_execucao, operacao);\n"
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

	/* Funções de Entrada e Saída */
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

	/* Funções Aritméticas */
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

	/* Funções Relacionais */
	// Função de ==
	"Var igual_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    float t_float;\n"
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

	// Função de >
	"Var maior_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    float t_float;\n"
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
		"    float t_float;\n"
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
		"    float t_float;\n"
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
		"    float t_float;\n"
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

	/* Funções Lógicas */
	// Função de !=
	"Var diferente_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    float t_float;\n"
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

	// Função AND
		"Var and_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c1;\n"
		"    int c3;\n"
		"\n"
		"    c1 = eh_verdadeiro(a);\n"
		"    if (!c1) goto L_false;\n"
		"\n"
		"    c3 = eh_verdadeiro(b);\n"
		"    goto L_end;\n"
		"\n"
		"L_false:\n"
		"    c3 = 0;\n"
		"\n"
		"L_end:\n"
		"    r = cria_bool(c3);\n"
		"    return r;\n"
	"}\n"
	"\n"

		// Função OR
		"Var or_dinamico(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c1;\n"
		"    int c3;\n"
		"\n"
		"    c1 = eh_verdadeiro(a);\n"
		"    if (!c1) goto L_eval_b;\n"
		"\n"
		"    c3 = 1;\n"
		"    goto L_end;\n"
		"\n"
		"L_eval_b:\n"
		"    c3 = eh_verdadeiro(b);\n"
		"\n"
		"L_end:\n"
		"    r = cria_bool(c3);\n"
		"    return r;\n"
		"}\n"
		"\n"

	// Função NOT
	"Var not_dinamico(Var a) {\n"
		"    Var r;\n"
		"    int c1;\n"
		"    int c2;\n"
		"    c1 = eh_verdadeiro(a);\n"
		"    c2 = !c1;\n"
		"    r = cria_bool(c2);\n"
		"    return r;\n"
	"}\n"

	/* Funções de Cast Explícito */
	// Função de cast int()
	"Var cast_int(Var a) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    int t_int;\n"
		"    long l_val;\n"
		"    char* endptr;\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L1;\n"
		"    r = a;\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L2;\n"
		"    t_int = (int)a.valor.v_float;\n"
		"    r = cria_int(t_int);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_BOOL);\n"
		"    if (c) goto L3;\n"
		"    r = cria_int(a.valor.v_bool);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_STRING);\n"
		"    if (c) goto L_ERR;\n"
		"    l_val = strtol(a.valor.v_string, &endptr, 10);\n"
		"    c = (endptr == a.valor.v_string);\n" // Nenhuma conversão pôde ser feita
		"    if (c) goto L_ERR2;\n"
		"    c = (*endptr != '\\0');\n" // O texto tem lixo após o número (ex: "42abc")
		"    if (c) goto L_ERR2;\n"
		"    t_int = (int)l_val;\n"
		"    r = cria_int(t_int);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"int()\");\n"
		"L_ERR2:\n"
		"    printf(\"Erro de Execucao na linha %d: Nao foi possivel converter a string em inteiro.\\n\", linha_execucao);\n"
		"    exit(1);\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de cast float()
	"Var cast_float(Var a) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    float t_float;\n"
		"    char* endptr;\n"
		"    double d_val;\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L1;\n"
		"    r = a;\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L2;\n"
		"    t_float = (float)a.valor.v_int;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_BOOL);\n"
		"    if (c) goto L3;\n"
		"    t_float = (float)a.valor.v_bool;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_STRING);\n"
		"    if (c) goto L_ERR;\n"
		"    d_val = strtod(a.valor.v_string, &endptr);\n"
		"    c = (endptr == a.valor.v_string);\n" // Verifica se nenhuma conversão foi feita
		"    if (c) goto L_ERR2;\n"
		"    c = (*endptr != '\\0');\n" // Verifica se sobrou texto não-numérico
		"    if (c) goto L_ERR2;\n"
		"    t_float = (float)d_val;\n"
		"    r = cria_float(t_float);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"float()\");\n"
		"L_ERR2:\n"
		"    printf(\"Erro de Execucao na linha %d: Nao foi possivel converter a string em float.\\n\", linha_execucao);\n"
		"    exit(1);\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de cast str()
	"Var cast_str(Var a) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    char* buf;\n"
		"    c = (a.tipo != TIPO_STRING);\n"
		"    if (c) goto L1;\n"
		"    r = cria_string(a.valor.v_string);\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_INT);\n"
		"    if (c) goto L2;\n"
		"    buf = (char*)malloc(32);\n"
		"    sprintf(buf, \"%d\", a.valor.v_int);\n"
		"    r = cria_string(buf);\n"
		"    free(buf);\n"
		"    goto FIM;\n"
		"L2:\n"
		"    c = (a.tipo != TIPO_FLOAT);\n"
		"    if (c) goto L3;\n"
		"    buf = (char*)malloc(64);\n"
		"    sprintf(buf, \"%f\", a.valor.v_float);\n"
		"    r = cria_string(buf);\n"
		"    free(buf);\n"
		"    goto FIM;\n"
		"L3:\n"
		"    c = (a.tipo != TIPO_BOOL);\n"
		"    if (c) goto L4;\n"
		"    c = (a.valor.v_bool == 1);\n"
		"    if (c) goto L_TRUE;\n"
		"    r = cria_string(\"false\");\n"
		"    goto FIM;\n"
		"L_TRUE:\n"
		"    r = cria_string(\"true\");\n"
		"    goto FIM;\n"
		"L4:\n"
		"    c = (a.tipo != TIPO_CHAR);\n"
		"    if (c) goto L_ERR;\n"
		"    buf = (char*)malloc(2);\n"
		"    buf[0] = a.valor.v_char;\n"
		"    buf[1] = '\\0';\n"
		"    r = cria_string(buf);\n"
		"    free(buf);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"str()\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de cast bool()
	"Var cast_bool(Var a) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    c = eh_verdadeiro(a);\n"
		"    r = cria_bool(c);\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de cast char()
	"Var cast_char(Var a) {\n"
		"    Var r;\n"
		"    int c;\n"
		"    int len;\n"
		"    int c2;\n"
		"    char t_char;\n"
		"    c = (a.tipo != TIPO_CHAR);\n"
		"    if (c) goto L1;\n"
		"    r = a;\n"
		"    goto FIM;\n"
		"L1:\n"
		"    c = (a.tipo != TIPO_STRING);\n"
		"    if (c) goto L_ERR;\n"
		"    len = strlen(a.valor.v_string);\n"
		"    c2 = (len > 1);\n"
		"    if (c2) goto L_ERR2;\n"
		"    t_char = a.valor.v_string[0];\n"
		"    r = cria_char(t_char);\n"
		"    goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"char()\");\n"
		"L_ERR2:\n"
		"    printf(\"Erro de Execucao na linha %d: Operacao char() aceita somente strings de tamanho 1.\\n\", linha_execucao);\n"
		"    exit(1);\n"
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
%token TK_IN TK_TO TK_INC TK_DEC
%token TK_BREAK TK_CONTINUE

// Funcao
%token TK_DEF TK_RETURN

// Variável GLobal e Local
%token TK_GLOBAL
%token TK_LOCAL

// Identificador
%token TK_ID

// Cast Explícito
%token TK_CAST_INT TK_CAST_FLOAT TK_CAST_STR TK_CAST_BOOL TK_CAST_CHAR

// tokens da indentacao por tabulacao
%token TK_INDENT TK_DEDENT TK_NEWLINE

// Tokens Relacionais
%token TK_GE TK_LE TK_EQ TK_DIF

// Tokens Lógicos
%token TK_AND TK_OR TK_NOT

// Operadores Compostos
%token TK_ADD_ASSIGN TK_SUB_ASSIGN TK_MUL_ASSIGN TK_DIV_ASSIGN

// Símbolo Inicial
%start PROGRAMA

// Precedência
%left TK_OR
%left TK_AND
%left TK_EQ TK_DIF
%left '>' '<' TK_GE TK_LE 
%left '+' '-'
%left '*' '/'
%right TK_NOT
%left '[' ']'

%%
	/* Início			*/
PROGRAMA 	: LISTA_COMANDOS
			{
				// >>> O SEGREDO ESTÁ AQUI: Injetar os headers antes de tudo <<<
				codigo_gerado = runtime_c + "\n" + codigo_headers_funcoes + "\n";
				
				// gera as variáveis globais no topo do c
				for (const string& g : variaveis_globais) {
					codigo_gerado += "Var " + g + ";\n";
				}

				// >>> E AQUI: Injetar as funções antes da main <<<
				codigo_gerado += "\n" + codigo_funcoes + "\nint main(void) {\n";

				// Declara Temporárias
				for (int i : temporarias_main) {
					codigo_gerado += "\tVar t" + to_string(i) + ";\n";
				}

				// Declara Variáveis de Condição
				for (int i : cond_main) {
					codigo_gerado += "\tint c" + to_string(i) + ";\n";
				}

				// Declara Variáveis do Usuário
				for (const string& nome_var : variaveis_main) {
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

	/* Bloco por Indentação*/
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

				// ID if para Labels
				if_qnt++;
				if_id_stack.push(if_qnt);

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
						string l_falso = gen_label("ELIF_DEU_FALSO");
						string l_fim = elif_fim_stack.top(); // Pega o label de fim

						// Condição do ELIF
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

			/* Operadores Compostos para Variáveis */
			| TK_ID TK_ADD_ASSIGN E TK_NEWLINE
			{
				// Diferente do '=', aqui nós só buscamos, pois a variável já DEVE existir!
				Simbolo s = buscar_Simbolo($1.label);
				$$.traducao = $3.traducao + "\t" + s.label + " = soma_dinamica(" + s.label + ", " + $3.label + ");\n";
			}
			| TK_ID TK_SUB_ASSIGN E TK_NEWLINE
			{
				Simbolo s = buscar_Simbolo($1.label);
				$$.traducao = $3.traducao + "\t" + s.label + " = sub_dinamica(" + s.label + ", " + $3.label + ");\n";
			}
			| TK_ID TK_MUL_ASSIGN E TK_NEWLINE
			{
				Simbolo s = buscar_Simbolo($1.label);
				$$.traducao = $3.traducao + "\t" + s.label + " = mult_dinamica(" + s.label + ", " + $3.label + ");\n";
			}
			| TK_ID TK_DIV_ASSIGN E TK_NEWLINE
			{
				Simbolo s = buscar_Simbolo($1.label);
				$$.traducao = $3.traducao + "\t" + s.label + " = div_dinamica(" + s.label + ", " + $3.label + ");\n";
			}

			/* Operador composto para divisão em Arrays/Matriz */
			| E '[' E ']' TK_ADD_ASSIGN E TK_NEWLINE
			{
				string temp_val = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + $6.traducao +
							  "\t" + temp_val + " = get_array(" + $1.label + ", " + $3.label + ");\n" +
							  "\t" + temp_val + " = soma_dinamica(" + temp_val + ", " + $6.label + ");\n" +
							  "\tset_array(" + $1.label + ", " + $3.label + ", " + temp_val + ");\n";
			}

			/* Operador composto para divisão em Arrays/Matriz */
			| E '[' E ']' TK_SUB_ASSIGN E TK_NEWLINE
			{
				string temp_val = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + $6.traducao +
							  "\t" + temp_val + " = get_array(" + $1.label + ", " + $3.label + ");\n" +
							  "\t" + temp_val + " = sub_dinamica(" + temp_val + ", " + $6.label + ");\n" +
							  "\tset_array(" + $1.label + ", " + $3.label + ", " + temp_val + ");\n";
			}

			/* Operador composto para divisão em Arrays/Matriz */
			| E '[' E ']' TK_MUL_ASSIGN E TK_NEWLINE
			{
				string temp_val = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + $6.traducao +
							  "\t" + temp_val + " = get_array(" + $1.label + ", " + $3.label + ");\n" +
							  "\t" + temp_val + " = mult_dinamica(" + temp_val + ", " + $6.label + ");\n" +
							  "\tset_array(" + $1.label + ", " + $3.label + ", " + temp_val + ");\n";
			}

			/* Operador composto para divisão em Arrays/Matriz */
			| E '[' E ']' TK_DIV_ASSIGN E TK_NEWLINE
			{
				string temp_val = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + $6.traducao +
							  "\t" + temp_val + " = get_array(" + $1.label + ", " + $3.label + ");\n" +
							  "\t" + temp_val + " = div_dinamica(" + temp_val + ", " + $6.label + ");\n" +
							  "\tset_array(" + $1.label + ", " + $3.label + ", " + temp_val + ");\n";
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

	/* Absorve Tabs Soltos  */
			| TK_INDENT TK_NEWLINE TK_DEDENT
			{
				$$.traducao = ""; 
			}

	/* Atribuição Dinâmica de Arrays e Matrizes */
			| E '[' E ']' '=' E TK_NEWLINE
			{
				$$.traducao = $1.traducao + $3.traducao + $6.traducao +
							  "\tset_array(" + $1.label + ", " + $3.label + ", " + $6.label + ");\n";
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

				// Recupera ID if para Labels
				int if_id = if_id_stack.top();

				// Para o bloco de alternativas saber para onde pular no fim
				elif_fim_stack.push("LBL_IF_FIM_" + to_string(if_id));
			}
			BLOCOS_ALTERNATIVOS
			{
				// Recupera Id para Label
				int if_id = if_id_stack.top();
				if_id_stack.pop();

				string l_falso = gen_label("IF_DEU_FALSO");
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

				// Id para Labels
				while_qnt++;
				int while_id = while_qnt;

				/* Break e Continue */
				loop_break_stack.push("LBL_WHILE_FIM_" + to_string(while_id));
				loop_continue_stack.push("LBL_WHILE_INICIO_" + to_string(while_id));
			}
			BLOCO
			{
				pilha_tabela_simbolos.pop_back();

				// Labels necessários
				string l_inicio = loop_continue_stack.top();
				string l_fim = loop_break_stack.top();
				loop_continue_stack.pop();
				loop_break_stack.pop();

				// Condição do while
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

				// ID para Labels
				do_while_qnt++;
				do_while_id_stack.push(do_while_qnt);
				int do_id = do_while_qnt;

				/* Break e Continue */
				loop_break_stack.push("LBL_DO_FIM_" + to_string(do_id));
				loop_continue_stack.push("LBL_DO_CONTINUE_" + to_string(do_id));
			}	
			BLOCO TK_WHILE E TK_NEWLINE
			{
				pilha_tabela_simbolos.pop_back();

				// Resgata o ID
				int do_id = do_while_id_stack.top();
				do_while_id_stack.pop();

				// Labels Necessários
				string l_inicio = "LBL_DO_INICIO_" + to_string(do_id);
				string l_continue = loop_continue_stack.top();
				string l_fim = loop_break_stack.top();

				// Tira das Pilhas
				loop_continue_stack.pop();
				loop_break_stack.pop();

				// Condição Do-While
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
				// Verifica se a variável já é um iterador ativo em um laço mais externo
				for (string iterador : iteradores_ativos) {
					if (iterador == $2.label) {
						yyerror("Erro Semantico: A variavel '" + $2.label + "' ja esta sendo usada como iteradora em um laco externo.");
						exit(1);
					}
				}

				// Tranca a Variável
				iteradores_ativos.push_back($2.label);

				pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
				id_escopo++;

				// registra a variavel iteradora (i)
				registrar_variavel($2.label);
				
				// Incrementa ID dos labels
				for_qnt++;
				for_id_stack.push(for_qnt);
				int for_id = for_qnt;

				/* Break e Continue usando ID para Label */
				loop_break_stack.push("LBL_FOR_FIM_" + to_string(for_id));
				loop_continue_stack.push("LBL_FOR_CONTINUE_" + to_string(for_id));

				// Linha que pode dar erro de Tipo no for (Linha do cabeçalho)
				for_linha_stack.push(linha);
			}
			BLOCO
			{
				// Destranca a variável pois o laço acabou
				iteradores_ativos.pop_back();

				// Busca Simbolo de i
				Simbolo s;
				s = buscar_Simbolo($2.label);
				
				pilha_tabela_simbolos.pop_back();

				// Recupera Labels Continue e Break e Retira eles da Pilha
				string l_continue = loop_continue_stack.top();
				string l_fim = loop_break_stack.top();
				loop_continue_stack.pop();
				loop_break_stack.pop();

				// Pega o ID do FOR atual para os labels internos
				int for_id = for_id_stack.top();
				for_id_stack.pop();

				// Labels necessários
				string l_inicio = "LBL_FOR_INICIO_" + to_string(for_id);
				string l_checagem_crescente = "LBL_FOR_CHECAGEM_CRESCENTE_" + to_string(for_id);
				string l_corpo = "LBL_FOR_CORPO_" + to_string(for_id);
				string l_passo_crescente = "LBL_FOR_PASSO_CRESCENTE_" + to_string(for_id);
				string l_err_tipo = "LBL_FOR_ERR_TIPO_" + to_string(for_id);
				string l_err_iterador = "LBL_FOR_ERR_ITER_" + to_string(for_id);

				// Resgata a linha correta do cabeçalho do FOR
				int linha_for = for_linha_stack.top();
				for_linha_stack.pop();

				// Temporária para ver se é crescente ou decrescente
				string temp_eh_crescente = gentempcode();

				// Temporária que avalia a checagem
				string temp_cond = gentempcode();
				
				// Temporária com o valor 1, para somar (i=i+1)
				string temp_um = gentempcode();

				// Condição se é Crescente
				string cond_crescente = gencondcode();
				
				// Condição de Checagem
				string cond = gencondcode();

				// Condição de Tipo
				string cond_tipo = gencondcode();

				// Inicializa i com o valor de x e verifica os se os tipos das expressões são int
				string trad_init = $4.traducao + 
								   "\t" + cond_tipo + " = (" + $4.label + ".tipo != TIPO_INT);\n" +
				            	   "\tif (" + cond_tipo + ") goto " + l_err_tipo + ";\n" +
								   "\t" + s.label + " = " + $4.label + ";\n" +
								   $6.traducao + 
								   "\t" + cond_tipo + " = (" + $6.label + ".tipo != TIPO_INT);\n" +
				                   "\tif (" + cond_tipo + ") goto " + l_err_tipo + ";\n" +
				                   "\t" + temp_eh_crescente + " = menor_igual_dinamico(" + s.label + ", " + $6.label + ");\n" +
				                   "\t" + cond_crescente + " = eh_verdadeiro(" + temp_eh_crescente + ");\n";


				// Monta o laço bidirecional
				$$.traducao = trad_init + 
										l_inicio + ":\n" +
										$6.traducao + // Reavalia o teto (y) a cada iteração
										"\tif (" + cond_crescente + ") goto " + l_checagem_crescente + ";\n" +
							  
										// --- CHECAGEM CASO DECRESCENTE ---
										"\t" + temp_cond + " = maior_igual_dinamico(" + s.label + ", " + $6.label + ");\n" +
										"\t" + cond + " = eh_verdadeiro(" + temp_cond + ");\n" + 
										"\t" + cond + " = !" + cond + ";\n" +
										"\tif (" + cond + ") goto " + l_fim + ";\n" +
										"\tgoto " + l_corpo + ";\n" +
										
										// --- CHECAGEM CASO CRESCENTE ---
										l_checagem_crescente + ":\n" +
										"\t" + temp_cond + " = menor_igual_dinamico(" + s.label + ", " + $6.label + ");\n" +
										"\t" + cond + " = eh_verdadeiro(" + temp_cond + ");\n" + 
										"\t" + cond + " = !" + cond + ";\n" +
										"\tif (" + cond + ") goto " + l_fim + ";\n" +
										
										// --- CORPO DO LAÇO ---
										l_corpo + ":\n" +
										$9.traducao + 
										
										// --- PASSO (INCREMENTO / DECREMENTO) ---
										l_continue + ":\n" + 

										// Catraca de segurança: Verifica se a variável iteradora continua sendo INT
										"\t" + cond_tipo + " = (" + s.label + ".tipo != TIPO_INT);\n" +
										"\tif (" + cond_tipo + ") goto " + l_err_iterador + ";\n" +
										
										"\t" + temp_um + " = cria_int(1);\n" + 
										"\tif (" + cond_crescente + ") goto " + l_passo_crescente + ";\n" +
										// Subtrai 1 se for decrescente
										"\t" + s.label + " = sub_dinamica(" + s.label + ", " + temp_um + ");\n" +
										"\tgoto " + l_inicio + ";\n" +
										l_passo_crescente + ":\n" +
										// Soma 1 se for crescente
										"\t" + s.label + " = soma_dinamica(" + s.label + ", " + temp_um + ");\n" +
										"\tgoto " + l_inicio + ";\n" +

										// --- TRATAMENTO DE ERRO DOS LIMITES ---
										l_err_tipo + ":\n" +
										"\tprintf(\"Erro de Execucao na linha " + to_string(linha_for) + ": O laco 'for' aceita apenas limites do tipo INT.\\n\");\n" +
										"\texit(1);\n" +
										
										// --- TRATAMENTO DE ERRO DA VARIÁVEL MUDADA ---
										l_err_iterador + ":\n" +
										"\tprintf(\"Erro de Execucao na linha " + to_string(linha_for) + ": A variavel iteradora do laco 'for' foi alterada para um tipo incompativel dentro do bloco.\\n\");\n" +
										"\texit(1);\n" +

										l_fim + ":\n";
			}
			/* Definição de Função */
			| TK_DEF TK_ID '('
			{
				// Configura o isolamento de escopo antes de ler o bloco
				em_funcao = true;
				pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());
				id_escopo++;
				temp_start_func = var_temp_qnt;
				cond_start_func = var_cond_qnt;
				variaveis_func_atual.clear();
				parametros_atuais.clear();
			}
			PARAMETROS ')' ':' TK_NEWLINE TK_INDENT LISTA_COMANDOS TK_DEDENT
			{
				string func_name = "f_" + $2.label;
				
				// 1. Gera o protótipo global
				codigo_headers_funcoes += "Var " + func_name + "(" + $5.traducao + ");\n";

				// 2. Monta o corpo da função TAC isolada
				string signature = "Var " + func_name + "(" + $5.traducao + ") {\n";
				string declarations = "";

				// Declara as temporárias exclusivas desta função
				for(int i = temp_start_func + 1; i <= var_temp_qnt; i++){
					declarations += "\tVar t" + to_string(i) + ";\n";
				}
				for(int i = cond_start_func + 1; i <= var_cond_qnt; i++){
					declarations += "\tint c" + to_string(i) + ";\n";
				}
				
				// Declara as variáveis locais (ignorando os parâmetros, pois já estão na assinatura)
				for(const string& v : variaveis_func_atual){
					bool is_param = false;
					for(const string& p : parametros_atuais) { if(v == p) { is_param = true; break; } }
					if(!is_param) declarations += "\tVar " + v + ";\n";
				}

				string body = $10.traducao;
				body += "\treturn cria_int(0);\n"; // Return de segurança caso o usuário esqueça

				codigo_funcoes += signature + declarations + body + "}\n\n";

				pilha_tabela_simbolos.pop_back();
				em_funcao = false;
				$$.traducao = ""; // Como a função foi enviada pro topo global, ela some do main!
			}

	/* Retorno de Função */
			| TK_RETURN E TK_NEWLINE
			{
				$$.traducao = $2.traducao + "\treturn " + $2.label + ";\n";
			}
			| TK_RETURN TK_NEWLINE
			{
				$$.traducao = "\treturn cria_int(0);\n";
			}

	/* switch case (basicamente uma cascata de ifs) */
			| TK_SWITCH E ':'
			{ 
				// ID switch
				switch_qnt++;
				int switch_id = switch_qnt;

				switch_var_stack.push($2.label); 
				switch_fim_stack.push("LBL_SWITCH_FIM_" + to_string(switch_id)); 
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

				// Labels necessários
				string l_prox_caso = gen_label("PROX_CASO");
				string l_fim = switch_fim_stack.top();

				// Variável do Switch
				string var_switch = switch_var_stack.top();
				
				// Temporária para condição
				string var_teste = gentempcode();

				// Condição em si
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

PARAMETROS	: TK_ID ',' PARAMETROS
			{
				registrar_variavel($1.label);
				Simbolo s = buscar_Simbolo($1.label);
				parametros_atuais.push_back(s.label);
				$$.traducao = "Var " + s.label + ", " + $3.traducao;
			}
			| TK_ID
			{
				registrar_variavel($1.label);
				Simbolo s = buscar_Simbolo($1.label);
				parametros_atuais.push_back(s.label);
				$$.traducao = "Var " + s.label;
			}
			| 
			{ $$.traducao = ""; }
			;

ARGUMENTOS	: E ',' ARGUMENTOS
			{
				$$.traducao = $1.traducao + $3.traducao;
				$$.label = $1.label + ", " + $3.label;
			}
			| E
			{
				$$.traducao = $1.traducao;
				$$.label = $1.label;
			}
			| 
			{ $$.traducao = ""; $$.label = ""; }
			;
// Arrays
LISTA_VALORES	: E ',' LISTA_VALORES
			{
				$$.traducao = $1.traducao + $3.traducao;
				$$.array_labels = $3.array_labels;
				$$.array_labels.insert($$.array_labels.begin(), $1.label);
			}
			| E
			{
				$$.traducao = $1.traducao;
				$$.array_labels.push_back($1.label);
			}
			| 
			{ $$.traducao = ""; }
			;

	/* Expressão 			*/
	/* Identificador		*/
E 			: TK_ID
			{
				Simbolo s = buscar_Simbolo($1.label);
				$$.label = s.label;
				$$.traducao = "";
				$$.linha_token = linha;
			}
	
	/*		  Literais			*/
			| TK_INT
			{
				$$.label = gentempcode();
				$$.traducao = "\t" + $$.label + " = cria_int(" + $1.label + ");\n";
				$$.linha_token = linha;
			}

			| TK_FLOAT
			{
				$$.label = gentempcode();
				$$.traducao = "\t" + $$.label + " = cria_float(" + $1.label + ");\n";
				$$.linha_token = linha;
			}

			| TK_CHAR
			{
				$$.label = gentempcode();
				$$.traducao = "\t" + $$.label + " = cria_char(" + $1.label + ");\n";
				$$.linha_token = linha;
			}

			| TK_STRING
			{
				$$.label = gentempcode();
				$$.traducao = "\t" + $$.label + " = cria_string(" + $1.label + ");\n";
				$$.linha_token = linha;
			}

			| TK_BOOL
			{
				$$.label = gentempcode();
				string valor_c = ($1.label == "true") ? "1" : "0";
				$$.traducao = "\t" + $$.label + " = cria_bool(" + valor_c + ");\n"; 
				$$.linha_token = linha;
			}

	/* Função Input */
			| TK_INPUT '(' ')'
			{
				$$.label = gentempcode();
				$$.traducao = "\t" + $$.label + " = input_dinamico();\n";
				$$.linha_token = linha;
			}

	/* Conversões Explícitas (Cast) */
			| TK_CAST_INT '(' E ')'
			{
				$$.label = gentempcode();
				$$.linha_token = $3.linha_token;
				$$.traducao = $3.traducao + 
					"\tlinha_execucao = " + to_string($3.linha_token) + ";\n" +
					"\t" + $$.label + " = cast_int(" + $3.label + ");\n";
			}
			| TK_CAST_FLOAT '(' E ')'
			{
				$$.label = gentempcode();
				$$.linha_token = $3.linha_token;
				$$.traducao = $3.traducao + 
					"\tlinha_execucao = " + to_string($3.linha_token) + ";\n" +
					"\t" + $$.label + " = cast_float(" + $3.label + ");\n";
			}
			| TK_CAST_STR '(' E ')'
			{
				$$.label = gentempcode();
				$$.linha_token = $3.linha_token;
				$$.traducao = $3.traducao + 
					"\tlinha_execucao = " + to_string($3.linha_token) + ";\n" +
					"\t" + $$.label + " = cast_str(" + $3.label + ");\n";
			}
			| TK_CAST_BOOL '(' E ')'
			{
				$$.label = gentempcode();
				$$.linha_token = $3.linha_token;
				$$.traducao = $3.traducao + 
					"\tlinha_execucao = " + to_string($3.linha_token) + ";\n" +
					"\t" + $$.label + " = cast_bool(" + $3.label + ");\n";
			}
			| TK_CAST_CHAR '(' E ')'
			{
				$$.label = gentempcode();
				$$.linha_token = $3.linha_token;
				$$.traducao = $3.traducao + 
					"\tlinha_execucao = " + to_string($3.linha_token) + ";\n" +
					"\t" + $$.label + " = cast_char(" + $3.label + ");\n";
			}

			/* Pós-incremento: x++ */
			| TK_ID TK_INC
			{
				Simbolo s = buscar_Simbolo($1.label);
				string temp_old = gentempcode();
				string temp_um = gentempcode();
				
				$$.label = temp_old; // A expressao passa o valor ANTIGO pra frente
				$$.linha_token = linha;
				
				$$.traducao = "\t" + temp_old + " = " + s.label + ";\n" +
							  "\t" + temp_um + " = cria_int(1);\n" +
							  "\t" + s.label + " = soma_dinamica(" + s.label + ", " + temp_um + ");\n";
			}

			/* Pós-decremento: x-- */
			| TK_ID TK_DEC
			{
				Simbolo s = buscar_Simbolo($1.label);
				string temp_old = gentempcode();
				string temp_um = gentempcode();
				
				$$.label = temp_old; // A expressao passa o valor ANTIGO pra frente
				$$.linha_token = linha;
				
				$$.traducao = "\t" + temp_old + " = " + s.label + ";\n" +
							  "\t" + temp_um + " = cria_int(1);\n" +
							  "\t" + s.label + " = sub_dinamica(" + s.label + ", " + temp_um + ");\n";
			}

			/* Pré-incremento: ++x */
			| TK_INC TK_ID
			{
				Simbolo s = buscar_Simbolo($2.label);
				string temp_um = gentempcode();
				
				$$.label = s.label; // A expressao passa o valor NOVO pra frente
				$$.linha_token = linha;
				
				$$.traducao = "\t" + temp_um + " = cria_int(1);\n" +
							  "\t" + s.label + " = soma_dinamica(" + s.label + ", " + temp_um + ");\n";
			}

			/* Pré-decremento: --x */
			| TK_DEC TK_ID
			{
				Simbolo s = buscar_Simbolo($2.label);
				string temp_um = gentempcode();
				
				$$.label = s.label; // A expressao passa o valor NOVO pra frente
				$$.linha_token = linha;
				
				$$.traducao = "\t" + temp_um + " = cria_int(1);\n" +
							  "\t" + s.label + " = sub_dinamica(" + s.label + ", " + temp_um + ");\n";
			}

			/* Literal de Array / Matriz (ex: [1, 2, 3] ou [[1], [2]]) */
			| '[' LISTA_VALORES ']'
			{
				$$.label = gentempcode();
				$$.linha_token = linha;
				string temp_size = gentempcode();
				
				string code = $2.traducao;
				code += "\t" + temp_size + " = cria_int(" + to_string($2.array_labels.size()) + ");\n";
				code += "\t" + $$.label + " = cria_array(" + temp_size + ");\n";
				
				for(int i = 0; i < $2.array_labels.size(); i++) {
					string temp_idx = gentempcode();
					code += "\t" + temp_idx + " = cria_int(" + to_string(i) + ");\n";
					code += "\tset_array(" + $$.label + ", " + temp_idx + ", " + $2.array_labels[i] + ");\n";
				}
				$$.traducao = code;
			}

			/* Acesso a Array / Matriz (ex: a[0] ou a[0][1]) */
			| E '[' E ']'
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao + 
							  "\t" + $$.label + " = get_array(" + $1.label + ", " + $3.label + ");\n";
			}
	/* Operadores Aritméticos	*/ 
			| E '+' E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao +
					"\tlinha_execucao = " + to_string($1.linha_token) + ";\n" + 
					"\t" + $$.label + " = soma_dinamica(" + $1.label + ", " + $3.label + ");\n";
			}

			| E '-' E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao + 
					"\tlinha_execucao = " + to_string($1.linha_token) + ";\n" +
					"\t" + $$.label + " = sub_dinamica(" + $1.label + ", " + $3.label + ");\n";
			}

			| E '*' E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao + 
					"\tlinha_execucao = " + to_string($1.linha_token) + ";\n" +
					"\t" + $$.label + " = mult_dinamica(" + $1.label + ", " + $3.label + ");\n";
			}

			| E '/' E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao +
					"\tlinha_execucao = " + to_string($1.linha_token) + ";\n" + 
					"\t" + $$.label + " = div_dinamica(" + $1.label + ", " + $3.label + ");\n";
			}

	/* Operadores Relacionais	*/ 
			| E '>' E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao +
				"\tlinha_execucao = " + to_string($1.linha_token) + ";\n" +
				"\t" + $$.label + " = maior_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E '<' E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao +
				"\tlinha_execucao = " + to_string($1.linha_token) + ";\n" +
				"\t" + $$.label + " = menor_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E TK_GE E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao +
				"\tlinha_execucao = " + to_string($1.linha_token) + ";\n" +
				"\t" + $$.label + " = maior_igual_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E TK_LE E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao +
				"\tlinha_execucao = " + to_string($1.linha_token) + ";\n" +
				"\t" + $$.label + " = menor_igual_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E TK_EQ E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao + 
				"\tlinha_execucao = " + to_string($1.linha_token) + ";\n" +
				"\t" + $$.label + " = igual_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E TK_DIF E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao +
				"\tlinha_execucao = " + to_string($1.linha_token) + ";\n" +
				"\t" + $$.label + " = diferente_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

	/* Operadores Lógicos    */ 
			| E TK_AND E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = and_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| E TK_OR E
			{
				$$.label = gentempcode();
				$$.linha_token = $1.linha_token;
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = or_dinamico(" + $1.label + ", " + $3.label + ");\n";
			}

			| TK_NOT E
			{
				$$.label = gentempcode();
				$$.linha_token = $2.linha_token;
				$$.traducao = $2.traducao + "\t" + $$.label + " = not_dinamico(" + $2.label + ");\n";
			}

	/* Parênteses		*/ 
			| '(' E ')'
			{
				$$.label = $2.label;
				$$.traducao = $2.traducao;
				$$.linha_token = $2.linha_token;
			}

			/* Chamada de Função como Expressão */
			| TK_ID '(' ARGUMENTOS ')'
			{
				$$.label = gentempcode();
				$$.linha_token = linha;
				$$.traducao = $3.traducao + "\t" + $$.label + " = f_" + $1.label + "(" + $3.label + ");\n";
			}

%%

#include "lex.yy.c"

int yyparse();

int main(int argc, char* argv[]) {
	pilha_tabela_simbolos.push_back(unordered_map<string, Simbolo>());

	if (yyparse() == 0)
		cout << codigo_gerado;

	return 0;
}

void yyerror(string MSG) {
	cerr << "Erro na linha " << linha << ": " << MSG << endl;
}
