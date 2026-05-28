%{
#include <iostream>
#include <string>
#include <vector>
#include <unordered_map>
#include <stack>

#define YYSTYPE atributos

using namespace std;

int var_temp_qnt;
int label_qnt = 0;
int linha = 1;
string codigo_gerado;

vector<string> variaveis_declaradas;
unordered_map<string, bool> tabela_simbolos;

stack<string> switch_var_stack;
stack<string> switch_fim_stack;

struct atributos {
	string label;
	string traducao;
};

string gentempcode() {
	var_temp_qnt++;
	return "t" + to_string(var_temp_qnt);
}

string gen_label() {
    label_qnt++;
    return "LBL_CTRL_" + to_string(label_qnt);
}

void registrar_variavel(string nome) {
	if (!tabela_simbolos.count(nome)) {
		tabela_simbolos[nome] = true;
		variaveis_declaradas.push_back(nome);
	}
}

int yylex(void);
void yyerror(string);

//codigo c q vai no final
string runtime_c = 
	"#include <stdio.h>\n"
	"#include <stdlib.h>\n"
	"#include <string.h>\n"

	// Função de Leitura para String Dinâmica
	"int lenstr(const char* str) {\n"
		"    int len, t1;\n"
		"    char c;\n"
		"    len = 0;\n"
		"L_LOOP:\n"
		"    c = str[len];\n"
		"    t1 = (c == '\\0'); if (t1 != 0) goto L_FIM;\n"
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
		"    int c, t;\n"
		"L_BOOL: c = (v.tipo == TIPO_BOOL); if (c == 0) goto L_INT;\n"
		"    return v.valor.v_bool;\n"
		"L_INT:  c = (v.tipo == TIPO_INT); if (c == 0) goto L_FLOAT;\n"
		"    t = (v.valor.v_int != 0); return t;\n"
		"L_FLOAT: c = (v.tipo == TIPO_FLOAT); if (c == 0) goto L_STR;\n"
		"    t = (v.valor.v_float != 0.0); return t;\n"
		"L_STR:  c = (v.tipo == TIPO_STRING); if (c == 0) goto L_FIM;\n"
		"    t = lenstr(v.valor.v_string);\n"
		"    c = (t > 0); return c;\n"
		"L_FIM:\n"
		"    return 1;\n"
	"}\n"
	"\n"

	// Função para Printar
	"void print_dinamico(Var v) {\n"
		"    int cond;\n"
		"L_PRINT_INT:\n"
		"    cond = (v.tipo == TIPO_INT); if (cond == 0) goto L_PRINT_FLOAT;\n"
		"    printf(\"%d\\n\", v.valor.v_int); goto L_PRINT_FIM;\n"
		"L_PRINT_FLOAT:\n"
		"    cond = (v.tipo == TIPO_FLOAT); if (cond == 0) goto L_PRINT_CHAR;\n"
		"    printf(\"%f\\n\", v.valor.v_float); goto L_PRINT_FIM;\n"
		"L_PRINT_CHAR:\n"
		"    cond = (v.tipo == TIPO_CHAR); if (cond == 0) goto L_PRINT_BOOL;\n"
		"    printf(\"%c\\n\", v.valor.v_char); goto L_PRINT_FIM;\n"
		"L_PRINT_BOOL:\n"
		"    cond = (v.tipo == TIPO_BOOL); if (cond == 0) goto L_PRINT_STRING;\n"
		"    cond = (v.valor.v_bool == 1); if (cond == 0) goto L_PRINT_FALSE;\n"
		"    printf(\"true\\n\"); goto L_PRINT_FIM;\n"
		"L_PRINT_STRING:\n" 
		"    cond = (v.tipo == TIPO_STRING); if (cond == 0) goto L_PRINT_FIM;\n"
		"    printf(\"%s\\n\", v.valor.v_string); goto L_PRINT_FIM;\n"
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
		"    int cap, len, ch, t1, t2;\n"
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
		"    ch = fgetc(stdin);\n" //le caracter por caracter	
		"    t1 = (ch == EOF); if (t1 != 0) goto L_FIM_READ;\n"
		"    t1 = (ch == '\\n'); if (t1 != 0) goto L_FIM_READ;\n"
		"    t1 = (ch == '\\r'); if (t1 != 0) goto L_READ;\n" //ignora o /r q vem antes do /n no windows
		"\n"
		"    buffer[len] = (char)ch;\n"
		"    len = len + 1;\n"
		"    t1 = (len >= cap); if (t1 == 0) goto L_READ;\n"
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
		"    t2 = (t1 == 0); if (t2 == 0) goto L_FALSE;\n"
		"    res = cria_bool(1); goto FIM;\n"
		"L_FALSE:\n"
		"    t1 = strcmp(buffer, \"false\");\n"
		"    t2 = (t1 == 0); if (t2 == 0) goto L_INT;\n"
		"    res = cria_bool(0); goto FIM;\n"
		"L_INT:\n"
		"    val_int = strtol(buffer, &endptr, 10);\n"
		"    t1 = (endptr != buffer); if (t1 == 0) goto L_FLOAT;\n"
		"    t2 = (*endptr == '\\0'); if (t2 == 0) goto L_FLOAT;\n"
		"    res = cria_int((int)val_int); goto FIM;\n"
		"L_FLOAT:\n"
		"    val_float = strtod(buffer, &endptr);\n"
		"    t1 = (endptr != buffer); if (t1 == 0) goto L_CHAR;\n"
		"    t2 = (*endptr == '\\0'); if (t2 == 0) goto L_CHAR;\n"
		"    res = cria_float((float)val_float); goto FIM;\n"
		"L_CHAR:\n"
		"    t1 = (len == 1); if (t1 == 0) goto L_STR;\n"
		"    res = cria_char(buffer[0]); goto FIM;\n"
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
		"    int c, t_int, len_a, len_b, len_tot;\n"
		"    float t_float;\n"
		"    char* tmp_str;\n"
		"L1: c = (a.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    t_int = a.valor.v_int + b.valor.v_int;\n"
		"    r = cria_int(t_int); goto FIM;\n"
		"L2: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    t_float = a.valor.v_float + b.valor.v_float;\n"
		"    r = cria_float(t_float); goto FIM;\n"
		"L3: c = (a.tipo == TIPO_INT); if (c == 0) goto L4;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L4;\n"
		"    t_float = a.valor.v_int + b.valor.v_float;\n"
		"    r = cria_float(t_float); goto FIM;\n"
		"L4: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L5;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L5;\n"
		"    t_float = a.valor.v_float + b.valor.v_int;\n"
		"    r = cria_float(t_float); goto FIM;\n"
		"L5: c = (a.tipo == TIPO_STRING); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_STRING); if (c == 0) goto L_ERR;\n"
		"    len_a = lenstr(a.valor.v_string);\n"
		"    len_b = lenstr(b.valor.v_string);\n"
		"    len_tot = len_a + len_b;\n"
		"    len_tot = len_tot + 1;\n"
		"    tmp_str = (char*)malloc(len_tot);\n"
		"    strcpy(tmp_str, a.valor.v_string);\n"
		"    strcat(tmp_str, b.valor.v_string);\n"
		"    r = cria_string(tmp_str);\n"
		"    free(tmp_str); goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"+\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de Subtração
	"Var sub_dinamica(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c, t_int;\n"
		"    float t_float;\n"
		"L1: c = (a.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    t_int = a.valor.v_int - b.valor.v_int;\n"
		"    r = cria_int(t_int); goto FIM;\n"
		"L2: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    t_float = a.valor.v_float - b.valor.v_float;\n"
		"    r = cria_float(t_float); goto FIM;\n"
		"L3: c = (a.tipo == TIPO_INT); if (c == 0) goto L4;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L4;\n"
		"    t_float = a.valor.v_int - b.valor.v_float;\n"
		"    r = cria_float(t_float); goto FIM;\n"
		"L4: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L_ERR;\n"
		"    t_float = a.valor.v_float - b.valor.v_int;\n"
		"    r = cria_float(t_float); goto FIM;\n"
		"L_ERR:\n"
		"    erro_runtime(\"-\");\n"
		"FIM:\n"
		"    return r;\n"
	"}\n"
	"\n"

	// Função de Multiplicação
	"Var mult_dinamica(Var a, Var b) {\n"
		"    Var r;\n"
		"    int c, t_int;\n"
		"    float t_float;\n"
		"L1: c = (a.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    t_int = a.valor.v_int * b.valor.v_int;\n"
		"    r = cria_int(t_int); goto FIM;\n"
		"L2: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    t_float = a.valor.v_float * b.valor.v_float;\n"
		"    r = cria_float(t_float); goto FIM;\n"
		"L3: c = (a.tipo == TIPO_INT); if (c == 0) goto L4;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L4;\n"
		"    t_float = a.valor.v_int * b.valor.v_float;\n"
		"    r = cria_float(t_float); goto FIM;\n"
		"L4: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L_ERR;\n"
		"    t_float = a.valor.v_float * b.valor.v_int;\n"
		"    r = cria_float(t_float); goto FIM;\n"
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
		"L1: c = (a.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    t_int = a.valor.v_int / b.valor.v_int;\n"
		"    r = cria_int(t_int); goto FIM;\n"
		"L2: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    t_float = a.valor.v_float / b.valor.v_float;\n"
		"    r = cria_float(t_float); goto FIM;\n"
		"L3: c = (a.tipo == TIPO_INT); if (c == 0) goto L4;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L4;\n"
		"    t_float = a.valor.v_int / b.valor.v_float;\n"
		"    r = cria_float(t_float); goto FIM;\n"
		"L4: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L_ERR;\n"
		"    t_float = a.valor.v_float / b.valor.v_int;\n"
		"    r = cria_float(t_float); goto FIM;\n"
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
		"L1: c = (a.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    r = cria_bool(a.valor.v_int == b.valor.v_int); goto FIM;\n"
		"L2: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    r = cria_bool(a.valor.v_float == b.valor.v_float); goto FIM;\n"
		"L3: c = (a.tipo == TIPO_INT); if (c == 0) goto L4;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L4;\n"
		"    r = cria_bool(a.valor.v_int == b.valor.v_float); goto FIM;\n"
		"L4: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L5;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L5;\n"
		"    r = cria_bool(a.valor.v_float == b.valor.v_int); goto FIM;\n"
		"L5: c = (a.tipo == TIPO_CHAR); if (c == 0) goto L6;\n"
		"    c = (b.tipo == TIPO_CHAR); if (c == 0) goto L6;\n"
		"    r = cria_bool(a.valor.v_char == b.valor.v_char); goto FIM;\n"
		"L6: c = (a.tipo == TIPO_BOOL); if (c == 0) goto L7;\n"
		"    c = (b.tipo == TIPO_BOOL); if (c == 0) goto L7;\n"
		"    r = cria_bool(a.valor.v_bool == b.valor.v_bool); goto FIM;\n"
		"L7: c = (a.tipo == TIPO_STRING); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_STRING); if (c == 0) goto L_ERR;\n"
		"    c = strcmp(a.valor.v_string, b.valor.v_string);\n"
		"    r = cria_bool(c == 0); goto FIM;\n"
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
		"L1: c = (a.tipo == TIPO_BOOL); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_BOOL); if (c == 0) goto L_ERR;\n"
		"    r = cria_bool(a.valor.v_bool && b.valor.v_bool); goto FIM;\n"
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
		"L1: c = (a.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    r = cria_bool(a.valor.v_int > b.valor.v_int); goto FIM;\n"
		"L2: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    r = cria_bool(a.valor.v_float > b.valor.v_float); goto FIM;\n"
		"L3: c = (a.tipo == TIPO_INT); if (c == 0) goto L4;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L4;\n"
		"    r = cria_bool(a.valor.v_int > b.valor.v_float); goto FIM;\n"
		"L4: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L_ERR;\n"
		"    r = cria_bool(a.valor.v_float > b.valor.v_int); goto FIM;\n"
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
		"L1: c = (a.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    r = cria_bool(a.valor.v_int < b.valor.v_int); goto FIM;\n"
		"L2: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    r = cria_bool(a.valor.v_float < b.valor.v_float); goto FIM;\n"
		"L3: c = (a.tipo == TIPO_INT); if (c == 0) goto L4;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L4;\n"
		"    r = cria_bool(a.valor.v_int < b.valor.v_float); goto FIM;\n"
		"L4: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L_ERR;\n"
		"    r = cria_bool(a.valor.v_float < b.valor.v_int); goto FIM;\n"
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
		"L1: c = (a.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    r = cria_bool(a.valor.v_int >= b.valor.v_int); goto FIM;\n"
		"L2: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    r = cria_bool(a.valor.v_float >= b.valor.v_float); goto FIM;\n"
		"L3: c = (a.tipo == TIPO_INT); if (c == 0) goto L4;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L4;\n"
		"    r = cria_bool(a.valor.v_int >= b.valor.v_float); goto FIM;\n"
		"L4: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L_ERR;\n"
		"    r = cria_bool(a.valor.v_float >= b.valor.v_int); goto FIM;\n"
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
		"L1: c = (a.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    r = cria_bool(a.valor.v_int <= b.valor.v_int); goto FIM;\n"
		"L2: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    r = cria_bool(a.valor.v_float <= b.valor.v_float); goto FIM;\n"
		"L3: c = (a.tipo == TIPO_INT); if (c == 0) goto L4;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L4;\n"
		"    r = cria_bool(a.valor.v_int <= b.valor.v_float); goto FIM;\n"
		"L4: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L_ERR;\n"
		"    r = cria_bool(a.valor.v_float <= b.valor.v_int); goto FIM;\n"
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
		"L1: c = (a.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L2;\n"
		"    r = cria_bool(a.valor.v_int != b.valor.v_int); goto FIM;\n"
		"L2: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L3;\n"
		"    r = cria_bool(a.valor.v_float != b.valor.v_float); goto FIM;\n"
		"L3: c = (a.tipo == TIPO_INT); if (c == 0) goto L4;\n"
		"    c = (b.tipo == TIPO_FLOAT); if (c == 0) goto L4;\n"
		"    r = cria_bool(a.valor.v_int != b.valor.v_float); goto FIM;\n"
		"L4: c = (a.tipo == TIPO_FLOAT); if (c == 0) goto L5;\n"
		"    c = (b.tipo == TIPO_INT); if (c == 0) goto L5;\n"
		"    r = cria_bool(a.valor.v_float != b.valor.v_int); goto FIM;\n"
		"L5: c = (a.tipo == TIPO_CHAR); if (c == 0) goto L6;\n"
		"    c = (b.tipo == TIPO_CHAR); if (c == 0) goto L6;\n"
		"    r = cria_bool(a.valor.v_char != b.valor.v_char); goto FIM;\n"
		"L6: c = (a.tipo == TIPO_BOOL); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_BOOL); if (c == 0) goto L_ERR;\n"
		"    r = cria_bool(a.valor.v_bool != b.valor.v_bool); goto FIM;\n"
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
		"L1: c = (a.tipo == TIPO_BOOL); if (c == 0) goto L_ERR;\n"
		"    c = (b.tipo == TIPO_BOOL); if (c == 0) goto L_ERR;\n"
		"    r = cria_bool(a.valor.v_bool || b.valor.v_bool); goto FIM;\n"
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
		"L1: c = (a.tipo == TIPO_BOOL); if (c == 0) goto L_ERR;\n"
		"    r = cria_bool(!a.valor.v_bool); goto FIM;\n"
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
%token TK_IF TK_ELSE TK_WHILE TK_DO TK_FOR TK_SWITCH TK_CASE TK_DEFAULT
%token TK_IN TK_TO TK_INC

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
CMD			: TK_ID '=' E TK_NEWLINE
			{
				registrar_variavel($1.label);
				$$.traducao = $3.traducao + "\t" + $1.label + " = " + $3.label + ";\n";
			}
			// Absorve linhas sobrando no código
			| TK_NEWLINE
			{
				$$.traducao = ""; 
			}
			| TK_PRINT '(' E ')' TK_NEWLINE
			{
				$$.traducao = $3.traducao + "\tprint_dinamico(" + $3.label + ");\n";
			}
			| E TK_NEWLINE
			{
                $$.traducao = $1.traducao;
			}

	/* x++ */
			| TK_ID TK_INC TK_NEWLINE
			{
				registrar_variavel($1.label);
				string temp_um = gentempcode();
				
				// TAC: x = soma_dinamica(x, 1);
				$$.traducao = "\t" + temp_um + " = cria_int(1);\n" +
							  "\t" + $1.label + " = soma_dinamica(" + $1.label + ", " + temp_um + ");\n";
			}

	/* if isolado */
			| TK_IF E ':' TK_NEWLINE TK_INDENT LISTA_COMANDOS TK_DEDENT
			{
				string l_fim = gen_label();
				$$.traducao = $2.traducao + 
							  "\tif (eh_verdadeiro(" + $2.label + ") == 0) goto " + l_fim + ";\n" +
							  $6.traducao +
							  l_fim + ":\n";
			}

	/* if else */
			| TK_IF E ':' TK_NEWLINE TK_INDENT LISTA_COMANDOS TK_DEDENT TK_ELSE ':' TK_NEWLINE TK_INDENT LISTA_COMANDOS TK_DEDENT
			{
				string l_falso = gen_label();
				string l_fim = gen_label();
				$$.traducao = $2.traducao + 
							  "\tif (eh_verdadeiro(" + $2.label + ") == 0) goto " + l_falso + ";\n" +
							  $6.traducao +
							  "\tgoto " + l_fim + ";\n" +
							  l_falso + ":\n" +
							  $12.traducao +
							  l_fim + ":\n";
			}

	/* while */
			| TK_WHILE E ':' TK_NEWLINE TK_INDENT LISTA_COMANDOS TK_DEDENT
			{
				string l_inicio = gen_label();
				string l_fim = gen_label();
				$$.traducao = l_inicio + ":\n" +
							  $2.traducao +
							  "\tif (eh_verdadeiro(" + $2.label + ") == 0) goto " + l_fim + ";\n" +
							  $6.traducao +
							  "\tgoto " + l_inicio + ";\n" +
							  l_fim + ":\n";
			}

	/* do while (executa o bloco e testa se eh true no final) */
			| TK_DO ':' TK_NEWLINE TK_INDENT LISTA_COMANDOS TK_DEDENT TK_WHILE E TK_NEWLINE
			{
				string l_inicio = gen_label();
				$$.traducao = l_inicio + ":\n" +
							  $5.traducao +
							  $8.traducao +
							  "\tif (eh_verdadeiro(" + $8.label + ") != 0) goto " + l_inicio + ";\n";
			}

	/* for i in x to y: */
			| TK_FOR TK_ID TK_IN E TK_TO E ':' TK_NEWLINE TK_INDENT LISTA_COMANDOS TK_DEDENT
			{
				string l_inicio = gen_label();
				string l_fim = gen_label();
				string temp_cond = gentempcode();
				string temp_um = gentempcode();
				
				// registra a variavel iteradora (i)
				registrar_variavel($2.label);
				
				// inicializa i com o valor de x
				string trad_init = $4.traducao + "\t" + $2.label + " = " + $4.label + ";\n";
				
				// monta o laço
				$$.traducao = trad_init + 
							  l_inicio + ":\n" +
							  $6.traducao + // avalia o teto (y)
							  "\t" + temp_cond + " = menor_igual_dinamico(" + $2.label + ", " + $6.label + ");\n" +
							  "\tif (eh_verdadeiro(" + temp_cond + ") == 0) goto " + l_fim + ";\n" +
							  $10.traducao + // corpo do for
							  "\t" + temp_um + " = cria_int(1);\n" + 
							  "\t" + $2.label + " = soma_dinamica(" + $2.label + ", " + temp_um + ");\n" + // i = i+1
							  "\tgoto " + l_inicio + ";\n" +
							  l_fim + ":\n";
			}

	/* switch case (basicamente uma cascata de ifs) */
			| TK_SWITCH E ':' TK_NEWLINE TK_INDENT 
			{ 
				switch_var_stack.push($2.label); 
				switch_fim_stack.push(gen_label()); 
			} 
			LISTA_CASOS TK_DEDENT
			{
				$$.traducao = $2.traducao + $7.traducao + switch_fim_stack.top() + ":\n";
				switch_var_stack.pop();
				switch_fim_stack.pop();
			}
		    ;

/* regras relacionadas ao switch */
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

CASO		: TK_CASE E ':' TK_NEWLINE TK_INDENT LISTA_COMANDOS TK_DEDENT
			{
				string l_prox_caso = gen_label();
				string var_switch = switch_var_stack.top();
				string l_fim = switch_fim_stack.top();
				string var_teste = gentempcode();
				
				$$.traducao = $2.traducao +
							  "\t" + var_teste + " = igual_dinamico(" + var_switch + ", " + $2.label + ");\n" +
							  "\tif (eh_verdadeiro(" + var_teste + ") == 0) goto " + l_prox_caso + ";\n" +
							  $6.traducao +
							  "\tgoto " + l_fim + ";\n" +
							  l_prox_caso + ":\n";
			}
			;

DEFAULT		: TK_DEFAULT ':' TK_NEWLINE TK_INDENT LISTA_COMANDOS TK_DEDENT
			{
				string l_fim = switch_fim_stack.top();
				$$.traducao = $5.traducao + "\tgoto " + l_fim + ";\n";
			}
			;

	/* Expressão 			*/
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

	if (yyparse() == 0)
		cout << codigo_gerado;

	return 0;
}

void yyerror(string MSG) {
	cerr << "Erro na linha " << linha << ": " << MSG << endl;
}
