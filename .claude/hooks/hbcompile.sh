#!/usr/bin/env bash
# PostToolUse(Edit|Write) — PORTÃO DE COMPILAÇÃO DE .prg (Diego, 2026-07-14).
#
# O CLAUDE.md (§3) manda "compile todo .prg (fixture, exemplo, teste) ANTES de
# usá-lo" porque um fixture que não compila gera DIAGNÓSTICO ENGANOSO — um erro
# de expansão pp na fixture já foi confundido com regressão no mecanismo. A regra
# vivia só no texto; este hook a torna PORTÃO: assim que eu edito/crio um .prg
# nosso, ele roda o compilador do HB_BIN e, se não compilar limpo, DEVOLVE o erro
# para o Claude na hora (exit 2 → stderr vira instrução).
#
# É ADVISÓRIO, não bloqueante: PostToolUse roda DEPOIS da escrita (a edição já
# aconteceu). O valor é o feedback imediato — nunca "desfazer".
#
# ANTI-VAZAMENTO (§2): usa `-s` (checagem de sintaxe, SEM geração de código),
# exatamente como o "case 0" da suíte. `-s` não escreve .c/.ppo/.d — nada vaza
# para o repo, então não é preciso -o<tmp>.
#
# TOOLCHAIN (§2): usa $HB_BIN; se não vier no ambiente, cai no MESMO default que
# o Makefile declara (`HB_BIN ?= $HOME/.../bin/linux/gcc`) — não é chute, é a
# fonte de verdade do build. Se nem esse harbour existir, sai calado (exit 0):
# sem toolchain não há veredito a dar.

set -uo pipefail

INPUT=$(cat)

FILE=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))
except Exception: print("")')

# só nos interessa .prg
case "$FILE" in
   *.prg) : ;;
   *) exit 0 ;;
esac

# arquivo tem de existir de fato (uma edição pode ter falhado / caminho estranho)
[ -f "$FILE" ] || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(git -C "$(dirname "$FILE")" rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$ROOT" ] || exit 0

# ESCOPO: só o .prg que NÓS escrevemos — fixtures (tests/) e a ferramenta (src/).
#   - work/      = cópias de código do CORE (corpus): só compila junto do core;
#                  checar isolado daria falso-negativo. FORA.
#   - smoketest/ = primeira encarnação, arquivada, só leitura. FORA.
#   - tests/tmp/ = fixtures COPIADAS para execução da suíte (efêmeras). FORA.
#   - .hbmk/     = cache do hbmk2. FORA.
case "$FILE" in
   "$ROOT"/tests/tmp/*|*/.hbmk/*|"$ROOT"/work/*|"$ROOT"/smoketest/*) exit 0 ;;
   "$ROOT"/tests/*|"$ROOT"/src/*) : ;;
   *) exit 0 ;;   # fora do escopo autoral → não é assunto do portão
esac

# TOOLCHAIN: HB_BIN do ambiente, ou o default do Makefile (mesma fonte de verdade)
HB_BIN="${HB_BIN:-$HOME/devel/harbour-core/harbour/bin/linux/gcc}"
HARBOUR="$HB_BIN/harbour"
[ -x "$HARBOUR" ] || exit 0   # sem toolchain, sem veredito — calado

DIR=$(dirname "$FILE")

# checagem de SINTAXE sob o contrato do repo (-w3 -es2, como o case 0 e os .hbp):
#   -s  só sintaxe, não gera código (anti-vazamento)
#   -n  sem procedure implícita a partir de statements de topo
#   -q0 silencioso
#   -I  inclui o diretório do próprio .prg (acha o .ch da fixture) E o contrib/hbtest:
#       o corpus METODO-V2 usa `#include "hbtest.ch"`, e sem esse -I o portão dava
#       FALSO-NEGATIVO ("Can't open #include file 'hbtest.ch'") em toda fixture com
#       assert. É o mesmo -I que o corpus_compile_all já passa; com -s (sem link) o
#       hbtest.hbc não é preciso — basta ACHAR o header. So' se o dir existir.
INCS=(-I"$DIR")
HBTEST_INC="${HB_BIN%/bin/*}/contrib/hbtest"
[ -d "$HBTEST_INC" ] && INCS+=(-I"$HBTEST_INC")
OUT=$("$HARBOUR" "$FILE" -n -q0 -w3 -es2 -s "${INCS[@]}" 2>&1)
RC=$?

[ $RC -eq 0 ] && exit 0   # compila limpo → silêncio (sucesso não faz barulho)

# não compilou: devolve o veredito ao Claude (exit 2 → stderr vira instrução)
REL="${FILE#"$ROOT"/}"
{
   echo "PORTÃO DE COMPILAÇÃO: '$REL' NÃO compila limpo sob -w3 -es2 (harbour de HB_BIN)."
   echo "Um .prg que não compila gera diagnóstico enganoso (CLAUDE.md §3) — conserte ANTES de usá-lo em teste/exemplo."
   echo "--- saída do compilador ---"
   printf '%s\n' "$OUT"
} >&2
exit 2
