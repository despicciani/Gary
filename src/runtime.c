#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int linha_execucao = 1;

int lenstr(const char* str) {
    int len;
	 int t1;
    char c;
    len = 0;
L_LOOP:
    c = str[len];
    t1 = (c == '\0');
    if (t1) goto L_FIM;
    len = len + 1;
    goto L_LOOP;
L_FIM:
    return len;
}

typedef enum { TIPO_INT, TIPO_FLOAT, TIPO_CHAR, TIPO_BOOL, TIPO_STRING, TIPO_ARRAY } TipoVar;
struct Var_struct;
typedef struct Var_struct {
    TipoVar tipo;
    union {
        int v_int;
        float v_float;
        char v_char;
        int v_bool;
        char* v_string;
        struct {
            int tamanho;
            struct Var_struct* elementos;
        } v_array;
    } valor;
} Var;
void erro_runtime(const char* operacao);
Var cria_int(int v);

Var cria_array(Var tamanho) {
    Var res;
    int c, tam;
    int size_elem, size_total;
    void* ptr_raw;
    c = (tamanho.tipo != TIPO_INT);
    if (c) goto L_ERR;
    tam = tamanho.valor.v_int;
    res.tipo = TIPO_ARRAY;
    res.valor.v_array.tamanho = tam;
    size_elem = sizeof(struct Var_struct);
    size_total = tam * size_elem;
    ptr_raw = malloc(size_total);
    res.valor.v_array.elementos = (struct Var_struct*)ptr_raw;
    return res;
L_ERR:
    erro_runtime("Array Size");
}

Var get_array_size(Var arr) {
    int c;
    c = (arr.tipo != TIPO_ARRAY);
    if (c) goto L_ERR;
    return cria_int(arr.valor.v_array.tamanho);
L_ERR:
    erro_runtime("Tamanho (Nao e um Array)");
}

Var get_array(Var arr, Var indice) {
    int c;
    c = (arr.tipo != TIPO_ARRAY);
    if (c) goto L_ERR1;
    c = (indice.tipo != TIPO_INT);
    if (c) goto L_ERR2;
    c = (indice.valor.v_int < 0);
    if (c) goto L_ERR3;
    c = (indice.valor.v_int >= arr.valor.v_array.tamanho);
    if (c) goto L_ERR4;
    return arr.valor.v_array.elementos[indice.valor.v_int];
L_ERR1:
    erro_runtime("[] (Nao e um Array)");
L_ERR2:
    erro_runtime("[] (Indice nao e INT)");
L_ERR3:
    erro_runtime("Index < 0");
L_ERR4:
    erro_runtime("Index Out of Bounds");
}

void set_array(Var arr, Var indice, Var valor) {
    int c;
    c = (arr.tipo != TIPO_ARRAY);
    if (c) goto L_ERR1;
    c = (indice.tipo != TIPO_INT);
    if (c) goto L_ERR2;
    c = (indice.valor.v_int < 0);
    if (c) goto L_ERR3;
    c = (indice.valor.v_int >= arr.valor.v_array.tamanho);
    if (c) goto L_ERR4;
    arr.valor.v_array.elementos[indice.valor.v_int] = valor;
    return;
L_ERR1:
    erro_runtime("[]= (Nao e um Array)");
L_ERR2:
    erro_runtime("[]= (Indice nao e INT)");
L_ERR3:
    erro_runtime("Index < 0");
L_ERR4:
    erro_runtime("Index Out of Bounds");
}
Var cria_int(int v) { Var res; res.tipo = TIPO_INT; res.valor.v_int = v; return res; }
Var cria_float(float v) { Var res; res.tipo = TIPO_FLOAT; res.valor.v_float = v; return res; }
Var cria_char(char v) { Var res; res.tipo = TIPO_CHAR; res.valor.v_char = v; return res; }
Var cria_bool(int v) { Var res; res.tipo = TIPO_BOOL; res.valor.v_bool = v; return res; }

Var cria_string(const char* v) {
    Var res; int len; char* ptr;
    res.tipo = TIPO_STRING;
    len = lenstr(v);
    len = len + 1;
    ptr = (char*)malloc(len);
    strcpy(ptr, v);
    res.valor.v_string = ptr;
    return res;
}

