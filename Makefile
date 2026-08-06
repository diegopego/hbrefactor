# hbrefactor - build and test
#
# HB_BIN: directory with the harbour/hbmk2 binaries carrying the AST dump
#         switch (-x) from harbour-core branch feature/compiler-ast-dump
#
# The tool is being rewritten on top of the compiler AST (.ast.json,
# schema ast-1) - see docs/roadmap.md (v3). The first incarnation lives in
# smoketest/hbrefactor-occ.prg as reference; tests/ keeps the behaviour
# contract the new tool must honour case by case.

# SÃO DOIS TOOLCHAINS, e os dois vêm da FONTE ÚNICA (tools/hbenv.sh), que
# documenta o papel de cada um:
#   HB_BIN    o do BRANCH - compila, analisa e verifica. TODO o trabalho.
#   STOCK_BIN o de upstream/master - NÃO trabalha; existe para ser COMPARADO.
# Override sempre vence:  make test HB_BIN=/outro/caminho/bin/linux/gcc
HB_BIN ?= $(shell sh tools/hbenv.sh --print HB_BIN)
# o Go dos testes: instalado por `make deps` em ~/.local/go (do site oficial)
GO     ?= $(shell command -v go 2>/dev/null || echo $(HOME)/.local/go/bin/go)
HBMK2  := $(HB_BIN)/hbmk2
BIN    := bin/hbrefactor

# o core, para o alvo `core`. Tudo derivado da MESMA fonte única - <plat>/<comp>
# saem do próprio HB_BIN (.../bin/linux/gcc), nunca de um chute.
HB_CORE   ?= $(shell sh tools/hbenv.sh --print HB_CORE)
CORE_COMP  = $(notdir $(HB_BIN))
CORE_PLAT  = $(notdir $(patsubst %/,%,$(dir $(HB_BIN))))
CORE_SRC   = $(HB_CORE)/src/compiler
CORE_OBJ   = $(CORE_SRC)/obj/$(CORE_PLAT)/$(CORE_COMP)
CORE_Y     = $(CORE_SRC)/harbour.y
CORE_YYC   = $(CORE_SRC)/harbour.yyc
CORE_BINS  = $(HB_BIN)/harbour $(HB_BIN)/hbmk2

# O STOCK: o harbour de upstream/master, SEM os remendos do branch. Ele e'
# dependencia do projeto tanto quanto o do branch (Diego, 2026-08-06) - e' a
# BASE da unica prova que a proposta aos mantenedores faz: com os switches
# desligados, o compilador remendado gera pcode identico ao do Harbour de
# fabrica. Worktree em vez de clone: compartilha os objetos e garante que a
# base e' exatamente aquela contra a qual o diff e' medido.
HB_STOCK   ?= $(shell sh tools/hbenv.sh --print HB_STOCK)
STOCK_BIN   = $(shell sh tools/hbenv.sh --print HB_STOCK_BIN)/harbour
# o schema que o FONTE declara agora - é contra ele que os binários são conferidos
CORE_SCHEMA = $(shell sed -n 's/^\#define HB_AST_SCHEMA  *"\(ast-[0-9]*\)".*/\1/p' $(CORE_SRC)/compast.c)

# `make` sem argumento mostra o help (convenção comum) - nunca dispara um build
# por engano. `make build` continua compilando.
.DEFAULT_GOAL := help

.PHONY: build core core-check stock stock-check pcode-identity test caso gotest govet oracle ppcorpus lexdiff clean hooks site-serve site-check site-examples tmp-usage setup-env deps help

# RC: os shell rc onde o setup-env escreve. Default: os DOIS (bash + zsh) - o
# bloco é idempotente, então escrever nos dois é inócuo. Override p/ um só:
#   make setup-env RC=~/.bashrc
RC ?= $(HOME)/.bashrc $(HOME)/.zshrc

## build       compila a ferramenta em bin/hbrefactor
build: hooks $(BIN)

