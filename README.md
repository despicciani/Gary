# Gary

<div align="center">

**Uma linguagem de programação dinamicamente tipada com sintaxe inspirada em Python.**

Gary compila para código C intermediário de 3 endereços, que pode ser compilado com GCC e executado nativamente.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## 📖 Sobre

<img align="right" width="200" alt="Gary" src="https://github.com/user-attachments/assets/e9b3ca82-0834-4378-90c9-01e6ef7df3c8" />

Gary é um compilador construído com **Flex** (análise léxica) e **Bison** (análise sintática) que traduz uma linguagem de alto nível com tipagem dinâmica para **código C** utilizando a técnica de **código de 3 endereços**.

A linguagem usa **indentação** como delimitador de bloco (como Python), suporta **tipagem dinâmica** com verificação em tempo de execução, e possui um runtime embutido que implementa uma struct `Var` (tagged union) capaz de armazenar `int`, `float`, `char`, `bool`, `string` e `array`.

Desenvolvido como projeto da disciplina de **Compiladores** na Universidade Federal Rural do Rio de Janeiro (UFRRJ).

## ✨ Features da Linguagem

| Categoria | Recursos |
|-----------|----------|
| **Tipos** | `int`, `float`, `char`, `bool`, `string`, `array` (tipagem dinâmica) |
| **Operadores** | `+` `-` `*` `/` `**` (exponenciação) `!!` (fatorial) |
| **Compostos** | `+=` `-=` `*=` `/=` `++` `--` (pré e pós) |
| **Relacionais** | `>` `<` `>=` `<=` `==` `!=` |
| **Lógicos** | `and` `or` `not` (com curto-circuito) |
| **Controle** | `if` / `elif` / `else`, `while`, `do-while`, `for..in..to`, `for each`, `switch` / `case` / `default` |
| **Fluxo** | `break`, `continue`, `break all` (sai de todos os loops) |
| **Funções** | `def`, `return`, recursão, chamada fora de ordem |
| **Escopo** | Blocos por indentação, `global`, `local`, blocos anônimos `{}` |
| **I/O** | `print()`, `input()` (detecta tipo automaticamente) |
| **Cast** | `int()`, `float()`, `str()`, `bool()`, `char()` |
| **Arrays** | Literais `[1, 2, 3]`, acesso `a[0]`, matrizes `a[0][1]` |

## 🚀 Exemplos

### Hello World
```python
print("Hello, World!")
```

### Variáveis e Operações
```python
nome = "Gary"
x = 10
y = 3.14
ativo = true

print(nome)
print(x + int(y))
print(5!! + 2 ** 3)
```

### Controle de Fluxo
```python
nota = 85

if nota >= 90:
    print("A")
elif nota >= 80:
    print("B")
elif nota >= 70:
    print("C")
else:
    print("F")
```

### Loops
```python
for i in 1 to 5:
    print(i)

x = 10
while x > 0:
    print(x)
    x -= 1

do:
    nome = input()
    print(nome)
while nome != "sair"
```

### For Each e Arrays
```python
frutas = ["maca", "banana", "uva"]

for fruta in frutas:
    print(fruta)

notas = [10, 8, 7, 9]
notas[2] = 10
print(notas[2])
```

### Funções
```python
def fatorial(n):
    if n <= 1:
        return 1
    return n * fatorial(n - 1)

print(fatorial(5))

def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

print(fibonacci(10))
```

### Switch
```python
dia = 3

switch dia:
    case 1:
        print("Segunda")
    case 2:
        print("Terca")
    case 3:
        print("Quarta")
    default:
        print("Outro dia")
```

### Break All (sai de todos os loops aninhados)
```python
for i in 0 to 9:
    for j in 0 to 9:
        if i == 3 and j == 5:
            break all
        print(i * 10 + j)
```

## 🏗️ Arquitetura

```
                    ┌─────────────┐
  Código Gary       │   lexico.l  │      Flex gera o scanner que
  (.gary)  ───────► │   (Flex)    │      tokeniza o código fonte,
                    └──────┬──────┘      incluindo controle de
                           │             indentação (INDENT/DEDENT)
                           ▼
                    ┌──────────────┐
                    │ sintatico.y  │      Bison gera o parser que
                    │   (Bison)    │      constrói a tradução dirigida
                    └──────┬───────┘      pela sintaxe (TDS)
                           │
                           ▼
                    ┌──────────────┐
                    │   Código C   │      Código de 3 endereços com
                    │ (3 endereços)│      runtime embutido (tagged
                    └──────┬───────┘      union para tipagem dinâmica)
                           │
                           ▼
                    ┌──────────────┐
                    │     GCC      │      Compila o C gerado em
                    │              │      executável nativo
                    └──────┬───────┘
                           │
                           ▼
                      Executável
```

