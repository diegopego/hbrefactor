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
#      cmd         a linha do hbrefactor, SEM o binário
#      after/      o projeto ESPERADO depois (só os arquivos que importam)
#      exit        (opcional) exit code esperado; default 0
#      out         (opcional) a saída esperada (stdout+stderr), byte a byte
#
# As três provas de cada caso, e a terceira é a que o grep nunca deu:
#   1. o exit bate;
#   2. TODO arquivo de after/ bate BYTE A BYTE com o resultado;
#   3. a saída bate byte a byte com out/ - o que prova também o que a
#      ferramenta NÃO disse (aviso a mais reprova, e é para reprovar mesmo).
#
# Um caso sem `after/` é de RECUSA/RELATO: o before/ inteiro tem de voltar
# byte a byte (nada editado), que é a promessa central da ferramenta.
#
# Falha mostra DIFF, nunca "FAIL: um grep não casou".
# ---------------------------------------------------------------------------

# run_casedir <dir-do-caso>  -> roda e emite os `check` do caso
run_casedir() {
   local dir="$1" name; name="$(basename "$dir")"
   local d="$HERE/tmp/case-$name"
   local exp_exit=0 got_exit

   echo "case $name: $(head -1 "$dir/desc" 2>/dev/null || echo "caso declarativo")"

   rm -rf "$d"; mkdir -p "$d"
   cp "$dir"/before/* "$d"/ 2>/dev/null
   [ -f "$dir/exit" ] && exp_exit="$(tr -d ' \n' < "$dir/exit")"

   # o comando roda DENTRO do tmp: caminhos relativos na saída (sem tmpdir)
   ( cd "$d" && eval "\"$BIN\" $(cat "$dir/cmd")" > out.log 2>&1 )
   got_exit=$?
   [ "$got_exit" = "$exp_exit" ]
   check "exit $got_exit == esperado $exp_exit" $?

   # (2) os fontes: after/ quando edita, before/ quando recusa ou só relata
   local ref="$dir/after" what="o fonte depois bate byte a byte com after/"
   if [ ! -d "$ref" ]; then
      ref="$dir/before"; what="RECUSA/RELATO: os fontes voltam byte a byte (nada editado)"
   fi
   local f base bad=0
   for f in "$ref"/*; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      if ! cmp -s "$f" "$d/$base"; then
         bad=1
         echo "    --- diff de $base (esperado < , obtido >) ---"
         diff "$f" "$d/$base" | head -20 | sed 's/^/    /'
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
