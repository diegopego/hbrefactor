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

.PHONY: build test ppcorpus clean hooks

build: hooks $(BIN)

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
test: build bin/tcheck bin/parrun
	@HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) JOBS="$(JOBS)" tests/run.sh

# suite EXPLORATORIA do PP (P-DOC): o corpus de diretivas REAIS do Harbour
# (docs/pp-corpus.md) casado com os quatro oraculos (.ppo/.ppt/ast dump/codigo
# compilavel). SEPARADA do contrato de proposito - e exploratoria e o core sera
# modificado durante a exploracao. Nao entra no `make test`.
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
lexdiff: bin/lexdiff
	@tests/lexdiff.sh $(HB_BIN)

bin/lexdiff: tests/lexdiff.prg
	@mkdir -p bin
	$(HBMK2) tests/lexdiff.prg -obin/lexdiff -q0 -w3 -es2 -gtcgi

clean:
	rm -rf bin
