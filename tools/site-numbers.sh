#!/usr/bin/env bash
# tools/site-numbers.sh - todo número das páginas é MEDIDO, nunca digitado.
#
# Ordem do Diego (2026-07-12): "se realmente importa colocar estes indicadores,
# eles devem ser atualizados de forma DETERMINÍSTICA". A motivação é concreta:
# a proposta aos mantenedores afirmava `1085/1085` e `112/112` módulos com pcode
# idêntico, a página do hbrefactor dizia `105 cases / 825 checks`, e o texto
# falava em "thirteen schema steps". Os QUATRO estavam errados, e ninguém tinha
# notado - porque número mantido à mão envelhece calado.
#
# Como funciona: cada indicador na página é um elemento MARCADO
#
#     <span data-metric="suite-checks">913</span>
#
# e este script recalcula o valor e reescreve o conteúdo. Nada de casar número
# solto por regex (que erra o alvo e corrompe o HTML).
#
#   uso:  tools/site-numbers.sh          # mede e ESCREVE
#         tools/site-numbers.sh --check  # mede e FALHA se algum estiver defasado
#
# REGRA que vem junto: indicador que não se consegue GERAR não entra na página.
# É por isso que a prova de impacto zero (que exige buildar DOIS compiladores, e
# não cabe num alvo de rotina) aparece lá como o COMANDO que o mantenedor roda,
# e não como um número - ver tools/pcode-identity.sh.

set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${CORE:-$HOME/devel/harbour-core/harbour}"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

declare -A M   # métrica -> valor

# ---------------------------------------------------------------- a suíte
# casos = as unidades registradas em ALL_UNITS; checks = o que o run reporta
M[suite-cases]=$(grep '^ALL_UNITS=' "$HERE/tests/run.sh" | tr ' ' '\n' | grep -cE '^[0-9]+')
if [ -n "${SUITE_CHECKS:-}" ]; then
   M[suite-checks]="$SUITE_CHECKS"          # atalho: reaproveita um run recente
else
   M[suite-checks]=$( cd "$HERE" && make -s test 2>/dev/null | sed -n 's/^passed: \([0-9]*\).*/\1/p' | tail -1 )
   rm -f "$HERE/sh1.c"                      # o compilador escreve o .c no CWD
fi

# --------------------------------------------- quantas versões de schema (ast-N)
# fonte: a própria tabela do NEWS.md do core - uma linha por schema
M[schema-count]=$(grep -cE '^\| `ast-[0-9]+`' "$CORE/NEWS.md")

# A FORMA DO DIFF NAO E MEDIDA AQUI - e essa e a lição (Diego, 2026-07-12).
# Tentei automatizá-la e ela exigia (a) uma BASE de comparação e (b) uma lista de
# exclusões. As duas apodrecem: o `master` local estava 7 commits atrasado e a
# conta acusou o UPSTREAM de poluir o branch - um achado falso, publicado. Um
# número que depende de uma base que envelhece e de uma exclusão escondida não
# vale o que custa. Na página ele deu lugar ao COMANDO que o mantenedor roda.
#
# A regra que fica: só vira indicador o que se MEDE SOZINHO, sem base nem
# exclusão. Suíte e contagem de schemas passam; forma do diff, não.

# ------------------------------------------------------------------ aplicar
stale=0
aplica() { # aplica <arquivo>
   local f="$1" k v cur
   for k in "${!M[@]}"; do
      v="${M[$k]}"
      grep -q "data-metric=\"$k\"" "$f" || continue
      cur=$(sed -n "s/.*data-metric=\"$k\"[^>]*>\([^<]*\)<.*/\1/p" "$f" | head -1)
      if [ "$cur" != "$v" ]; then
         if [ "$CHECK" = 1 ]; then
            echo "DEFASADO  $(basename "$f")  $k: página='$cur'  medido='$v'"
            stale=1
         else
            sed -i "s|\(data-metric=\"$k\"[^>]*>\)[^<]*<|\1$v<|g" "$f"
            echo "  $k: $cur -> $v   ($(basename "$f"))"
         fi
      fi
   done
}
aplica "$HERE/site/index.html"
[ -f "$CORE/site/index.html" ] && aplica "$CORE/site/index.html"

# o manual não é HTML: a linha de baseline é o indicador dele
MAN="$HERE/docs/manual.md"
LINHA="  suite at baseline: ${M[suite-cases]} cases, ${M[suite-checks]} checks green"
if ! grep -qxF "$LINHA" "$MAN"; then
   if [ "$CHECK" = 1 ]; then
      echo "DEFASADO  manual.md  baseline: $(grep -n 'suite at baseline' "$MAN" | head -1)"
      stale=1
   else
      sed -i "s|^  suite at baseline:.*|$LINHA|" "$MAN"
      echo "  manual.md baseline -> ${M[suite-cases]} cases, ${M[suite-checks]} checks"
   fi
fi

if [ "$CHECK" = 1 ]; then
   [ "$stale" = 0 ] && echo "indicadores em dia (nada defasado)"
   exit "$stale"
fi
echo "indicadores atualizados por MEDIÇÃO."
