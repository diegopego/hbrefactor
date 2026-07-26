#!/bin/bash
# ---------------------------------------------------------------------------
# CENÁRIO - o formato NOVO de teste (Diego, 2026-07-26), e o destino de TODOS
# os testes da suíte. Um cenário é uma frase completa, num diretório só:
#
#    tests/scenarios/<nome>/
#       case.json   os ESCALARES (não se beneficiam de diff), COM SCHEMA:
#                      schema:  "case-1" - exato; divergir BERRA (lei §1.5)
#                      kind:    "command" (roda o hbrefactor). Os outros tipos
#                               entram junto com o código que os executa
#                      desc:    uma linha - o que este cenário prova
#                      cmd:     a linha do hbrefactor SEM o binário, ou uma
#                               LISTA delas (A->B->A e afins), rodadas em ordem
#                      creates: (opcional) artefatos que o comando pode deixar
#                      forbid:  (opcional) o vocabulário desta fixture, que NÃO
#                               pode aparecer em src/hbrefactor.prg (caso 64)
#       source/     o projeto ANTES - todos os arquivos
#       expected/   os arquivos DEPOIS, escritos À MÃO; SÓ os que mudam
#       output      a TRANSCRIÇÃO esperada, byte a byte: por comando, a linha
#                   `$ hbrefactor <cmd>`, a saída, e `-> exit N`
#       oracle/     o RETRATO do .ppo/.ppt que o core produz para a `source/`
#                   (gravado do core por `make oracle`, nunca escrito à mão)
#
# POR QUE O `case` É JSON COM SCHEMA (Diego, 2026-07-26): a validação é o
# produto, não a leitura. Em "chave: valor" solto, um `exitt:` por engano é
# ignorado em SILÊNCIO e o cenário passa provando outra coisa - a vacuidade que
# este formato existe para matar. O `tcheck scen` recusa schema ausente/errado,
# chave desconhecida, obrigatória faltando e tipo errado.
#
# A ORDEM É TDD (Diego): *"escreve os arquivos expected, depois escreve o
# arquivo que vai ser alterado, e compara a saída do actual vs expected"*. O
# `expected/` e o `output` se escrevem À MÃO, ANTES, do CONTRATO - nunca se
# GRAVAM de uma execução. Os dois arquivos ficam idênticos; os dois testes,
# não: gravado, o esperado afirma "a ferramenta faz isto hoje" (e congela o
# defeito atual); escrito, ele afirma "o contrato pede isto" (e o defeito vira
# FALHA). É PROIBIDA ferramenta que grave esperado. [cicatrizes §6.4]
#
# AUSÊNCIA DE `expected/` TEM SIGNIFICADO: é a promessa de que NADA muda - o
# cenário é de recusa ou de consulta, e o projeto inteiro volta byte a byte.
#
# AS SEIS PROVAS de cada cenário:
#   1. o exit bate;
#   2. TODO arquivo de `source/` bate byte a byte com o esperado - com
#      `expected/<arquivo>` onde o cenário edita, e com o próprio `source/`
#      onde não edita (é isto que prova o que a ferramenta NÃO tocou);
#   3. `expected/` que nomeie arquivo fora de `source/` REPROVA - nunca seria
#      comparado, e passaria por vacuidade (a cicatriz que criou o formato);
#   4. arquivo NOVO no projeto que o `case` não declarou em `creates:` reprova
#      (a ferramenta não suja o projeto do usuário);
#   5. a saída bate byte a byte com `output` - o que prova também o que a
#      ferramenta NÃO disse (um aviso a mais reprova, e é para reprovar);
#   6. o projeto DEPOIS compila limpo sob -w3 -es2. Esta é a rede do método:
#      esperado escrito à mão tem erro de digitação, e sem ela o erro vira uma
#      falha que se "conserta" regravando - que é o golden-file voltando pela
#      janela.
#
# Falha mostra DIFF, nunca "um grep não casou".
# ---------------------------------------------------------------------------
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="${BIN:-$HERE/../bin/hbrefactor}"
TCHECK="${TCHECK:-$HERE/../bin/tcheck}"
CASE_SCHEMA="case-1"              # a versão do formato de `case.json` que ESTE runner honra
DIR="${SCENARIOS:-$HERE/scenarios}"
[ -x "$TCHECK" ] || { echo "tcheck ausente ($TCHECK) - rode via make scenarios"; exit 1; }
export HB_BIN="${HB_BIN:?HB_BIN must point to the harbour binaries dir (branch feature/compiler-ast-dump)}"
CORE="$(cd "$HB_BIN/../../.." && pwd)"

