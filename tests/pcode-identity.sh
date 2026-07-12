#!/usr/bin/env bash
# tests/pcode-identity.sh - A PROVA DE IMPACTO ZERO do branch do core.
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
#   uso: tests/pcode-identity.sh <harbour-STOCK> <harbour-REMENDADO> [raiz-do-core]

set -uo pipefail

STOCK="${1:?caminho do harbour STOCK}"
PATCHED="${2:?caminho do harbour REMENDADO}"
ROOT="${3:-$HOME/devel/harbour-core/harbour}"

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
