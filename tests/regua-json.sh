#!/bin/bash
# ---------------------------------------------------------------------------
# RÉGUA do contrato de máquina (A.1): sob `--json`, NENHUM comando sai calado.
#
# A CICATRIZ (2026-07-24, e o bug foi meu): ao separar o canal humano do canal
# de máquina, os 171 pontos de saída viraram `Prose()` - que cala sob `--json`.
# Os comandos ainda não migrados para o envelope passaram então a devolver
# stdout VAZIO com exit 0. Silêncio indistinguível de sucesso é o pior modo de
# falha que esta ferramenta pode ter, e a suíte inteira passou verde por cima
# dele: nenhum caso rodava aqueles comandos com `--json`.
#
# A régua roda TODO comando que a Usage() anuncia e reprova o que sair mudo.
# Não julga o conteúdo - só exige que exista resposta.
# ---------------------------------------------------------------------------
set -u
BIN="${1:?binário do hbrefactor}"
BIN="$( cd "$( dirname "$BIN" )" && pwd )/$( basename "$BIN" )"   # o teste faz cd: caminho ABSOLUTO
FIX="${2:?diretório com um projeto de teste}"

D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
cp "$FIX"/* "$D"/ 2>/dev/null

# os comandos que o binário ANUNCIA (fonte única: a própria Usage())
CMDS=$( "$BIN" 2>&1 | sed -n 's/^  hbrefactor \([a-z-]*\) .*/\1/p' | sort -u )
[ -z "$CMDS" ] && { echo "régua-json: não consegui listar os comandos da Usage()"; exit 1; }

# PLACAR da migração (A.1): comandos que AINDA não modelam o próprio fato.
# Encolhe a cada verbo migrado; quando esvaziar, a régua exige contrato de TODOS.
# Deixar isto EXPLÍCITO é melhor que a régua passar calada sobre o que falta.
# VAZIO (passo 1 completo): os 14 comandos - leitura E edição - modelam o fato.
PENDENTES=" "

falhas=0
for c in $CMDS; do
   # cada comando com o projeto como 1o argumento; argumentos faltando dão
   # `usage`, que TAMBÉM tem de sair como envelope (nunca vazio)
   out=$( cd "$D" && "$BIN" "$c" app.hbp --json 2>/dev/null )
   if [ -z "$out" ]; then
      echo "  $c: stdout VAZIO sob --json (silêncio não pode parecer sucesso)"
      falhas=$(( falhas + 1 ))
   elif ! printf '%s' "$out" | grep -q '"schema": "cli-2"'; then
      echo "  $c: stdout não é o envelope cli-1"
      falhas=$(( falhas + 1 ))
   elif printf '%s' "$out" | grep -q '"no-machine-contract-yet"'; then
      # o gate no ponto de saída impede o SILÊNCIO, mas o fallback não é
      # contrato: o comando ainda não modela o próprio fato. A régua mede a
      # COMPLETUDE, não só a não-mudez - mas tolera o que está no PLACAR.
      case "$PENDENTES" in
         *" $c "*) : ;;   # ainda na fila, tudo bem
         *) echo "  $c: caiu no fallback e NÃO está no placar de pendentes"
            falhas=$(( falhas + 1 )) ;;
      esac
   fi
done

[ "$falhas" -eq 0 ] || { echo "régua-json: $falhas comando(s) sem contrato de máquina"; exit 1; }
exit 0
