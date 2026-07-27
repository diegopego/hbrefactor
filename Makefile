# hbrefactor - build and test
#
# HB_BIN: directory with the harbour/hbmk2 binaries carrying the AST dump
#         switch (-x) from harbour-core branch feature/compiler-ast-dump
#
# The tool is being rewritten on top of the compiler AST (.ast.json,
# schema ast-1) - see docs/roadmap.md (v3). The first incarnation lives in
# smoketest/hbrefactor-occ.prg as reference; tests/ keeps the behaviour
# contract the new tool must honour case by case.

# HB_BIN vem da FONTE ÚNICA (tools/hbenv.sh), a mesma que os scripts leem -
# um lugar só decide onde está o harbour-core. Override sempre vence:
#   make test HB_BIN=/outro/caminho/bin/linux/gcc
HB_BIN ?= $(shell sh tools/hbenv.sh --print HB_BIN)
# o Go dos testes: instalado por `make deps` em ~/.local/go (do site oficial)
GO     ?= $(shell command -v go 2>/dev/null || echo $(HOME)/.local/go/bin/go)
HBMK2  := $(HB_BIN)/hbmk2
BIN    := bin/hbrefactor

# `make` sem argumento mostra o help (convenção comum) - nunca dispara um build
# por engano. `make build` continua compilando.
.DEFAULT_GOAL := help

.PHONY: build test scenarios caso gotest govet oracle ppcorpus lexdiff clean hooks site-serve site-check site-examples tmp-usage setup-env deps help

# RC: os shell rc onde o setup-env escreve. Default: os DOIS (bash + zsh) - o
# bloco é idempotente, então escrever nos dois é inócuo. Override p/ um só:
#   make setup-env RC=~/.bashrc
RC ?= $(HOME)/.bashrc $(HOME)/.zshrc

## build       compila a ferramenta em bin/hbrefactor
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
	@HB_BIN=$(HB_BIN) HBREFACTOR_HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) JOBS="$(JOBS)" tests/run.sh
	@$(MAKE) --no-print-directory scenarios
	@$(MAKE) --no-print-directory govet
	@$(MAKE) --no-print-directory gotest

# RETRATO do core: grava os .ppo/.ppt de cada caso, nos DOIS formatos que ainda
# convivem (os cenários bash que faltam migrar, e a suíte Go). É o UNICO
# esperado que se grava em vez de escrever - e só porque ali a autoridade e' o
# core, nao nos. Rodar isto e' ato DELIBERADO: o diff dos retratos entra na
# revisao do commit que mexeu no core.
## oracle      regrava os retratos .ppo/.ppt de cada caso (NOME=x para um só)
oracle: build bin/tcheck
	@HB_BIN=$(HB_BIN) HBREFACTOR_HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) tests/scenarios.sh --oracle $(NOME)
	@cd tests-go && HB_BIN=$(HB_BIN) $(GO) test ./suite -update -count=1 -v \
	   -run 'TestCasos/$(if $(NOME),$(NOME),.*)/fixture/retrato'

# A SUÍTE DA CLASSE A (transformação), em Go (Diego, 2026-07-26) — o formato
# para onde TODOS os testes migram. Um caso é uma pasta em
# tests-go/suite/testdata/<nome>/ (source/ + expected/ + outputs.json + oracle/)
# mais um <nome>_test.go que se registra e afirma o que é dele. O contrato do
# formato está em tests/README.md; o runner bash e o tests/scenarios/ seguem só
# com o que ainda não migrou.
#   make deps                 instala o Go e o resto
#   make gotest               a suíte inteira
#   make caso NOME=x          UM caso, com as provas da fixture dele
## gotest      roda a suíte da classe A (Go; o formato para onde tudo migra)
gotest: build
	@command -v $(GO) > /dev/null 2>&1 || { echo "sem Go - rode 'make deps'"; exit 1; }
	@cd tests-go && HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) \
	   $(GO) test ./... -count=1 $(if $(VERBOSE),-v,)

# UM caso e TUDO sobre ele: a transformação e as três provas da fixture
# (compila, vocabulário, retrato). É o comando do loop de migração - segundos,
# em vez do `make test` inteiro.
# SEM PIPE, e isto não é estilo: o exit de um pipeline é o do ÚLTIMO comando, e
# um `| grep` no fim engole a falha do `go test`. Medido em 2026-07-26 - este
# alvo saía 0 com o caso deliberadamente quebrado, dando verde vacuoso no
# comando que mais se roda.
## caso        roda UM caso e as provas da fixture dele (make caso NOME=x)
caso: build
	@test -n "$(NOME)" || { echo "uso: make caso NOME=<pasta em tests-go/suite/testdata>"; exit 1; }
	@cd tests-go && HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) \
	   $(GO) test ./suite -count=1 -v -run 'TestCasos/$(NOME)'

## govet       gofmt + go vet dos testes (o compilador já é o portão de tipos)
govet:
	@cd tests-go && test -z "$$($(GO) fmt ./...)" || { echo "gofmt reformatou arquivos"; exit 1; }
	@cd tests-go && $(GO) vet ./...

## scenarios   roda só os testes no formato NOVO (make scenarios NOME=x roda um)
scenarios: build bin/tcheck
	@HB_BIN=$(HB_BIN) HBREFACTOR_HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) tests/scenarios.sh $(NOME)

# suite EXPLORATORIA do PP (P-DOC): o corpus de diretivas REAIS do Harbour
# (docs/pp-corpus.md) casado com os quatro oraculos (.ppo/.ppt/ast dump/codigo
# compilavel). SEPARADA do contrato de proposito - e exploratoria e o core sera
# modificado durante a exploracao. Nao entra no `make test`.
## ppcorpus    suíte EXPLORATÓRIA do pp (fora do contrato; não entra no test)
ppcorpus: build
	@HB_BIN=$(HB_BIN) HBREFACTOR_HB_BIN=$(HB_BIN) tests/ppcorpus.sh

bin/tcheck: tests/tcheck.prg
	@mkdir -p bin
	$(HBMK2) tests/tcheck.prg -obin/tcheck -q0 -w3 -es2 -gtcgi

bin/parrun: tests/parrun.prg
	@mkdir -p bin
	$(HBMK2) tests/parrun.prg -obin/parrun -q0 -w3 -es2 -gtcgi

# porta de precisão da B1: dump ast vs TokenScan arquivado, corpus
# fixtures + hbhttpd (0 divergências reais exigidas)
## site-check   falha se algum exemplo das páginas estiver defasado
site-check: $(BIN)
	@HB_BIN=$(HB_BIN) HBREFACTOR_HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) tools/site-examples.sh --check

## site-examples  RE-EXECUTA todo exemplo da página e regrava os blocos (nada é digitado)
site-examples: tools/site-examples.sh $(BIN)
	@HB_BIN=$(HB_BIN) HBREFACTOR_HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) tools/site-examples.sh

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

## tmp-usage   AVISA se os temporários passaram do limite (nunca apaga; HBREFACTOR_TMP_WARN_MB=500)
tmp-usage: tools/tmp-usage.sh
	@tools/tmp-usage.sh

## deps        instala as dependências EXTERNAS dos testes (node); --check só relata
deps: tools/deps.sh
	@tools/deps.sh

## setup-env   adiciona o export HBREFACTOR_HB_BIN aos shell rc (idempotente; RC=~/.bashrc p/ um só)
setup-env: tools/setup-env.sh tools/hbenv.sh
	@for rc in $(RC); do sh tools/setup-env.sh "$$rc" "$(abspath tools/hbenv.sh)"; done

## clean       remove bin/
clean:
	rm -rf bin