void erro_runtime(const char* operacao) {
    printf("Erro de Execucao na linha %d: Tipos incompativeis para a operacao '%s'.\n", linha_execucao, operacao);
    exit(1);
}

int eh_verdadeiro(Var v) {
    int c;
    int t;
    c = (v.tipo != TIPO_BOOL);
    if (c) goto L_INT;
    return v.valor.v_bool;
L_INT:
    c = (v.tipo != TIPO_INT);
    if (c) goto L_FLOAT;
    t = (v.valor.v_int != 0);
    return t;
L_FLOAT:
    c = (v.tipo != TIPO_FLOAT);
    if (c) goto L_STR;
    t = (v.valor.v_float != 0.0);
    return t;
L_STR:
    c = (v.tipo != TIPO_STRING);
    if (c) goto L_CHAR;
    t = lenstr(v.valor.v_string);
    c = (t > 0);
    return c;
L_CHAR:
    c = (v.tipo != TIPO_CHAR);
    if (c) goto L_FIM;
    t = (v.valor.v_char != '\0');
    return t;
L_FIM:
    return 1;
}

void print_dinamico(Var v) {
    int cond;
L_PRINT_INT:
    cond = (v.tipo != TIPO_INT);
    if (cond) goto L_PRINT_FLOAT;
    printf("%d\n", v.valor.v_int);
    goto L_PRINT_FIM;
L_PRINT_FLOAT:
    cond = (v.tipo != TIPO_FLOAT);
    if (cond) goto L_PRINT_CHAR;
    printf("%f\n", v.valor.v_float);
    goto L_PRINT_FIM;
L_PRINT_CHAR:
    cond = (v.tipo != TIPO_CHAR);
    if (cond) goto L_PRINT_BOOL;
    printf("%c\n", v.valor.v_char);
    goto L_PRINT_FIM;
L_PRINT_BOOL:
    cond = (v.tipo != TIPO_BOOL);
    if (cond) goto L_PRINT_STRING;
    cond = (v.valor.v_bool != 1);
    if (cond) goto L_PRINT_FALSE;
    printf("true\n");
    goto L_PRINT_FIM;
L_PRINT_STRING:
    cond = (v.tipo != TIPO_STRING);
    if (cond) goto L_PRINT_FIM;
    printf("%s\n", v.valor.v_string);
    goto L_PRINT_FIM;
L_PRINT_FALSE:
    printf("false\n");
L_PRINT_FIM:
    return;
}

Var input_dinamico() {
    char* buffer;
    char* new_buf;
    int cap;
    int len;
    int ch;
    int t1;
    int t2;
    int t_int;
    float t_float;
    char t_char;
    char* endptr;
    long val_int;
    double val_float;
    Var res;

    cap = 32;
    buffer = (char*)malloc(cap);
    len = 0;

L_READ:
    ch = fgetc(stdin);
    t1 = (ch == EOF);
    if (t1) goto L_FIM_READ;
    t1 = (ch == '\n');
    if (t1) goto L_FIM_READ;
    t1 = (ch == '\r');
    if (t1) goto L_READ;

	 t_char = (char)ch;
    buffer[len] = t_char;
    len = len + 1;
    t1 = (len < cap);
    if (t1) goto L_READ;

    cap = cap * 2;
    new_buf = (char*)realloc(buffer, cap);
    buffer = new_buf;
    goto L_READ;

L_FIM_READ:
    buffer[len] = '\0';

    t1 = strcmp(buffer, "true");
    t2 = (t1 != 0);
    if (t2) goto L_FALSE;
    res = cria_bool(1);
    goto FIM;
L_FALSE:
    t1 = strcmp(buffer, "false");
    t2 = (t1 != 0);
    if (t2) goto L_INT;
    res = cria_bool(0);
    goto FIM;
L_INT:
    val_int = strtol(buffer, &endptr, 10);
    t1 = (endptr == buffer);
    if (t1) goto L_FLOAT;
    t2 = (*endptr != '\0');
    if (t2) goto L_FLOAT;
    t_int = (int)val_int;
    res = cria_int(t_int);
    goto FIM;
L_FLOAT:
    val_float = strtod(buffer, &endptr);
    t1 = (endptr == buffer);
    if (t1) goto L_CHAR;
    t2 = (*endptr != '\0');
    if (t2) goto L_CHAR;
    t_float = (float)val_float;
    res = cria_float(t_float);
    goto FIM;
L_CHAR:
    t1 = (len != 1);
    if (t1) goto L_STR;
    t_char = buffer[0];
    res = cria_char(t_char);
    goto FIM;
L_STR:
    res = cria_string(buffer);
FIM:
    free(buffer);
    return res;
}

