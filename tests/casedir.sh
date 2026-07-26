#!/bin/bash
# ---------------------------------------------------------------------------
# CASO DECLARATIVO - o formato de teste que substitui o grep em saída.
#
# POR QUÊ (a cicatriz, 2026-07-24): o run.sh chegou a 1.006 asserções, 637
# delas `grep -q` em texto de saída. Duas falhas típicas apareceram na MESMA
# hora, e nenhuma delas era sobre a ferramenta:
#   (a) um `grep` que passava por VACUIDADE - o padrão nunca casaria com a
#       saída real, então o check era verde sem provar nada;
#   (b) uma fixture usando a palavra `Conta`, que é português comum no fonte,
#       quebrando a régua do caso 64 por colisão de vocabulário.
# Um `grep` prova que UM pedaço da saída existe; ele nunca prova o que a
# ferramenta NÃO fez, e é exatamente isso que este produto promete.
#
# O FORMATO (ordem do Diego: "usar fixtures expected para cada teste"):
#
#   tests/cases/<nome>/
#      before/     o projeto ANTES (.prg, .ch, .hbp) - copiado para um tmp
#      fixture     (alternativa a before/) o NOME de uma fixture compartilhada
#                  de tests/ (ex.: `fixdsl`) - a ENTRADA vem de lá
#      cmd         a linha do hbrefactor, SEM o binário
#      after/      o projeto ESPERADO depois (só os arquivos que a ferramenta edita)
#      exit        (opcional) exit code esperado; default 0
#      out         (opcional) a saída esperada (stdout+stderr), byte a byte
#
# As três provas de cada caso, e a terceira é a que o grep nunca deu:
#   1. o exit bate;
#   2. TODO arquivo de ENTRADA bate BYTE A BYTE com o esperado - com `after/`
#      onde o caso edita, e com a própria ENTRADA onde não edita;
#   3. a saída bate byte a byte com out/ - o que prova também o que a
#      ferramenta NÃO disse (aviso a mais reprova, e é para reprovar mesmo).
#
# Um caso sem `after/` é de RECUSA/RELATO: a entrada inteira tem de voltar
# byte a byte (nada editado), que é a promessa central da ferramenta.
#
# POR QUE `fixture` (2026-07-25): sem ela, migrar um assert de prosa para caso
# declarativo obriga a DUPLICAR o projeto de entrada (o before/ do caso 137 era
# cópia byte a byte de tests/fixdsl/). Duplicata de entrada apodrece: conserta-se
# a fixture compartilhada e o caso segue provando o mundo velho, calado. A
# ENTRADA é insumo, não expectativa - o que o caso possui é o `after/` e o `out`.
#
# POR QUE comparar TODO arquivo de entrada (2026-07-25): antes, um caso com
# `after/` conferia SÓ os arquivos listados lá - a ferramenta podia editar
# qualquer outro módulo do projeto sem ninguém ver. `after/` que nomeie arquivo
# fora da entrada REPROVA (senão um nome errado passa por vacuidade, que é a
# cicatriz que criou este formato).
#
# Falha mostra DIFF, nunca "FAIL: um grep não casou".
# ---------------------------------------------------------------------------

# casedir_input <dir-do-caso> -> ecoa o diretório de ENTRADA do caso
casedir_input() {
   local dir="$1"
   if [ -f "$dir/fixture" ]; then echo "$HERE/$(tr -d ' \n' < "$dir/fixture")"
   else echo "$dir/before"; fi
}

# casedir_exec <dir-do-caso> <workdir> -> monta a entrada, roda o comando,
# normaliza a saída em <workdir>/out.log e DEVOLVE o exit real.
# Uma implementação só, porque o gravador (tools/mkcase.sh) roda por aqui
# também: recorder e verificador que divergem gravam o que nunca vai casar.
casedir_exec() {
   local dir="$1" d="$2" inp; inp="$(casedir_input "$dir")"
   rm -rf "$d"; mkdir -p "$d"
   cp "$inp"/* "$d"/ 2>/dev/null
   # o comando roda DENTRO do tmp: caminhos relativos na saída (sem tmpdir)
   ( cd "$d" && eval "\"$BIN\" $(cat "$dir/cmd")" > out.raw 2>&1 )
   local rc=$?
   # NORMALIZAÇÃO do que é legitimamente variável por máquina. O `uri` do
   # formato LSP é ABSOLUTO por contrato (a extensão VSCode precisa dele
   # assim), então a fixture guarda <CWD> no lugar do diretório do caso e
   # <CORE> no lugar da árvore do harbour-core (que muda de layout entre
   # máquinas - o tools/hbenv.sh detecta dois). Só ESTES DOIS se normalizam:
   # qualquer outra variação é drift de verdade.
   # (A LINHA dentro de um include do core NÃO se normaliza: ela é fato do
   # core com que a suíte roda, e se mudar é para BERRAR - §1.5 da lei.)
   local core; core="$(cd "$HB_BIN/../../.." 2>/dev/null && pwd)"
   sed -e "s|$d|<CWD>|g" -e "s|${core:-__sem_core__}|<CORE>|g" "$d/out.raw" > "$d/out.log"
   return $rc
}

# run_casedir <dir-do-caso>  -> roda e emite os `check` do caso
run_casedir() {
   local dir="$1" name; name="$(basename "$dir")"
   local d="$HERE/tmp/case-$name"
   local exp_exit=0 got_exit
   local inp; inp="$(casedir_input "$dir")"

   echo "case $name: $(head -1 "$dir/desc" 2>/dev/null || echo "caso declarativo")"

   [ -f "$dir/exit" ] && exp_exit="$(tr -d ' \n' < "$dir/exit")"
   casedir_exec "$dir" "$d"
   got_exit=$?
   [ "$got_exit" = "$exp_exit" ]
   check "exit $got_exit == esperado $exp_exit" $?

   # (2) os fontes: TODO arquivo de entrada, com after/ onde o caso edita e a
   #     própria entrada onde não - assim o caso prova também o que a ferramenta
   #     NÃO tocou (um módulo editado por engano fora do after/ reprova aqui)
   local what="o fonte depois bate byte a byte com after/ (e o resto intacto)"
   [ -d "$dir/after" ] || what="RECUSA/RELATO: os fontes voltam byte a byte (nada editado)"
   local f base exp bad=0
   for f in "$inp"/*; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      exp="$f"
      [ -f "$dir/after/$base" ] && exp="$dir/after/$base"
      if ! cmp -s "$exp" "$d/$base"; then
         bad=1
         echo "    --- diff de $base (esperado < , obtido >) ---"
         diff "$exp" "$d/$base" | head -20 | sed 's/^/    /'
      fi
   done
   # after/ que nomeie arquivo fora da entrada nunca seria comparado: passaria
   # por VACUIDADE (a cicatriz que criou este formato). Reprova.
   for f in "$dir"/after/*; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      if [ ! -f "$inp/$base" ]; then
         bad=1
         echo "    --- after/$base não existe na entrada ($inp): nunca seria comparado ---"
      fi
   done
   [ "$bad" = 0 ]
   check "$what" $?

   # (3) a saída INTEIRA - prova também o que a ferramenta não disse
   if [ -f "$dir/out" ]; then
      if ! cmp -s "$dir/out" "$d/out.log"; then
         echo "    --- diff da saída (esperado < , obtido >) ---"
         diff "$dir/out" "$d/out.log" | head -20 | sed 's/^/    /'
         false
      else
         true
      fi
      check "a saída bate byte a byte com out" $?
   fi

   return 0
}
