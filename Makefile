# hbrefactor - build and test
#
# HB_BIN: directory with the harbour/hbmk2 binaries (needs the -x patch
#         from harbour-core branch feature/refactoring-mechanism)

HB_BIN ?= $(HOME)/devel/harbour-core/harbour/bin/linux/gcc
HBMK2  := $(HB_BIN)/hbmk2
BIN    := bin/hbrefactor

.PHONY: build test clean

build: $(BIN)

$(BIN): src/hbrefactor.prg
	@mkdir -p bin
	$(HBMK2) src/hbrefactor.prg -o$(BIN) -q0 -w3 -es2 -gtcgi

test: build
	@HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) tests/run.sh

clean:
	rm -rf bin