Var soma_dinamica(Var a, Var b) {
    Var r;
    int c;
    int t_int;
    int len_a;
    int len_b;
	 int len_tot;
    float t_float;
    char* tmp_str;
    c = (a.tipo != TIPO_INT);
    if (c) goto L1;
    c = (b.tipo != TIPO_INT);
    if (c) goto L1;
    t_int = a.valor.v_int + b.valor.v_int;
    r = cria_int(t_int);
    goto FIM;
L1:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L2;
    t_float = a.valor.v_float + b.valor.v_float;
    r = cria_float(t_float);
    goto FIM;
L2:
    c = (a.tipo != TIPO_INT);
    if (c) goto L3;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L3;
    t_float = (float)a.valor.v_int;
    t_float = t_float + b.valor.v_float;
    r = cria_float(t_float);
    goto FIM;
L3:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L4;
    c = (b.tipo != TIPO_INT);
    if (c) goto L4;
    t_float = (float)b.valor.v_int;
    t_float = a.valor.v_float + t_float;
    r = cria_float(t_float);
    goto FIM;
L4:
    c = (a.tipo != TIPO_STRING);
    if (c) goto L_ERR;
    c = (b.tipo != TIPO_STRING);
    if (c) goto L_ERR;
    len_a = lenstr(a.valor.v_string);
    len_b = lenstr(b.valor.v_string);
    len_tot = len_a + len_b;
    len_tot = len_tot + 1;
    tmp_str = (char*)malloc(len_tot);
    strcpy(tmp_str, a.valor.v_string);
    strcat(tmp_str, b.valor.v_string);
    r = cria_string(tmp_str);
    free(tmp_str);
    goto FIM;
L_ERR:
    erro_runtime("+");
FIM:
    return r;
}

Var sub_dinamica(Var a, Var b) {
    Var r;
    int c;
	 int t_int;
    float t_float;
    c = (a.tipo != TIPO_INT);
    if (c) goto L1;
    c = (b.tipo != TIPO_INT);
    if (c) goto L1;
    t_int = a.valor.v_int - b.valor.v_int;
    r = cria_int(t_int);
    goto FIM;
L1:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L2;
    t_float = a.valor.v_float - b.valor.v_float;
    r = cria_float(t_float);
    goto FIM;
L2:
    c = (a.tipo != TIPO_INT);
    if (c) goto L3;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L3;
    t_float = (float)a.valor.v_int;
    t_float = t_float - b.valor.v_float;
    r = cria_float(t_float);
    goto FIM;
L3:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L_ERR;
    c = (b.tipo != TIPO_INT);
    if (c) goto L_ERR;
    t_float = (float)b.valor.v_int;
    t_float = a.valor.v_float - t_float;
    r = cria_float(t_float);
    goto FIM;
L_ERR:
    erro_runtime("-");
FIM:
    return r;
}

Var mult_dinamica(Var a, Var b) {
    Var r;
    int c;
    int t_int;
    float t_float;
    c = (a.tipo != TIPO_INT);
    if (c) goto L1;
    c = (b.tipo != TIPO_INT);
    if (c) goto L1;
    t_int = a.valor.v_int * b.valor.v_int;
    r = cria_int(t_int);
    goto FIM;
L1:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L2;
    t_float = a.valor.v_float * b.valor.v_float;
    r = cria_float(t_float);
    goto FIM;
L2:
    c = (a.tipo != TIPO_INT);
    if (c) goto L3;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L3;
    t_float = (float)a.valor.v_int;
    t_float = t_float * b.valor.v_float;
    r = cria_float(t_float);
    goto FIM;
L3:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L_ERR;
    c = (b.tipo != TIPO_INT);
    if (c) goto L_ERR;
    t_float = (float)b.valor.v_int;
    t_float = a.valor.v_float * t_float;
    r = cria_float(t_float);
    goto FIM;
L_ERR:
    erro_runtime("*");
FIM:
    return r;
}