PASS=0
FAIL=0

note()  { printf '  %s\n' "$*"; }
check() { # check <desc> <cond-exit>
   if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); note "ok:   $1"
   else FAIL=$((FAIL+1)); note "FAIL: $1"; fi
}

# meta <dir> <chave> -> valida o case.json INTEIRO e ecoa a chave. Validar a
# cada leitura é de propósito: assim nenhum runner futuro pode esquecer.
meta() { "$TCHECK" scen "$1/case.json" "$2"; }

# gera .ppo/.ppt de cada módulo da `source/` num diretório - o retrato do que o
# pré-compilador e o compilador fizeram. `-p` escreve o .ppo (o código depois
# do pp), `-p+` escreve o .ppt (o rastro: cada aplicação de diretiva, com a
# linha do fonte). `-s` = só sintaxe, sem gerar código.
scen_artifacts() { # scen_artifacts <dir-com-a-source> <destino>
   local src="$1" dst="$2" f
   rm -rf "$dst"; mkdir -p "$dst"
   cp "$src"/* "$dst"/ 2>/dev/null
   for f in "$dst"/*.prg; do
      [ -f "$f" ] || continue
      ( cd "$dst" && "$HB_BIN/harbour" "$(basename "$f")" -n -q0 -s -p -p+ \
           -I"$dst" -I"$CORE/include" > /dev/null 2>&1 )
   done
}

# scen_oracle <dir-do-cenário> <nome> -> compara o retrato com oracle/
scen_oracle() {
   local dir="$1" name="$2" g="$HERE/tmp/oracle-$2" f base bad=0 n=0 ok
   scen_artifacts "$dir/source" "$g"
   if [ ! -d "$dir/oracle" ]; then
      echo "    --- sem oracle/: rode 'make oracle NOME=$name' e REVISE o que o core produziu ---"
      check "retrato do .ppo/.ppt do core (oracle/)" 1
      return 0
   fi
   for f in "$g"/*.ppo "$g"/*.ppt; do
      [ -f "$f" ] || continue
      n=$((n+1))
      base="$(basename "$f")"
      if [ ! -f "$dir/oracle/$base" ]; then
         bad=1; echo "    --- oracle/$base não existe (o core produziu um artefato novo) ---"
      elif ! cmp -s "$dir/oracle/$base" "$f"; then
         bad=1
         echo "    --- o core mudou: diff de $base (retrato < , agora >) ---"
         diff "$dir/oracle/$base" "$f" | head -20 | sed 's/^/    /'
      fi
   done
   for f in "$dir"/oracle/*; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      if [ ! -f "$g/$base" ]; then
         bad=1; echo "    --- oracle/$base já não é produzido pelo core ---"
      fi
   done
   # ANTI-VACUIDADE: cenário cujo compilador não emitiu artefato nenhum não
   # pode passar nesta prova por não ter o que comparar
   [ "$n" -gt 0 ] || { bad=1; echo "    --- o compilador não emitiu .ppo/.ppt nenhum ---"; }
   [ "$bad" = 0 ]; ok=$?
   check "o .ppo/.ppt do core batem com o retrato em oracle/" $ok
}

run_scenario() { # run_scenario <dir-do-cenário>
   local dir="$1" name; name="$(basename "$dir")"
   local d="$HERE/tmp/scen-$name"
   local cmd got_exit creates f base exp bad ok

   # o case.json é a IDENTIDADE do cenário: inválido, nada mais faz sentido
   if ! "$TCHECK" scen "$dir/case.json"; then
      echo "scenario $name:"
      check "case.json válido (schema $CASE_SCHEMA, chaves conhecidas)" 1
      return 0
   fi

   creates=" $(meta "$dir" creates | tr '\n' ' ') "

   echo "scenario $name: $(meta "$dir" desc)"

   rm -rf "$d"; mkdir -p "$d"
   cp "$dir"/source/* "$d"/ 2>/dev/null

   # os comandos rodam EM ORDEM, dentro do tmp (caminhos relativos na saída), e
   # o resultado é uma TRANSCRIÇÃO: comando, saída e exit de cada um. É por isso
   # que não existe chave `exit` no case.json - com N comandos o exit é por
   # comando, e o lugar dele é aqui, comparado byte a byte junto com a saída.
   : > "$d/out.log"
   while IFS= read -r cmd; do
      [ -n "$cmd" ] || continue
      ( cd "$d" && eval "\"$BIN\" $cmd" > out.raw 2>&1 )
      got_exit=$?
      # NORMALIZAÇÃO do que é legitimamente variável por máquina: o diretório do
      # cenário (<CWD>) e a árvore do harbour-core (<CORE>) - o `uri` do formato
      # LSP é ABSOLUTO por contrato, e o core muda de lugar entre máquinas (o
      # tools/hbenv.sh detecta dois layouts). Só ESTES DOIS: o resto é drift.
      printf '$ hbrefactor %s\n' "$cmd" >> "$d/out.log"
      sed -e "s|$d|<CWD>|g" -e "s|$CORE|<CORE>|g" "$d/out.raw" >> "$d/out.log"
      printf -- '-> exit %s\n' "$got_exit" >> "$d/out.log"
   done < <( meta "$dir" cmd )
   rm -f "$d/out.raw"

   # (2)+(3) os fontes: expected/ onde edita, source/ onde não
   bad=0
   for f in "$dir"/source/*; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      exp="$f"
      [ -f "$dir/expected/$base" ] && exp="$dir/expected/$base"
      if ! cmp -s "$exp" "$d/$base"; then
         bad=1
         echo "    --- diff de $base (esperado < , obtido >) ---"
         diff "$exp" "$d/$base" | head -20 | sed 's/^/    /'
      fi
   done
   for f in "$dir"/expected/*; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      if [ ! -f "$dir/source/$base" ]; then
         bad=1
         echo "    --- expected/$base não existe em source/: nunca seria comparado ---"
      fi
   done
   # o `if` abaixo SOBRESCREVE o $? - guardar o veredito antes é obrigatório.
   # (Escrevi errado na primeira versão: o `check` recebia o exit do próprio
   # `if`, sempre 0, e a prova passava por VACUIDADE - dentro do runner que
   # existe justamente para matar vacuidade. Foi o shellcheck do editor que
   # pegou. Régua: `$?` nunca atravessa um comando, nem que seja um `[`.)
   [ "$bad" = 0 ]; ok=$?
   if [ -d "$dir/expected" ]; then
      check "o projeto depois bate com expected/ (e o resto intacto)" $ok
   else
      check "NADA EDITADO: o projeto inteiro volta byte a byte" $ok
   fi

   # (4) artefato não declarado: a ferramenta não suja o projeto do usuário
   bad=0
   for f in "$d"/*; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      case "$base" in out.raw|out.log ) continue ;; esac
      [ -f "$dir/source/$base" ] && continue
      case "$creates" in *" $base "* ) continue ;; esac
      bad=1
      echo "    --- arquivo NOVO não declarado em creates: $base ---"
   done
   [ "$bad" = 0 ]; ok=$?
   check "nenhum artefato inesperado no projeto" $ok

   # (5) a saída INTEIRA - prova também o que a ferramenta não disse
   if [ -f "$dir/output" ]; then
      cmp -s "$dir/output" "$d/out.log"; ok=$?
      if [ "$ok" -ne 0 ]; then
         echo "    --- diff da saída (esperado < , obtido >) ---"
         diff "$dir/output" "$d/out.log" | head -30 | sed 's/^/    /'
      fi
      check "a saída bate byte a byte com output" $ok
   else
      check "o cenário declara a saída esperada (arquivo output)" 1
   fi

   # (6) o RETRATO do que o pré-compilador e o compilador fizeram com a
   # `source/`: `.ppo` (no que o código vira) e `.ppt` (o que o pp fez, linha a
   # linha). Duas funções, e a segunda é a que o Diego pediu (2026-07-26):
   #   - RASTREAR o core: mexeu no pp e o caso mostra o diff, legível, de 30
   #     linhas - e atualizar o retrato vira ato deliberado, revisado no commit;
   #   - ESTUDAR: ao ler um caso, ver o que o pp fez ali é metade do
   #     entendimento, e é onde a LACUNA do core aparece (falta informação no
   #     .ppt? então o conserto é estender o core, não adivinhar na ferramenta).
   # Retrato do CORE se GRAVA do core (`make oracle NOME=<caso>`) - ali a
   # autoridade é ele, não nós. Isto NÃO abre exceção para o `expected/`/`output`,
   # que são afirmação NOSSA e continuam escritos à mão. [cicatrizes §6.4]
   scen_oracle "$dir" "$name"

   # (7) o vocabulário desta fixture NÃO pode aparecer no fonte da ferramenta
   # (a régua do caso 64). Fica no caso que INTRODUZ o vocabulário: antes era um
   # check solto, longe da fixture, que quem criasse fixture nova tinha de
   # lembrar de escrever.
   local words; words="$(meta "$dir" forbid)"
   if [ -n "$words" ]; then
      bad=0
      while IFS= read -r f; do
         [ -n "$f" ] || continue
         if grep -qiE "\\b$f\\b" "$HERE/../src/hbrefactor.prg"; then
            bad=1
            echo "    --- '$f' (vocabulário da fixture) aparece em src/hbrefactor.prg ---"
         fi
      done <<< "$words"
      [ "$bad" = 0 ]; ok=$?
      check "nenhuma palavra da fixture no fonte da ferramenta (régua do caso 64)" $ok
   fi

   # (8) o projeto QUE O CENÁRIO AFIRMA compila limpo. Repare: compila o
   # `source/` + `expected/` por cima - o estado que EU escrevi -, NUNCA o que
   # a ferramenta produziu. É essa a rede do método: se o meu esperado tiver um
   # erro de digitação, a prova (2) falha e eu ficaria tentado a "consertar"
   # copiando a saída da ferramenta - que é o golden-file voltando pela janela.
   # Aqui o cenário diz, sozinho, qual dos dois lados está quebrado.
   local c="$d.claim"
   rm -rf "$c"; mkdir -p "$c"
   cp "$dir"/source/* "$c"/ 2>/dev/null
   cp "$dir"/expected/* "$c"/ 2>/dev/null
   bad=0
   for f in "$c"/*.prg; do
      [ -f "$f" ] || continue
      "$HB_BIN/harbour" "$f" -n -q0 -w3 -es2 -s -I"$c" -I"$CORE/include" > "$c/.cc.log" 2>&1 || {
         bad=1
         echo "    --- $(basename "$f") do estado AFIRMADO não compila ---"
         head -10 "$c/.cc.log" | sed 's/^/    /'
      }
   done
   [ "$bad" = 0 ]; ok=$?
   check "o projeto que o cenário afirma compila limpo (-w3 -es2)" $ok

   return 0
}

# ---------------------------------------------------------------------------
# despacho: os cenários são AUTO-DESCOBERTOS (o diretório é a lista - não há
# registro central para desatualizar). Um argumento roda só aquele.
# ---------------------------------------------------------------------------
# MODO GRAVAÇÃO do retrato do core (`make oracle NOME=x`): o único lugar do
# repo onde um esperado se GRAVA - e só porque ali a autoridade é o core, não
# nós. Nunca toca em expected/ nem em output.
if [ "${1:-}" = "--oracle" ]; then
   shift
   for s in "$DIR"/*/; do
      [ -d "$s" ] || continue
      [ $# -gt 0 ] && [ -n "${1:-}" ] && [ "$(basename "$s")" != "$1" ] && continue
      nm="$(basename "$s")"
      scen_artifacts "${s}source" "$HERE/tmp/oracle-$nm"
      rm -rf "${s}oracle"; mkdir -p "${s}oracle"
      cp "$HERE/tmp/oracle-$nm"/*.ppo "$HERE/tmp/oracle-$nm"/*.ppt "${s}oracle"/ 2>/dev/null
      echo "retrato gravado: $nm -> $(ls "${s}oracle" | tr '\n' ' ')"
   done
   exit 0
fi

mkdir -p "$HERE/tmp"
n=0
for s in "$DIR"/*/; do
   [ -d "$s" ] || continue
   [ $# -gt 0 ] && [ "$(basename "$s")" != "$1" ] && continue
   run_scenario "${s%/}"
   n=$((n+1))
done

echo
if [ "$n" -eq 0 ]; then
   # ANTI-VACUIDADE: runner que não mediu nada NÃO passa. Silêncio nunca pode
   # parecer sucesso (já aconteceu 3x com as réguas desta fase).
   echo "nenhum cenário rodou em $DIR${1+ (filtro: $1)} - isto é FALHA, não sucesso"
   exit 1
fi
echo "scenarios: $n  passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