## core        rebuilda o harbour-core LIMPO (harbour + hbmk2) - o unico jeito
# BUILD INCREMENTAL DO CORE NAO SE USA (Diego, 2026-08-06): o make dele nao
# rastreia `#include`, entao editar um header sai exit 0 SEM RECOMPILAR NADA e a
# medicao seguinte responde do binario VELHO. Vale para os dois: o hbmk2 EMBUTE o
# compilador. CLAUDE.md §2, cicatrizes §5.1.
core: $(CORE_YYC)
	@echo "core: $(HB_CORE)  ($(CORE_PLAT)/$(CORE_COMP))  branch: $$(git -C $(HB_CORE) rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
	@[ "$$(git -C $(HB_CORE) rev-parse --abbrev-ref HEAD 2>/dev/null)" = feature/compiler-ast-dump ] || \
		echo "core: AVISO - o branch esperado e' feature/compiler-ast-dump"
	@# os binarios somem ANTES: sem isso o make relata "up to date" e nao relinca
	rm -f $(CORE_BINS)
	cd $(HB_CORE) && $(MAKE) clean >/dev/null && $(MAKE) -j$(if $(JOBS),$(JOBS),8)
	@$(MAKE) --no-print-directory core-check

# o parser COMMITADO e' o que um checkout limpo usa; HB_REBUILD_PARSER=yes
# regenera so' o artefato de build (obj/**/harboury.c) e deixa os .yyc/.yyh para
# tras. Aqui e' dependencia de verdade - e e' disto que o make e' feito.
# Gerado de dentro do obj/ com o caminho relativo que o make do core usaria, para
# que os `#line` batam byte a byte com um build HB_REBUILD_PARSER=yes.
$(CORE_YYC): $(CORE_Y)
	@command -v bison >/dev/null || { echo "core: harbour.y mudou e nao ha bison no PATH" >&2; exit 1; }
	@echo "core: harbour.y > harbour.yyc - regenerando ($$(bison --version | head -1))"
	@mkdir -p $(CORE_OBJ)
	cd $(CORE_OBJ) && bison -d -oharboury.c ../../../harbour.y
	cp $(CORE_OBJ)/harboury.c $(CORE_YYC)
	cp $(CORE_OBJ)/harboury.h $(CORE_SRC)/harbour.yyh
	@echo "core: COMMITE OS TRES JUNTOS (.y + .yyc + .yyh)"

## core-check  confere que harbour+hbmk2 estao em passo com o fonte (sem rebuildar)
# Alvo proprio porque a conferencia vale sozinha - responde em 1s "o binario que
# estou medindo e' o do fonte de agora?", que e' a pergunta cujo NAO responder
# custou dois diagnosticos errados. E' tambem o que torna a guarda TESTAVEL: os
# tres controles negativos (binario velho, ausente, schema fora de passo) se
# rodam contra ele, nao contra um rebuild de minutos.
core-check:
	$(call core-check-one,$(HB_BIN)/harbour)
	$(call core-check-one,$(HB_BIN)/hbmk2)
	@echo "core: ok - $$($(HB_BIN)/harbour -build 2>&1 | head -1)  [$(CORE_SCHEMA)]"

## stock       builda o harbour STOCK (upstream/master) - a base da prova de pcode
# Forca o rebuild. Para so' provisionar quando faltar, use `make pcode-identity`,
# que tem o binario como dependencia.
stock:
	rm -f $(STOCK_BIN)
	@$(MAKE) --no-print-directory $(STOCK_BIN)

# provisiona e builda. Mesma regra do core: build LIMPO, e conferido.
$(STOCK_BIN):
	@# a base do diff so' e' um fato depois do fetch (CLAUDE.md §4)
	cd $(HB_CORE) && git fetch upstream
	@if [ -d $(HB_STOCK) ]; then 		echo "stock: atualizando o worktree para upstream/master"; 		git -C $(HB_STOCK) checkout --detach upstream/master; 	else 		echo "stock: criando o worktree em $(HB_STOCK)"; 		git -C $(HB_CORE) worktree add --detach $(HB_STOCK) upstream/master; 	fi
	cd $(HB_STOCK) && $(MAKE) clean >/dev/null 2>&1 || true
	cd $(HB_STOCK) && $(MAKE) -j$(if $(JOBS),$(JOBS),8)
	@$(MAKE) --no-print-directory stock-check