Var div_dinamica(Var a, Var b) {
    Var r;
    int c, t_int;
    float t_float;
    c = (a.tipo != TIPO_INT);
    if (c) goto L1;
    c = (b.tipo != TIPO_INT);
    if (c) goto L1;
    t_int = a.valor.v_int / b.valor.v_int;
    r = cria_int(t_int);
    goto FIM;
L1:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L2;
    t_float = a.valor.v_float / b.valor.v_float;
    r = cria_float(t_float);
    goto FIM;
L2:
    c = (a.tipo != TIPO_INT);
    if (c) goto L3;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L3;
    t_float = (float)a.valor.v_int;
    t_float = t_float / b.valor.v_float;
    r = cria_float(t_float);
    goto FIM;
L3:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L_ERR;
    c = (b.tipo != TIPO_INT);
    if (c) goto L_ERR;
    t_float = (float)b.valor.v_int;
    t_float = a.valor.v_float / t_float;
    r = cria_float(t_float);
    goto FIM;
L_ERR:
    erro_runtime("/");
FIM:
    return r;
}

Var exp_dinamico(Var a, Var b) {
    Var r;
    int c, t_int;
    int base_int, exp_int, i;
    float base_float, result_float;
    int is_float_base = 0;
    c = (b.tipo != TIPO_INT);
    if (c) goto L_ERR_EXP;
    exp_int = b.valor.v_int;
    c = (exp_int < 0);
    if (c) goto L_ERR_NEG;
    c = (a.tipo == TIPO_FLOAT);
    if (c) goto L_FLOAT_BASE;
    c = (a.tipo != TIPO_INT);
    if (c) goto L_ERR_TIPO;
    base_int = a.valor.v_int;
    goto L_CALC;
L_FLOAT_BASE:
    is_float_base = 1;
    base_float = a.valor.v_float;
L_CALC:
    c = is_float_base;
    if (!c) goto L_INT_LOOP_INIT;
    
    result_float = 1.0;
    i = 0;
L_FLOAT_LOOP:
    c = (i < exp_int);
    if (!c) goto L_FLOAT_END;
    result_float = result_float * base_float;
    i = i + 1;
    goto L_FLOAT_LOOP;
L_FLOAT_END:
    r = cria_float(result_float);
    goto FIM;

L_INT_LOOP_INIT:
    t_int = 1;
    i = 0;
L_INT_LOOP:
    c = (i < exp_int);
    if (!c) goto L_INT_END;
    t_int = t_int * base_int;
    i = i + 1;
    goto L_INT_LOOP;
L_INT_END:
    r = cria_int(t_int);
    goto FIM;
L_ERR_NEG:
    printf("Erro de Execucao na linha %d: A exponenciacao suporta apenas expoentes inteiros positivos.\n", linha_execucao);
    exit(1);
L_ERR_EXP:
    printf("Erro de Execucao na linha %d: A exponenciacao suporta apenas expoentes inteiros.\n", linha_execucao);
    exit(1);
L_ERR_TIPO:
    erro_runtime("**");
FIM:
    return r;
}

Var fat_dinamico(Var a) {
    Var r;
    int c, n, res = 1, i;
    c = (a.tipo != TIPO_INT);
    if (c) goto L_ERR;
    n = a.valor.v_int;
    c = (n < 0);
    if (c) goto L_ERR_NEG;
    res = 1;
    i = 1;
L_LOOP:
    c = (i <= n);
    if (!c) goto L_FIM_FAT;
    res = res * i;
    i = i + 1;
    goto L_LOOP;
L_FIM_FAT:
    r = cria_int(res);
    goto FIM;
L_ERR:
    erro_runtime("!");
L_ERR_NEG:
    printf("Erro de Execucao na linha %d: Fatorial nao definido para numeros negativos.\n", linha_execucao);
    exit(1);
FIM:
    return r;
}

