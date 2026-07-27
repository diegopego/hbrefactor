#!/usr/bin/env bash
# PreToolUse(Bash) — PORTÃO DO FORMATO DE TESTE (Diego, 2026-07-26).
#
# `tests/run.sh` e `tests/cases/` são LEGADO em migração para `tests/scenarios/`
# (contrato em tests/README.md). A lei já diz "nada de teste NOVO ali" — e, como
# toda regra deste repo que só existia em prosa, ela ia ser quebrada: a migração
# tem ~127 iterações e basta uma sessão distraída para o formato antigo crescer
# de novo enquanto o esforço é para matá-lo.
#
# Este hook intercepta `git commit` e recusa quando o diff STAGED:
#   (a) ACRESCENTA um `unit_N()` ao tests/run.sh, ou acrescenta número à lista
#       ALL_UNITS  — tirar de lá é o trabalho; pôr, não;
#   (b) cria arquivo NOVO em tests/cases/ — aquele formato também está morrendo.
#
# Ele NÃO impede nada em tests/scenarios/, e NÃO impede REMOÇÃO — o sentido do
# fluxo é de mão única, e é isso que ele protege.
#
# Bloqueia com exit 2, cuja saída volta para o Claude como instrução.

set -uo pipefail

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: print("")')

case "$CMD" in
   *"git commit"*) : ;;
   *) exit 0 ;;
esac

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

SAIDA=""

# (a) unit_N novo, ou número novo em ALL_UNITS. Só linhas ADICIONADAS.
if ! git diff --cached --quiet -- tests/run.sh 2>/dev/null; then
   NOVOS=$(git diff --cached -U0 -- tests/run.sh | grep '^+' | grep -v '^+++' | sed 's/^+//' \
           | grep -E '^\s*unit_[0-9]+\(\)' || true)
   if [ -n "$NOVOS" ]; then
      SAIDA+=$(printf '\n  [unit novo no formato LEGADO]\n%s\n' "$(printf '%s\n' "$NOVOS" | sed 's/^/    /')")
   fi
   # ALL_UNITS: comparar os CONJUNTOS de números entre a versão HEAD e a staged.
   # Um grep de linha não serve — a lista é uma linha só, e toda edição a
   # reescreve inteira (remover 3 também "adiciona" a linha).
   ANTES=$(git show HEAD:tests/run.sh 2>/dev/null | grep -o 'ALL_UNITS="[^"]*"' | tr -d '"' | cut -d= -f2)
   DEPOIS=$(git show :tests/run.sh 2>/dev/null | grep -o 'ALL_UNITS="[^"]*"' | tr -d '"' | cut -d= -f2)
   ENTRARAM=$(comm -13 <(printf '%s\n' $ANTES | sort -u) <(printf '%s\n' $DEPOIS | sort -u) | tr '\n' ' ')
   if [ -n "${ENTRARAM// /}" ]; then
      SAIDA+=$(printf '\n  [número novo em ALL_UNITS]\n    %s\n' "$ENTRARAM")
   fi
fi

# (b) arquivo novo nos formatos intermediários. Os DOIS são legado desde que a
# classe A passou a ser Go (Diego, 2026-07-26): tests/cases/ tinha o esperado
# GRAVADO da execução, e tests/scenarios/ foi a ponte que o substituiu — ela
# cumpriu o papel e agora também só encolhe.
for velho in 'tests/cases/*' 'tests/scenarios/*'; do
   NOVOS_ARQ=$(git diff --cached --name-only --diff-filter=A -- "$velho" 2>/dev/null || true)
   if [ -n "$NOVOS_ARQ" ]; then
      SAIDA+=$(printf '\n  [arquivo novo em %s (formato legado)]\n%s\n' \
               "${velho%/\*}/" "$(printf '%s\n' "$NOVOS_ARQ" | sed 's/^/    /')")
   fi
done

if [ -n "$SAIDA" ]; then
   cat >&2 <<EOF
PORTÃO DO FORMATO DE TESTE: commit BARRADO.

O diff staged faz o formato LEGADO crescer:
$SAIDA

Teste novo é um CASO em tests-go/suite/, e o contrato é tests/README.md — leia-o
inteiro antes de escrever. O caminho:

    tools/unit-brief.py <N>        # o que o unit antigo prova (se for migração)
    tools/caso-new.sh <nome> <fixture>
    # escreva expected/ e outputs.json À MÃO, ANTES de rodar
    make oracle NOME=<nome> && make caso NOME=<nome>

Se o teste NÃO couber no formato, isso é uma PROPOSTA DE MUDANÇA em
tests/README.md §9 — nunca uma exceção no formato antigo.

Este portão não impede REMOVER de lugar nenhum (migrar é mover) nem nada em
tests-go/. Falso positivo? Diga qual e por quê antes de seguir.
EOF
   exit 2
fi
exit 0
