#!/bin/bash
# ---------------------------------------------------------------------------
# RÉGUA DOS DOIS CANAIS (A.1): a prosa não pode mostrar FATO que o JSON não tem.
#
# A CICATRIZ (Diego, 2026-07-24): *"a prosa a meu ver é apenas um dos argumentos
# de saída; as ferramentas como IDE e o Claude via MCP precisam de dados
# adequados além da prosa"*. Ele estava certo, e a prova era medível: o `usages`
# imprimia
#
#     app.prg:5: call in MAIN  | nTotal += Dobro( 2 )
#                                ^^^^^^^^^^^^^^^^^^^^ a linha do fonte
#
# e o JSON do MESMO comando não carregava esse texto. O consumidor de MÁQUINA
# recebia MENOS que o humano - invertido, porque a IDE precisa dele para o
# preview do find-references e um servidor MCP teria de reabrir o arquivo para
# completar a resposta (o que reprova o critério de matar da fase A.3: adaptador
# não decide nada, e reler arquivo é decidir).
#
# A CAUSA era arquitetural: prosa e JSON eram DOIS CAMINHOS PARALELOS. O certo é
# um conjunto de FATOS, com a prosa como RENDERIZAÇÃO dele - aí divergir vira
# impossível por construção, em vez de depender do meu cuidado.
#
# A régua: para cada `arquivo:linha` que a prosa cita, o JSON tem de trazer uma
# location na mesma linha. Não compara formatação - compara FATO.
# ---------------------------------------------------------------------------
set -u
BIN="${1:?binário do hbrefactor}"
BIN="$( cd "$( dirname "$BIN" )" && pwd )/$( basename "$BIN" )"
FIX="${2:?diretório com um projeto de teste}"
shift 2

D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
cp "$FIX"/* "$D"/ 2>/dev/null

( cd "$D" && "$BIN" "$@"        > prosa.txt 2>/dev/null )
( cd "$D" && "$BIN" "$@" --json > dados.json 2>/dev/null )

# ANTI-VACUIDADE: régua que não mediu nada NÃO passa. (Esta mesma régua já
# passou verde uma vez porque o binário não rodou - sem HB_BIN - e as duas
# listas ficaram vazias. Silêncio não pode parecer sucesso nem aqui dentro.)
[ -s "$D/prosa.txt" ] || { echo "régua-canais: a prosa saiu VAZIA - o comando não rodou"; exit 1; }
grep -q '"schema": "cli-2"' "$D/dados.json" || { echo "régua-canais: o --json não produziu envelope"; exit 1; }

# linhas que a PROSA cita: "<arquivo>:<linha>:" no começo
sed -n 's/^\([A-Za-z0-9_.-]*\.prg\):\([0-9]*\):.*/\1 \2/p' "$D/prosa.txt" | sort -u > "$D/p.txt"

# linhas que o JSON traz (LSP é 0-based; a prosa é 1-based)
python3 - "$D/dados.json" > "$D/j.txt" <<'PYEOF'
import json, sys, os
d = json.load(open(sys.argv[1]))
for l in (d.get("result") or {}).get("locations") or []:
    f = os.path.basename(l["uri"])
    print(f, l["range"]["start"]["line"] + 1)
PYEOF
sort -u "$D/j.txt" -o "$D/j.txt"

faltando=$( comm -23 "$D/p.txt" "$D/j.txt" )
if [ -n "$faltando" ]; then
   echo "a PROSA cita fato que o JSON não tem (o consumidor de máquina recebe MENOS):"
   echo "$faltando" | sed 's/^/  /'
   exit 1
fi

# e o texto da linha: se a prosa mostra o fonte, o dado tem de carregá-lo
if grep -q '  | ' "$D/prosa.txt"; then
   if ! grep -q '"text"' "$D/dados.json"; then
      echo "a PROSA mostra a linha do fonte ('  | ...') e o JSON não tem o campo 'text'"
      echo "  -> a IDE teria de reabrir o arquivo; o MCP teria de DECIDIR (mata a A.3)"
      exit 1
   fi
fi
exit 0
