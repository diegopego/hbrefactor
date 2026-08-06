#!/usr/bin/env bash
# tools/pcode-identity.sh - A PROVA DE IMPACTO ZERO do branch do core.
#
# Afirmação que a proposta aos mantenedores faz (harbour-core/site/index.html):
# "com os switches DESLIGADOS, o compilador remendado gera pcode IDÊNTICO ao do
# Harbour stock". É o número mais importante daquela página - um mantenedor que
# desconfie dele não lê o resto. Era medido À MÃO, e por isso nunca era remedido;
# este script existe para que remedir seja barato.
#
# Método: cada .prg é compilado para .hrb (pcode portável) pelos DOIS
# compiladores, sem nenhum switch novo, e os bytes são comparados. Só entram na
# conta os módulos que os DOIS compilam - um .prg que não compila (falta de
# header do próprio contrib, etc.) não diz nada sobre impacto.
#
#   uso: make pcode-identity        <- o normal: provisiona o stock se faltar,
#                                       confere os dois toolchains, e mede
#        tools/pcode-identity.sh [harbour-STOCK] [harbour-REMENDADO] [raiz-do-core]
#                                sem argumentos, os dois vem da fonte unica

set -uo pipefail

. "$(cd "$(dirname "$0")" && pwd)/hbenv.sh"   # os DOIS toolchains, da fonte única

STOCK="${1:-$HB_STOCK_BIN/harbour}"
PATCHED="${2:-$HB_BIN/harbour}"
ROOT="${3:-$HB_CORE}"

# QUEM É QUEM não é confiado ao chamador. Trocar os dois argumentos não daria
# erro nenhum: daria 100% de identidade - o binário comparado com ele mesmo -,
# e essa é justamente a resposta que este script existe para NÃO inventar.
# O papel de cada um está gravado no binário: o remendado carrega o schema do
# dump, o de fábrica não pode carregar.
for _b in "$STOCK" "$PATCHED"; do
   [ -x "$_b" ] || { echo "pcode-identity: nao existe: $_b" >&2; exit 1; }
done
# NUNCA `grep -q` dentro de pipeline aqui: com `pipefail` (ligado acima) o -q
# fecha o pipe, o `strings` leva SIGPIPE, e o PIPELINE sai nao-zero mesmo tendo
# CASADO. A guarda mentiria na direcao mais perigosa - "nao tem o dump" sobre um
# binario que tem. Substituicao de comando nao tem esse problema.
_schema_de() { strings "$1" | grep -oE '^ast-[0-9]+$' | sort -u | tr '\n' ' '; }

if [ -n "$(_schema_de "$STOCK")" ]; then
   echo "pcode-identity: o STOCK ($STOCK) carrega o dump - isto nao e' o de fabrica." >&2
   echo "                rode 'make stock'; comparar o remendado consigo mesmo prova nada." >&2
   exit 1
fi
if [ -z "$(_schema_de "$PATCHED")" ]; then
   echo "pcode-identity: o REMENDADO ($PATCHED) nao carrega o dump - isto nao e' o branch." >&2
   echo "                rode 'make core'." >&2
   exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/s" "$TMP/p"

ident=0 difer=0 pulado=0
DIFF_LIST="$TMP/divergentes.txt"
: > "$DIFF_LIST"

while IFS= read -r prg; do
   base=$(basename "$prg" .prg)
   dir=$(dirname "$prg")
   rm -f "$TMP/s/$base.hrb" "$TMP/p/$base.hrb"

   # -gh: pcode portável.  -n: sem procedure implícita.  -q0: quieto.
   # -I: o include do core + o diretório do próprio fonte (contribs têm .ch locais)
   "$STOCK"   "$prg" -n -q0 -gh -o"$TMP/s/" -i"$ROOT/include" -i"$dir" > /dev/null 2>&1
   "$PATCHED" "$prg" -n -q0 -gh -o"$TMP/p/" -i"$ROOT/include" -i"$dir" > /dev/null 2>&1

   if [ ! -f "$TMP/s/$base.hrb" ] || [ ! -f "$TMP/p/$base.hrb" ]; then
      pulado=$((pulado+1))          # não compila nos dois -> não conta
      continue
   fi
   if cmp -s "$TMP/s/$base.hrb" "$TMP/p/$base.hrb"; then
      ident=$((ident+1))
   else
      difer=$((difer+1))
      echo "$prg" >> "$DIFF_LIST"
   fi
done < <(find "$ROOT" -name '*.prg' -not -path '*/.git/*' | sort)

total=$((ident+difer))
echo "pcode (.hrb) com os switches DESLIGADOS, remendado vs stock:"
echo "  IDÊNTICOS:   $ident / $total"
echo "  DIVERGENTES: $difer"
echo "  (não compilam nos dois, fora da conta: $pulado)"
if [ "$difer" -gt 0 ]; then
   echo "--- divergentes:"; cat "$DIFF_LIST"
fi
[ "$difer" -eq 0 ]
