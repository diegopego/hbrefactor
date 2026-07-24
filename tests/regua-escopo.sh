#!/bin/bash
# ---------------------------------------------------------------------------
# RÉGUA EXECUTÁVEL da P17 (item 5 do critério de pronto).
#
# POR QUÊ: o experimento da fase provou o rot na prática - ligado a UM verbo, o
# aviso de alcance não existia nos outros, e o caso da diretiva passou batido.
# Regra sem portão é regra que se viola de novo (CLAUDE.md §1.6).
#
# O QUE ELA COBRA: todo verbo que ANUNCIA um rename ("rename-XXX: ") tem de
# chamar SayScope() dentro da mesma função - senão ele volta a afirmar sobre um
# alcance que nunca declarou.
#
# saída: lista os verbos sem a chamada; exit 0 = todos cobertos
# ---------------------------------------------------------------------------
set -u
SRC="${1:?fonte da ferramenta}"

awk '
   /^STATIC FUNCTION |^FUNCTION / { fn = $3; sub( /\(.*/, "", fn ); start = NR; verb = ""; said = 0 }
   /OutStd\( "rename-/ {
      if( verb == "" ) { verb = $0; sub( /.*OutStd\( "/, "", verb ); sub( /:.*/, "", verb ) }
   }
   /SayScope\(/ { said = 1 }
   /^STATIC FUNCTION |^FUNCTION |^$/ {
      if( verb != "" && prevfn != "" && !prevsaid ) print "  " prevverb "  (" prevfn ")"
   }
   { if( verb != "" ) { prevfn = fn; prevverb = verb; prevsaid = said } }
   END {
      if( verb != "" && !said ) print "  " verb "  (" fn ")"
   }
' "$SRC" | sort -u > /tmp/regua-escopo.$$

# a varredura acima é frágil por natureza (awk sobre texto); a régua REAL é a
# de baixo: por verbo, olhar o corpo da função inteira
: > /tmp/regua-falhas.$$
for ln in $( grep -n 'OutStd( "rename-' "$SRC" | cut -d: -f1 ); do
   verb=$( sed -n "${ln}p" "$SRC" | sed 's/.*OutStd( "//; s/:.*//' )
   # início da função que contém a linha
   ini=$( awk -v n="$ln" 'NR<=n && (/^STATIC FUNCTION /||/^FUNCTION /) { l=NR } END { print l }' "$SRC" )
   # fim = próxima definição de função depois do início
   fim=$( awk -v i="$ini" 'NR>i && (/^STATIC FUNCTION /||/^FUNCTION /) { print NR; exit }' "$SRC" )
   [ -z "$fim" ] && fim=$( wc -l < "$SRC" )
   if ! sed -n "${ini},${fim}p" "$SRC" | grep -q 'SayScope('; then
      fn=$( sed -n "${ini}p" "$SRC" | sed 's/^STATIC FUNCTION //; s/^FUNCTION //; s/(.*//' )
      echo "  $verb  (função $fn, linha $ln)" >> /tmp/regua-falhas.$$
   fi
done
rm -f /tmp/regua-escopo.$$

if [ -s /tmp/regua-falhas.$$ ]; then
   echo "verbos de rename SEM o aviso de alcance da P17 (SayScope):"
   sort -u /tmp/regua-falhas.$$
   rm -f /tmp/regua-falhas.$$
   exit 1
fi
rm -f /tmp/regua-falhas.$$
exit 0
