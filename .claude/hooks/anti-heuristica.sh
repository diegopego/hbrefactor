#!/usr/bin/env bash
# PreToolUse(Bash) — PORTÃO ANTI-HEURÍSTICA (Diego, 2026-07-12).
#
# A REGRA DO FATO diz que o hbrefactor age só sobre FATO da AST do compilador:
# nada de heurística, inferência ou réplica de gramática do core. A regra existia
# e vinha sendo quebrada "de tempos em tempos" — porque era uma regra, não um
# PORTÃO. Este hook é o portão: ele intercepta `git commit` e recusa o commit
# quando o diff STAGED de src/hbrefactor.prg adiciona linhas com os CHEIROS
# catalogados no CLAUDE.md (§ GATILHOS da REGRA DO FATO).
#
# Ele NÃO decide se o código é heurística — ele PARA e obriga a pergunta. A
# liberação é do Diego, por caso (igual à autorização de commit), e se dá
# marcando a linha com o selo abaixo, que só se escreve DEPOIS do "ok" dele:
#
#     // FATO-OK(diego,AAAA-MM-DD): <por que o core não pode dar este fato>
#
# Bloqueia com exit 2, cuja saída volta para o Claude como instrução.

set -uo pipefail

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: print("")')

# só interessa `git commit` (e não `git commit --dry-run`, que não grava nada)
case "$CMD" in
   *"git commit"*) : ;;
   *) exit 0 ;;
esac

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

ALVO="src/hbrefactor.prg"
git diff --cached --quiet -- "$ALVO" 2>/dev/null && exit 0   # a ferramenta não mudou

# linhas ADICIONADAS (sem o '+' do diff), fora de comentário puro, sem o selo
ADD=$(git diff --cached -U0 -- "$ALVO" | grep '^+' | grep -v '^+++' | sed 's/^+//' \
      | grep -v 'FATO-OK(')

SAIDA=""
relata() {  # relata <rotulo> <regex-egrep>  -- acumula em SAIDA (SEM subshell:
            # `x=$(f)` roda f num subshell e a variável de dentro se perde)
   local hits
   hits=$(printf '%s\n' "$ADD" | grep -nEi "$2" | head -3) || true
   if [ -n "$hits" ]; then
      SAIDA+=$(printf '\n  [%s]\n%s\n' "$1" "$(printf '%s\n' "$hits" | sed 's/^/    /')")
      SAIDA+=$'\n'
   fi
}

relata "gatilho 1 - comparação de TEXTO para decidir PAPEL/IDENTIDADE (o dump tem id/número?)" \
   'Upper\([^)]*\) *== *Upper\(|== *Left\(|\bLeft\([^)]*\) *==|\$ *(cUp|cNome|cName)'
relata "gatilho 2 - CONSTANTE MÁGICA de gramática (réplica de regra do compilador)" \
   '(Len|hb_BLen)\([^)]*\) *(>=|>|<=|<) *[0-9]+'
# O gatilho 5 é CASAR arquivo por basename (dois .ch homônimos colidem), não
# EXIBIR o basename. `Refuse( "text in " + hb_FNameNameExt( cPath ) + ... )` lê
# e escreve pelo caminho CANÔNICO e só encurta o nome na mensagem - acusá-lo era
# falso positivo (6 sites, 2026-07-12). Acusa quando o basename é COMPARADO
# (==, $) ou vira CHAVE de hash/índice - aí sim ele decide identidade.
relata "gatilho 4/5 - re-implementar RESOLUÇÃO do core / casar por BASENAME" \
   'hb_FNameName[^)]*\) *(==|\$)|(==|\$) *hb_FNameName|hb_HHasKey\([^,]*, *hb_FNameName|\[ *hb_FNameName|hb_vfExists.*\+.*cFile|FOR EACH .* IN .*\[ *"inc" *\]'

if [ -n "$SAIDA" ]; then
   cat >&2 <<EOF
PORTÃO ANTI-HEURÍSTICA: commit BARRADO.

O diff staged de $ALVO adiciona linhas com os cheiros do CLAUDE.md
(§ GATILHOS da REGRA DO FATO):
$SAIDA

Antes de commitar, responda: **"o core SABE isto e não me conta?"**
  - Se sim  -> o conserto é ESTENDER O CORE (foi assim que nasceram ast-14,
               ast-15 e ast-16 — nos três, o fato faltava e eu ia remendar aqui).
  - Se não  -> é uma RECUSA sobre o core, e recusa exige varredura REGISTRADA
               (--help, API pública, tests/ do core, ChangeLog).

Heurística/inferência/réplica no hbrefactor exige AUTORIZAÇÃO EXPLÍCITA DO DIEGO,
por caso. É PROIBIDO implementar "provisoriamente" e pedir depois.

Se ele autorizou, sele a linha (e só então):
    // FATO-OK(diego,$(date +%F)): <por que o core não pode dar este fato>

Se o achado for FALSO POSITIVO, diga qual e por quê antes de seguir.
EOF
   exit 2
fi
exit 0
