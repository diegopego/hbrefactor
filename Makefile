# hbrefactor - build and test
#
# HB_BIN: directory with the harbour/hbmk2 binaries carrying the AST dump
#         switch (-x) from harbour-core branch feature/compiler-ast-dump
#
# The tool is being rewritten on top of the compiler AST (.ast.json,
# schema ast-1) - see docs/roadmap.md (v3). The first incarnation lives in
# smoketest/hbrefactor-occ.prg as reference; tests/ keeps the behaviour
# contract the new tool must honour case by case.

HB_BIN ?= $(HOME)/devel/harbour-core/harbour/bin/linux/gcc
HBMK2  := $(HB_BIN)/hbmk2
BIN    := bin/hbrefactor

.PHONY: build test ppcorpus lexdiff clean hooks site-serve site-numbers site-check help

## build       compila a ferramenta em bin/hbrefactor (alvo padrão)
build: hooks $(BIN)

# a lista sai dos comentários `## <alvo> <descrição>` dos próprios alvos:
# uma fonte de verdade só, senão a ajuda envelhece caladinha
help:
	@echo "hbrefactor - alvos disponíveis:"
	@echo
	@grep -hE '^## ' $(MAKEFILE_LIST) | sed 's/^## /  make /'
	@echo
	@echo "variáveis:  HB_BIN=$(HB_BIN)"
	@echo "            JOBS=1 (test sequencial)  SITE=  PORT= (site-serve)"

# ativa o pre-commit anti-binário (.githooks/pre-commit) sem exigir alvo
# próprio: todo `make`/`make test` garante o core.hooksPath. Idempotente e
# silencioso quando já está ligado; no-op fora de um clone git (tarball).
hooks:
	@if [ -d .git ] && [ "$$(git config --get core.hooksPath)" != ".githooks" ]; then \
		git config core.hooksPath .githooks && \
		echo "hooks: pre-commit anti-binário ativado (core.hooksPath=.githooks)"; \
	fi

$(BIN): src/hbrefactor.prg
	@mkdir -p bin
	$(HBMK2) src/hbrefactor.prg -o$(BIN) -q0 -w3 -es2 -gtcgi

# paralelo por padrão (pool por-caso, teto nproc - B-infra; Etapa 2:
# despacho+join em Harbour via bin/parrun, asserts de JSON via bin/tcheck);
# JOBS=1 força o modo sequencial com saída ao vivo, para depurar um caso
## test        roda a suíte (contrato executável; JOBS=1 força sequencial)
test: build bin/tcheck bin/parrun
	@HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) JOBS="$(JOBS)" tests/run.sh

# suite EXPLORATORIA do PP (P-DOC): o corpus de diretivas REAIS do Harbour
# (docs/pp-corpus.md) casado com os quatro oraculos (.ppo/.ppt/ast dump/codigo
# compilavel). SEPARADA do contrato de proposito - e exploratoria e o core sera
# modificado durante a exploracao. Nao entra no `make test`.
## ppcorpus    suíte EXPLORATÓRIA do pp (fora do contrato; não entra no test)
ppcorpus: build
	@HB_BIN=$(HB_BIN) tests/ppcorpus.sh

bin/tcheck: tests/tcheck.prg
	@mkdir -p bin
	$(HBMK2) tests/tcheck.prg -obin/tcheck -q0 -w3 -es2 -gtcgi

bin/parrun: tests/parrun.prg
	@mkdir -p bin
	$(HBMK2) tests/parrun.prg -obin/parrun -q0 -w3 -es2 -gtcgi

# porta de precisão da B1: dump ast vs TokenScan arquivado, corpus
# fixtures + hbhttpd (0 divergências reais exigidas)
## site-numbers  remede TODO indicador das páginas (nenhum número é digitado)
site-numbers: tools/site-numbers.sh
	@tools/site-numbers.sh

## site-check   falha se algum indicador das páginas estiver defasado
site-check: tools/site-numbers.sh
	@tools/site-numbers.sh --check

## lexdiff     porta de precisão: dump ast vs TokenScan arquivado
lexdiff: bin/lexdiff
	@tests/lexdiff.sh $(HB_BIN)

bin/lexdiff: tests/lexdiff.prg
	@mkdir -p bin
	$(HBMK2) tests/lexdiff.prg -obin/lexdiff -q0 -w3 -es2 -gtcgi

# pré-visualiza a landing page como o GitHub Pages a serve (raiz = site/,
# `/` resolve para index.html), antes do push. SITE= aponta para outra pasta -
# a proposta aos mantenedores mora no core:
#   make site-serve SITE=$(HOME)/devel/harbour-core/harbour/site PORT=8001
# Ctrl+C encerra. Lembrete: o nome do arquivo nunca muda, então o navegador
# cacheia - recarregar com Ctrl+Shift+R depois de editar.
SITE ?= site
PORT ?= 8000

## site-serve  pré-visualiza a landing page como o GitHub Pages a serve
site-serve:
	@echo "site: http://localhost:$(PORT)/  (servindo $(SITE), Ctrl+C encerra)"
	@python3 -m http.server $(PORT) --directory $(SITE)

## clean       remove bin/
clean:
	rm -rf bin
