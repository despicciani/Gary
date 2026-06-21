SHELL := /bin/bash
DIR := src
SCANNER := flex
SCANNER_PARAMS := $(DIR)/lexico.l
PARSER := bison
PARSER_PARAMS := -d --yacc $(DIR)/sintatico.y
CXXFLAGS := -Wno-free-nonheap-object

ifeq (run,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
  $(eval .PHONY: $(RUN_ARGS))
endif

ifeq (build,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
  $(eval .PHONY: $(RUN_ARGS))
endif

ifneq ($(RUN_ARGS),)
  FILE := $(RUN_ARGS)
else
  FILE ?= main.gary
endif

all: glf

compile: glf

runtime_str.h: $(DIR)/runtime.c
		@echo 'string runtime_c = R"RUNTIME(' > runtime_str.h
		@cat $(DIR)/runtime.c >> runtime_str.h
		@echo ')RUNTIME";' >> runtime_str.h

glf: y.tab.c lex.yy.c runtime_str.h
		g++ $(CXXFLAGS) -o glf y.tab.c

lex.yy.c: $(DIR)/lexico.l
		$(SCANNER) $(SCANNER_PARAMS)

y.tab.c y.tab.h: $(DIR)/sintatico.y
		$(PARSER) $(PARSER_PARAMS)

translate: glf
		./glf < $(FILE)

run: glf
		@./glf < $(FILE) > /tmp/gary_output.c
		@gcc /tmp/gary_output.c -o /tmp/gary_output
		@/tmp/gary_output

build: glf
		@./glf < $(FILE) > /tmp/gary_output.c
		@gcc /tmp/gary_output.c -o $$(basename $(FILE) .gary)

clean:
		rm -f y.tab.c y.tab.h lex.yy.c runtime_str.h glf /tmp/gary_output.c /tmp/gary_output
