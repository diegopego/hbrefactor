#!/usr/bin/env bash
# artefato-vazado.sh - PostToolUse/Bash: o compilador escreveu .c onde ninguem mandou?
#
# O `harbour` grava o `.c` no CWD, nao ao lado do fonte. A regra ja' existe
# (CLAUDE.md 2: "depois de qualquer comando que rode o compilador ao lado dos
# fontes, conferir git status") e foi violada TRES vezes em 2026-08-09/11, uma
# delas com 587 arquivos de uma vez - um censo que rodou o compilador 726 vezes
# com o CWD na raiz do repo. Regra sem portao e' regra que se viola de novo
# (CLAUDE.md 1.6): entao o freio e' codigo, nao mais um paragrafo.
#
# Ele nao adivinha o comando - olha o ESTRAGO, e por isso vale para qualquer
# forma de invocar o compilador. Roda depois de todo Bash, nos DOIS repos.
#
# SO' `.c`, e SO' os que o harbour gerou. Duas razoes, as duas do Diego:
#   - `.ppo`, `.ppt` e `.ast.json` sao salvos DE PROPOSITO em teste (os retratos
#     `oracle/` do tests/README.md 6). Marca-los teria mordido trabalho legitimo -
#     a primeira versao deste hook fazia isso;
#   - `.c` legitimo existe (o core inteiro e' C). O gerado se identifica pelo
#     cabecalho, que o proprio compilador escreve:
#         * Generated C source from "x.prg"
#     Sem heuristica de nome, sem lista de pastas: o arquivo diz o que e'.
#
# O que ele NAO cobre, dito para nao ser confundido com cobertura total: lixo
# que o .gitignore engole e que contamina uma SONDA (CLAUDE.md 1.7.8). Contra
# isso o remedio continua sendo diretorio novo a cada medicao.
set -uo pipefail

raiz="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$raiz" ] || exit 0

achados=""
for repo in "$raiz" "$(sh "$raiz/tools/hbenv.sh" --print HB_CORE 2>/dev/null)"; do
   [ -n "$repo" ] && [ -d "$repo/.git" ] || continue

   # sem `| head` no fim: consumidor que fecha o pipe faz o pipeline sair
   # nao-zero sob pipefail mesmo tendo casado (cicatrizes 5.1b, e o
   # TestNenhumScriptCaiNaArmadilhaDoPipefail pegou este hook fazendo isso)
   novos=$(git -C "$repo" status --porcelain 2>/dev/null | sed -n 's/^?? //p')
   [ -n "$novos" ] || continue

   deste=""
   while IFS= read -r f; do
      case "$f" in
         *.c ) ;;
         * ) continue ;;
      esac
      cab=$(head -5 "$repo/$f" 2>/dev/null)
      case "$cab" in
         *"Generated C source from"* ) deste="${deste}
    $f" ;;
      esac
   done <<< "$novos"

   [ -n "$deste" ] || continue
   achados="${achados}
  em $(basename "$repo"):$deste"
done

[ -n "$achados" ] || exit 0

cat >&2 <<EOF
o compilador deixou .c gerado na arvore:$achados

Ele grava no CWD, nao ao lado do fonte. Mande a saida para um tmp (\`-o<tmp>/\`,
com a barra final) e rode a partir de um diretorio de sonda, nunca da raiz do
repo. Apague os arquivos acima antes de seguir - eles entram no proximo
\`git add -A\`.
EOF
exit 2