## stock-check confere que o harbour stock existe e NAO carrega o dump
# O controle que importa: um "stock" que carregue `ast-N` nao e' stock - o
# worktree escorregou para o branch, e a prova de impacto zero viraria uma
# comparacao do binario com ele mesmo, passando verde e provando NADA.
stock-check:
	@[ -x $(STOCK_BIN) ] || { echo "stock: FALHOU - $(STOCK_BIN) nao existe; rode make stock" >&2; exit 1; }
	@! strings $(STOCK_BIN) | grep -qE '^ast-[0-9]+$$' || 		{ echo "stock: FALHOU - o binario carrega o dump; isto NAO e' o stock" >&2; exit 1; }
	@echo "stock: ok - $$($(STOCK_BIN) -build 2>&1 | head -1)  (upstream/master $$(git -C $(HB_STOCK) rev-parse --short HEAD))"

## pcode-identity  prova: sem os switches, o pcode e' IDENTICO ao do stock
# A afirmacao mais importante da proposta aos mantenedores - um mantenedor que
# desconfie dela nao le o resto. Era medida a mao, e por isso nunca era remedida.
# Depende dos DOIS toolchains: o stock e' construido se faltar, e o do branch e'
# conferido (nao rebuildado - `make core` e' quem faz isso).
pcode-identity: $(STOCK_BIN)
	@$(MAKE) --no-print-directory stock-check
	@$(MAKE) --no-print-directory core-check
	bash tools/pcode-identity.sh $(STOCK_BIN) $(HB_BIN)/harbour

# as conferencias de UM binario. Build que "passou" sem produzir binario novo e'
# exatamente o modo de falha que este alvo existe para matar, entao ele e'
# VERIFICADO, nao presumido. As tres tem controle negativo rodado.
define core-check-one
	@[ -x $(1) ] || { echo "core: FALHOU - $(1) nao existe apos o build" >&2; exit 1; }
	@[ ! $(1) -ot $(CORE_Y) ] || { echo "core: FALHOU - $(1) e' mais VELHO que o fonte; nao relincou" >&2; exit 1; }
	@# o CONJUNTO de versoes dentro do binario tem de ser exatamente {SCHEMA}:
	@# sobrou outra = objeto velho linkado junto. Extrai os tokens em vez de casar
	@# a linha - no hbmk2 a string mora colada a outras, e um `grep -x` responderia
	@# "nao tem" sobre um binario correto (medido).
	@got=$$(strings $(1) | grep -oE 'ast-[0-9]+' | sort -u | tr '\n' ' '); \
	 [ "$$got" = "$(CORE_SCHEMA) " ] || \
	   { echo "core: FALHOU - $(1) carrega [$${got% }], o fonte declara '$(CORE_SCHEMA)'" >&2; exit 1; }
endef

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
#
# O `lexdiff` e o `site-check` entraram AQUI em 2026-07-27, e a razão é uma
# cicatriz: ao remover um comportamento, enumerei os testes afetados rodando
# `make test` e reportei três - faltava um QUARTO, o exemplo `09-string-guard`
# da landing page, que anunciava ao leitor uma proteção que acabara de deixar de
# existir. Ele só apareceu por acaso, dias depois no mesmo dia, porque fui mexer
# na documentação. A lei diz "contrato executável: make test" (CLAUDE.md §3), e
# o contrato não cobria o portão das afirmações que o USUÁRIO lê. Custo de trazer
# para dentro: 13,7s + 0,02s, medido - não havia razão para estarem fora.
# (O `ppcorpus` continua fora, e de propósito: é exploratório.)
## test        roda a suíte (contrato executável; JOBS=1 força sequencial)
test: build bin/tcheck bin/parrun
	@HB_BIN=$(HB_BIN) HBREFACTOR_HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) JOBS="$(JOBS)" tests/run.sh
	@$(MAKE) --no-print-directory govet
	# ANTES do gotest, e de propósito: a cadeia para no primeiro erro, e um
	# vermelho de TDD longevo na suíte Go deixaria estes dois sem rodar - que é
	# como o portão da página ficou mudo justamente na fase que o quebrou
	@$(MAKE) --no-print-directory lexdiff
	@$(MAKE) --no-print-directory site-check
	@$(MAKE) --no-print-directory gotest

