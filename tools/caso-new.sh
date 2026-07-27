#!/usr/bin/env bash
# caso-new.sh <nome> <fixture> — anda o esqueleto de um CASO da classe A.
#
# O contrato do formato é tests/README.md, e só ele. Aqui só o que é mecânico e
# SEGURO de automatizar: copiar a fixture para `source/` (o caso é dono da
# entrada) e escrever o arquivo Go que registra o caso.
#
# A LINHA VERMELHA: este script NÃO cria `expected/` nem `outputs.json`, e nunca
# vai criar. Ferramenta que grave esperado é PROIBIDA no repo — uma foi escrita
# e deletada no mesmo dia (cicatrizes §6.4). Gravado, o esperado afirma "a
# ferramenta faz isto hoje" e congela o defeito atual; escrito à mão do
# contrato, ele afirma "o contrato pede isto" e é aí que o defeito aparece.
#
# Ele TAMBÉM não roda o hbrefactor. Se rodasse, você veria a saída antes de
# escrever o esperado — e aí escrever vira copiar, com passos extras.
#
# Uso:  tools/caso-new.sh refuse-new-name-taken fix01

set -uo pipefail

NOME="${1:-}"
FIX="${2:-}"
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "caso-new: fora de um clone git"; exit 1; }

case "$NOME" in
   ''|*[!a-z0-9-]*)
      echo "caso-new: <nome> obrigatório, só [a-z0-9-]."
      echo "  O nome diz o que o caso PROVA (rename-local-beside-define,"
      echo "  refuse-old-name-shadowed-by-block-param) — nunca um número: número"
      echo "  amarra ao runner antigo, que é legado."
      exit 2 ;;
esac
case "$NOME" in
   *[0-9]) echo "caso-new: '$NOME' termina em número — o nome diz o que prova, não a posição no runner antigo."; exit 2 ;;
esac
[ -n "$FIX" ] || { echo "caso-new: <fixture> obrigatória (ex.: fix01). Descubra com: tools/unit-brief.py <N>"; exit 2; }

SRC="$ROOT/tests/$FIX"
SUITE="$ROOT/tests-go/suite"
DST="$SUITE/testdata/$NOME"
# o Go quer identificador: rename-local -> rename_local_test.go
GOFILE="$SUITE/$(printf '%s' "$NOME" | tr '-' '_')_test.go"

[ -d "$SRC" ] || { echo "caso-new: fixture '$SRC' não existe"; exit 1; }
[ -e "$DST" ] && { echo "caso-new: '$DST' já existe"; exit 1; }
[ -e "$GOFILE" ] && { echo "caso-new: '$GOFILE' já existe"; exit 1; }

mkdir -p "$DST/source" "$DST/expected"
# o caso é DONO da entrada: cópia, nunca link nem referência à fixture
# compartilhada (entrada compartilhada apodrece calada, tests/README.md §2)
find "$SRC" -maxdepth 1 -type f -exec cp {} "$DST/source/" \;

cat > "$GOFILE" <<EOF
package suite

import "testing"

// TODO: uma linha dizendo o que ESTE caso prova.
func init() {
	registra("$NOME", func(t *testing.T, p *Projeto) {
		// TODO: a invocação. Ex.:
		//   env := p.Roda("rename", "$FIX.hbp", "a.prg:5:10", "nNovo")
		//
		// As duas comparações (o projeto × expected/, o relatado ×
		// outputs.json) são do harness e acontecem depois daqui — escreva
		// só o que é DESTE caso.
	})
}
EOF

echo "caso andado:"
echo "  $(realpath --relative-to="$ROOT" "$GOFILE")"
echo "  tests-go/suite/testdata/$NOME/source/   $(ls "$DST/source" | tr '\n' ' ')"
cat <<EOF

AGORA, e nesta ordem (tests/README.md §3) — o que o script NÃO faz de propósito:

  1. escreva expected/ — TODOS os arquivos de source/, como devem ficar.
     O que o caso edita, você escreve; o que ele promete não tocar, é o
     original copiado. Caso de RECUSA tem expected/ igual ao source/:
         cp tests-go/suite/testdata/$NOME/source/* tests-go/suite/testdata/$NOME/expected/
  2. escreva outputs.json — a LISTA dos envelopes, na ordem dos comandos,
     DO CONTRATO:
         - a coluna se COMPUTA (tools/unit-brief.py já a resolve);
         - o texto da mensagem se LÊ do fonte que a produz;
         - o \`reason\` se ESCOLHE da taxonomia; se o código não existe, ele
           NASCE neste caso — jamais escreva "unclassified": é o campo pelo
           qual o agente decide o que fazer.
  3. escreva a invocação no $(basename "$GOFILE")
  4. make oracle NOME=$NOME   e LEIA o que o core produziu
  5. make caso NOME=$NOME     divergiu? separe os dois lados e diga qual cedeu
  6. migração: tire o unit_N do run.sh (da função E de ALL_UNITS)

O vocabulário da fixture (a régua do caso 64) NÃO se declara: a prova o extrai
das diretivas de source/*.ch sozinha.
EOF
