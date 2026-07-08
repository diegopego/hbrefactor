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

.PHONY: build test clean

build: $(BIN)

$(BIN): src/hbrefactor.prg
	@mkdir -p bin
	$(HBMK2) src/hbrefactor.prg -o$(BIN) -q0 -w3 -es2 -gtcgi

# paralelo por padrão (pool por-caso, teto nproc - B-infra Etapa 1);
# JOBS=1 força o modo sequencial com saída ao vivo, para depurar um caso
test: build
	@HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) JOBS="$(JOBS)" tests/run.sh

# porta de precisão da B1: dump ast vs TokenScan arquivado, corpus
# fixtures + hbhttpd (0 divergências reais exigidas)
lexdiff: bin/lexdiff
	@tests/lexdiff.sh $(HB_BIN)

bin/lexdiff: tests/lexdiff.prg
	@mkdir -p bin
	$(HBMK2) tests/lexdiff.prg -obin/lexdiff -q0 -w3 -es2 -gtcgi

clean:
	rm -rf bin