# RETRATO do core: grava os .ppo/.ppt de cada caso. É o UNICO esperado que se
# grava em vez de escrever - e só porque ali a autoridade e' o core, nao nos.
# Rodar isto e' ato DELIBERADO: o diff dos retratos entra na revisao do commit
# que mexeu no core.
## oracle      regrava os retratos .ppo/.ppt de cada caso (NOME=x para um só)
oracle: build
	@cd tests-go && HB_BIN=$(HB_BIN) $(GO) test ./suite -update -count=1 -v \
	   -run 'TestCasos/$(if $(NOME),$(NOME),.*)/fixture/retrato'

# A SUÍTE DA CLASSE A (transformação), em Go (Diego, 2026-07-26) — o formato
# para onde TODOS os testes migram. Um caso é uma pasta em
# tests-go/suite/testdata/<nome>/ (source/ + expected/ + outputs.json + oracle/)
# mais um <nome>_test.go que se registra e afirma o que é dele. O contrato do
# formato está em tests/README.md; o tests/run.sh segue só com o que ainda não
# migrou.
#   make deps                 instala o Go e o resto
#   make gotest               a suíte inteira
#   make caso NOME=x          UM caso, com as provas da fixture dele
# JOBS=1 tem de alcançar a suíte Go também: o contrato "paralelo x JOBS=1
# byte-idêntico" é da INFRA (CLAUDE.md §3), e ele valia só metade da suíte -
# o run.sh recebia JOBS e o `go test` seguia paralelo, enquanto o help anunciava
# "test sequencial". `-p 1` serializa os pacotes, `-parallel 1` os t.Parallel()
GOSEQ = $(if $(filter 1,$(JOBS)),-p 1 -parallel 1,)

## gotest      roda a suíte da classe A (Go; o formato para onde tudo migra)
gotest: build
	@command -v $(GO) > /dev/null 2>&1 || { echo "sem Go - rode 'make deps'"; exit 1; }
	@cd tests-go && HB_BIN=$(HB_BIN) BIN=$(abspath $(BIN)) \
	   $(GO) test ./... -count=1 $(GOSEQ) $(if $(VERBOSE),-v,)

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

# `gofmt -l` LISTA; `go fmt` REESCREVE. A versão anterior usava `go fmt` e tinha
# os dois defeitos de um portão que edita: mexia na árvore do usuário como efeito
# colateral de uma CONFERÊNCIA, e SE DESARMAVA - a 1a rodada falhava já com os
# arquivos reformatados, a 2a passava. Medido em 2026-07-27: exit 2 depois exit 0,
# sem ninguém consertar nada. Portão que se desarma sozinho é pior que portão
# nenhum, porque dá a sensação de ter passado.
GOFMT ?= $(dir $(GO))gofmt

## govet       gofmt + go vet dos testes (o compilador já é o portão de tipos)
govet:
	@command -v $(GO) > /dev/null 2>&1 || { echo "sem Go - rode 'make deps'"; exit 1; }
	@cd tests-go && out=$$($(GOFMT) -l .) && test -z "$$out" || { \
	   echo "gofmt: arquivo(s) fora do formato (rode: $(GOFMT) -w tests-go)"; \
	   echo "$$out"; exit 1; }
	@cd tests-go && $(GO) vet ./...

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

## deps        instala as dependências EXTERNAS (node, go, bison); --check só relata
deps: tools/deps.sh
	@tools/deps.sh

## setup-env   adiciona o export HBREFACTOR_HB_BIN aos shell rc (idempotente; RC=~/.bashrc p/ um só)
setup-env: tools/setup-env.sh tools/hbenv.sh
	@for rc in $(RC); do sh tools/setup-env.sh "$$rc" "$(abspath tools/hbenv.sh)"; done

## clean       remove bin/
clean:
	rm -rf bin
