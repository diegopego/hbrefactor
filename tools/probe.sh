#!/bin/sh
# probe.sh - um diretório de sonda NOVO, nunca reusado, com o estado inicial gravado.
#
# POR QUE ISTO EXISTE (2026-08-08, ordem do Diego depois da TERCEIRA vez no
# mesmo dia): a ferramenta EDITA os fontes - é o trabalho dela. Logo toda pasta
# de sonda é de USO ÚNICO, e reusar uma faz o "antes" da medição já ser o
# "depois" da anterior. As três contaminações do dia:
#
#   1. rodei `usages` numa pasta onde um `rename` anterior já havia editado;
#   2. "restaurei" com sed e medi - o nome velho já era o novo;
#   3. copiei como modelo uma pasta que o script anterior tinha editado.
#
# Nas três a medição SAIU, com cara de resposta. Silêncio não é o modo de falha
# aqui: resposta errada e confiante é. Por isso o mecanismo não é um aviso -
# é RECUSAR reusar, e conferir que o estado inicial é o que se pensa.
#
# Uso:
#   D=$(sh tools/probe.sh new <arquivo-ou-dir>...)   # cria, copia, grava baseline
#   sh tools/probe.sh diff "$D"                      # o que mudou desde a criação
#   sh tools/probe.sh check "$D"                     # falha se JÁ mudou (antes de medir)

set -eu

raiz=${HBREF_PROBE_ROOT:-${TMPDIR:-/tmp}/hbref-probes}
manifesto=.probe-baseline

grava() {
   ( cd "$1" && find . -type f ! -name "$manifesto" -exec sha256sum {} + \
        | LC_ALL=C sort > "$manifesto" )
}

case "${1:-}" in
new)
   shift
   mkdir -p "$raiz"
   # número SEMPRE crescente: um diretório nunca é reaproveitado, nem depois de
   # apagado à mão (o contador olha o maior que já existiu neste raiz)
   n=$( ls "$raiz" 2>/dev/null | sed -n 's/^p\([0-9]\{4\}\).*$/\1/p' \
        | LC_ALL=C sort -n | tail -1 )
   n=$(( ${n:-0} + 1 ))
   d=$( printf '%s/p%04d' "$raiz" "$n" )
   [ -e "$d" ] && { echo "probe: $d já existe - recusando" >&2; exit 1; }
   mkdir "$d"
   for a in "$@"; do
      [ -e "$a" ] || { echo "probe: '$a' não existe" >&2; exit 1; }
      if [ -d "$a" ]; then cp -r "$a"/. "$d"/; else cp "$a" "$d"/; fi
   done
   grava "$d"
   echo "$d"
   ;;
check)
   d=${2:?uso: probe.sh check <dir>}
   [ -f "$d/$manifesto" ] || { echo "probe: $d não é um probe (sem baseline)" >&2; exit 1; }
   if ! ( cd "$d" && sha256sum -c --status "$manifesto" ); then
      echo "probe: $d JÁ FOI MODIFICADO - o 'antes' desta medição não é o inicial" >&2
      exit 1
   fi
   ;;
diff)
   d=${2:?uso: probe.sh diff <dir>}
   [ -f "$d/$manifesto" ] || { echo "probe: $d não é um probe (sem baseline)" >&2; exit 1; }
   ( cd "$d" && sha256sum -c "$manifesto" 2>/dev/null | grep -v ': OK$' || true )
   ;;
*)
   sed -n '2,25p' "$0"
   exit 1
   ;;
esac