Var igual_dinamico(Var a, Var b) {
    Var r;
    int c;
    float t_float;
    c = (a.tipo != TIPO_INT);
    if (c) goto L1;
    c = (b.tipo != TIPO_INT);
    if (c) goto L1;
    c = (a.valor.v_int == b.valor.v_int);
    r = cria_bool(c);
    goto FIM;
L1:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (a.valor.v_float == b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L2:
    c = (a.tipo != TIPO_INT);
    if (c) goto L3;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L3;
    t_float = (float)a.valor.v_int;
    c = (t_float == b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L3:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L4;
    c = (b.tipo != TIPO_INT);
    if (c) goto L4;
    t_float = (float)b.valor.v_int;
    c = (a.valor.v_float == t_float);
    r = cria_bool(c);
    goto FIM;
L4:
    c = (a.tipo != TIPO_CHAR);
    if (c) goto L5;
    c = (b.tipo != TIPO_CHAR);
    if (c) goto L5;
    c = (a.valor.v_char == b.valor.v_char);
    r = cria_bool(c);
    goto FIM;
L5:
    c = (a.tipo != TIPO_BOOL);
    if (c) goto L6;
    c = (b.tipo != TIPO_BOOL);
    if (c) goto L6;
    c = (a.valor.v_bool == b.valor.v_bool);
    r = cria_bool(c);
    goto FIM;
L6:
    c = (a.tipo != TIPO_STRING);
    if (c) goto L_ERR;
    c = (b.tipo != TIPO_STRING);
    if (c) goto L_ERR;
    c = strcmp(a.valor.v_string, b.valor.v_string);
    c = (c == 0);
    r = cria_bool(c);
    goto FIM;
L_ERR:
    erro_runtime("==");
FIM:
    return r;
}

Var maior_dinamico(Var a, Var b) {
    Var r;
    int c;
    float t_float;
    c = (a.tipo != TIPO_INT);
    if (c) goto L1;
    c = (b.tipo != TIPO_INT);
    if (c) goto L1;
    c = (a.valor.v_int > b.valor.v_int);
    r = cria_bool(c);
    goto FIM;
L1:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (a.valor.v_float > b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L2:
    c = (a.tipo != TIPO_INT);
    if (c) goto L3;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L3;
    t_float = (float)a.valor.v_int;
    c = (t_float > b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L3:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L_ERR;
    c = (b.tipo != TIPO_INT);
    if (c) goto L_ERR;
    t_float = (float)b.valor.v_int;
    c = (a.valor.v_float > t_float);
    r = cria_bool(c);
    goto FIM;
L_ERR:
    erro_runtime(">");
FIM:
    return r;
}

Var menor_dinamico(Var a, Var b) {
    Var r;
    int c;
    float t_float;
    c = (a.tipo != TIPO_INT);
    if (c) goto L1;
    c = (b.tipo != TIPO_INT);
    if (c) goto L1;
    c = (a.valor.v_int < b.valor.v_int);
    r = cria_bool(c);
    goto FIM;
L1:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (a.valor.v_float < b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L2:
    c = (a.tipo != TIPO_INT);
    if (c) goto L3;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L3;
    t_float = (float)a.valor.v_int;
    c = (t_float < b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L3:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L_ERR;
    c = (b.tipo != TIPO_INT);
    if (c) goto L_ERR;
    t_float = (float)b.valor.v_int;
    c = (a.valor.v_float < t_float);
    r = cria_bool(c);
    goto FIM;
L_ERR:
    erro_runtime("<");
FIM:
    return r;
}

Var maior_igual_dinamico(Var a, Var b) {
    Var r;
    int c;
    float t_float;
    c = (a.tipo != TIPO_INT);
    if (c) goto L1;
    c = (b.tipo != TIPO_INT);
    if (c) goto L1;
    c = (a.valor.v_int >= b.valor.v_int);
    r = cria_bool(c);
    goto FIM;
L1:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (a.valor.v_float >= b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L2:
    c = (a.tipo != TIPO_INT);
    if (c) goto L3;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L3;
    t_float = (float)a.valor.v_int;
    c = (t_float >= b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L3:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L_ERR;
    c = (b.tipo != TIPO_INT);
    if (c) goto L_ERR;
    t_float = (float)b.valor.v_int;
    c = (a.valor.v_float >= t_float);
    r = cria_bool(c);
    goto FIM;
L_ERR:
    erro_runtime(">=");
FIM:
    return r;
}

Var menor_igual_dinamico(Var a, Var b) {
    Var r;
    int c;
    float t_float;
    c = (a.tipo != TIPO_INT);
    if (c) goto L1;
    c = (b.tipo != TIPO_INT);
    if (c) goto L1;
    c = (a.valor.v_int <= b.valor.v_int);
    r = cria_bool(c);
    goto FIM;
L1:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (a.valor.v_float <= b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L2:
    c = (a.tipo != TIPO_INT);
    if (c) goto L3;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L3;
    t_float = (float)a.valor.v_int;
    c = (t_float <= b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L3:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L_ERR;
    c = (b.tipo != TIPO_INT);
    if (c) goto L_ERR;
    t_float = (float)b.valor.v_int;
    c = (a.valor.v_float <= t_float);
    r = cria_bool(c);
    goto FIM;
L_ERR:
    erro_runtime("<=");
FIM:
    return r;
}

Var diferente_dinamico(Var a, Var b) {
    Var r;
    int c;
    float t_float;
    c = (a.tipo != TIPO_INT);
    if (c) goto L1;
    c = (b.tipo != TIPO_INT);
    if (c) goto L1;
    c = (a.valor.v_int != b.valor.v_int);
    r = cria_bool(c);
    goto FIM;
L1:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L2;
    c = (a.valor.v_float != b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L2:
    c = (a.tipo != TIPO_INT);
    if (c) goto L3;
    c = (b.tipo != TIPO_FLOAT);
    if (c) goto L3;
    t_float = (float)a.valor.v_int;
    c = (t_float != b.valor.v_float);
    r = cria_bool(c);
    goto FIM;
L3:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L4;
    c = (b.tipo != TIPO_INT);
    if (c) goto L4;
    t_float = (float)b.valor.v_int;
    c = (a.valor.v_float != t_float);
    r = cria_bool(c);
    goto FIM;
L4:
    c = (a.tipo != TIPO_CHAR);
    if (c) goto L5;
    c = (b.tipo != TIPO_CHAR);
    if (c) goto L5;
    c = (a.valor.v_char != b.valor.v_char);
    r = cria_bool(c);
    goto FIM;
L5:
    c = (a.tipo != TIPO_BOOL);
    if (c) goto L6;
    c = (b.tipo != TIPO_BOOL);
    if (c) goto L6;
    c = (a.valor.v_bool != b.valor.v_bool);
    r = cria_bool(c);
    goto FIM;
L6:
    c = (a.tipo != TIPO_STRING);
    if (c) goto L_ERR;
    c = (b.tipo != TIPO_STRING);
    if (c) goto L_ERR;
    c = strcmp(a.valor.v_string, b.valor.v_string);
    c = (c != 0);
    r = cria_bool(c);
    goto FIM;
L_ERR:
    erro_runtime("!=");
FIM:
    return r;
}

Var and_dinamico(Var a, Var b) {
    Var r;
    int c1;
    int c3;

    c1 = eh_verdadeiro(a);
    if (!c1) goto L_false;

    c3 = eh_verdadeiro(b);
    goto L_end;

L_false:
    c3 = 0;

L_end:
    r = cria_bool(c3);
    return r;
}

Var or_dinamico(Var a, Var b) {
    Var r;
    int c1;
    int c3;

    c1 = eh_verdadeiro(a);
    if (!c1) goto L_eval_b;

    c3 = 1;
    goto L_end;

L_eval_b:
    c3 = eh_verdadeiro(b);

L_end:
    r = cria_bool(c3);
    return r;
}

Var not_dinamico(Var a) {
    Var r;
    int c1;
    int c2;
    c1 = eh_verdadeiro(a);
    c2 = !c1;
    r = cria_bool(c2);
    return r;
}
Var cast_int(Var a) {
    Var r;
    int c;
    int t_int;
    long l_val;
    char* endptr;
    c = (a.tipo != TIPO_INT);
    if (c) goto L1;
    r = a;
    goto FIM;
L1:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L2;
    t_int = (int)a.valor.v_float;
    r = cria_int(t_int);
    goto FIM;
L2:
    c = (a.tipo != TIPO_BOOL);
    if (c) goto L3;
    r = cria_int(a.valor.v_bool);
    goto FIM;
L3:
    c = (a.tipo != TIPO_STRING);
    if (c) goto L_ERR;
    l_val = strtol(a.valor.v_string, &endptr, 10);
    c = (endptr == a.valor.v_string);
    if (c) goto L_ERR2;
    c = (*endptr != '\0');
    if (c) goto L_ERR2;
    t_int = (int)l_val;
    r = cria_int(t_int);
    goto FIM;
L_ERR:
    erro_runtime("int()");
L_ERR2:
    printf("Erro de Execucao na linha %d: Nao foi possivel converter a string em inteiro.\n", linha_execucao);
    exit(1);
FIM:
    return r;
}

Var cast_float(Var a) {
    Var r;
    int c;
    float t_float;
    char* endptr;
    double d_val;
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L1;
    r = a;
    goto FIM;
L1:
    c = (a.tipo != TIPO_INT);
    if (c) goto L2;
    t_float = (float)a.valor.v_int;
    r = cria_float(t_float);
    goto FIM;
L2:
    c = (a.tipo != TIPO_BOOL);
    if (c) goto L3;
    t_float = (float)a.valor.v_bool;
    r = cria_float(t_float);
    goto FIM;
L3:
    c = (a.tipo != TIPO_STRING);
    if (c) goto L_ERR;
    d_val = strtod(a.valor.v_string, &endptr);
    c = (endptr == a.valor.v_string);
    if (c) goto L_ERR2;
    c = (*endptr != '\0');
    if (c) goto L_ERR2;
    t_float = (float)d_val;
    r = cria_float(t_float);
    goto FIM;
L_ERR:
    erro_runtime("float()");
L_ERR2:
    printf("Erro de Execucao na linha %d: Nao foi possivel converter a string em float.\n", linha_execucao);
    exit(1);
FIM:
    return r;
}

Var cast_str(Var a) {
    Var r;
    int c;
    char* buf;
    c = (a.tipo != TIPO_STRING);
    if (c) goto L1;
    r = cria_string(a.valor.v_string);
    goto FIM;
L1:
    c = (a.tipo != TIPO_INT);
    if (c) goto L2;
    buf = (char*)malloc(32);
    sprintf(buf, "%d", a.valor.v_int);
    r = cria_string(buf);
    free(buf);
    goto FIM;
L2:
    c = (a.tipo != TIPO_FLOAT);
    if (c) goto L3;
    buf = (char*)malloc(64);
    sprintf(buf, "%f", a.valor.v_float);
    r = cria_string(buf);
    free(buf);
    goto FIM;
L3:
    c = (a.tipo != TIPO_BOOL);
    if (c) goto L4;
    c = (a.valor.v_bool == 1);
    if (c) goto L_TRUE;
    r = cria_string("false");
    goto FIM;
L_TRUE:
    r = cria_string("true");
    goto FIM;
L4:
    c = (a.tipo != TIPO_CHAR);
    if (c) goto L_ERR;
    buf = (char*)malloc(2);
    buf[0] = a.valor.v_char;
    buf[1] = '\0';
    r = cria_string(buf);
    free(buf);
    goto FIM;
L_ERR:
    erro_runtime("str()");
FIM:
    return r;
}

Var cast_bool(Var a) {
    Var r;
    int c;
    c = eh_verdadeiro(a);
    r = cria_bool(c);
    return r;
}

Var cast_char(Var a) {
    Var r;
    int c;
    int len;
    int c2;
    char t_char;
    c = (a.tipo != TIPO_CHAR);
    if (c) goto L1;
    r = a;
    goto FIM;
L1:
    c = (a.tipo != TIPO_STRING);
    if (c) goto L_ERR;
    len = strlen(a.valor.v_string);
    c2 = (len > 1);
    if (c2) goto L_ERR2;
    t_char = a.valor.v_string[0];
    r = cria_char(t_char);
    goto FIM;
L_ERR:
    erro_runtime("char()");
L_ERR2:
    printf("Erro de Execucao na linha %d: Operacao char() aceita somente strings de tamanho 1.\n", linha_execucao);
    exit(1);
FIM:
    return r;
}