### Sistema de Tipos em Runtime

O compilador gera código C que usa uma `struct Var` (tagged union) para representar todos os tipos dinamicamente:

```c
typedef enum { TIPO_INT, TIPO_FLOAT, TIPO_CHAR, TIPO_BOOL, TIPO_STRING, TIPO_ARRAY } TipoVar;

typedef struct Var_struct {
    TipoVar tipo;
    union {
        int v_int;
        float v_float;
        char v_char;
        int v_bool;
        char* v_string;
        struct { int tamanho; struct Var_struct* elementos; } v_array;
    } valor;
} Var;
```

Todas as operações (soma, comparação, cast, etc.) são funções C que verificam os tipos dos operandos em tempo de execução e realizam a operação correta ou emitem um erro com o número da linha.

## 📦 Pré-requisitos

- **Flex** — gerador de analisador léxico
- **Bison** — gerador de analisador sintático
- **g++** — compilador C++
- **gcc** — compilador C (para compilar o código gerado)
- **make**

```bash
# Debian/Ubuntu/Kali
sudo apt install flex bison g++ gcc make
```

## 🔧 Como Usar

### Compilar o compilador Gary
```bash
make
```

### Ver o código C gerado
```bash
./glf < programa.gary
```

### Compilar e executar diretamente
```bash
make run programa.gary
```

### Compilar e gerar executável
```bash
make build programa.gary
```

### Limpar arquivos gerados
```bash
make clean
```

## 📂 Estrutura do Projeto

```
Gary/
├── src/
│   ├── lexico.l          # Analisador Léxico (Flex)
│   └── sintatico.y       # Analisador Sintático + Semântico + Geração de Código (Bison)
├── Makefile              # Sistema de build
├── LICENSE               # MIT License
└── README.md
```

## 🧪 Gramática (Simplificada)

```
PROGRAMA        → LISTA_COMANDOS
LISTA_COMANDOS  → LISTA_COMANDOS CMD | ε
BLOCO           → NEWLINE INDENT LISTA_COMANDOS DEDENT

CMD → ID '=' E NEWLINE                          // Atribuição
    | ID ('+=' | '-=' | '*=' | '/=') E NEWLINE  // Operadores compostos
    | PRINT '(' E ')' NEWLINE                   // Saída
    | IF E ':' BLOCO BLOCOS_ALT                 // Condicional
    | WHILE E ':' BLOCO                         // While
    | DO ':' BLOCO WHILE E NEWLINE              // Do-While
    | FOR ID IN E TO E ':' BLOCO                // For range
    | FOR ID IN E ':' BLOCO                     // For each
    | SWITCH E ':' BLOCO_CASOS                  // Switch
    | DEF ID '(' PARAMS ')' ':' BLOCO           // Função
    | RETURN E NEWLINE                          // Retorno
    | BREAK | CONTINUE | BREAK ALL              // Controle de fluxo

E   → E ('+' | '-' | '*' | '/' | '**') E       // Aritméticos
    | E ('>' | '<' | '>=' | '<=' | '==' | '!=') E  // Relacionais
    | E ('and' | 'or') E | 'not' E             // Lógicos
    | E '!!'                                    // Fatorial
    | E '[' E ']'                               // Acesso a array
    | ID '(' ARGS ')'                           // Chamada de função
    | ('++' | '--') ID | ID ('++' | '--')       // Inc/Dec
    | INT | FLOAT | CHAR | STRING | BOOL | ID   // Literais
    | '[' LISTA_VALORES ']'                     // Array literal
    | ('int' | 'float' | 'str' | 'bool' | 'char') '(' E ')'  // Cast
    | INPUT '(' ')'                             // Entrada
    | '(' E ')'                                 // Agrupamento
```

## 👥 Autores

- **Gabriel Picciani** — [@despicciani](https://github.com/despicciani)
- **Ryan Armond** - [@RyanArmond](https://github.com/RyanArmond)

## 📄 Licença

Este projeto está licenciado sob a [MIT License](LICENSE).

---

<div align="center">
<sub>Meow.</sub>
</div>
