#!/usr/bin/env bash
# Suite dos EXEMPLOS DA PAGINA (tests/site/).
#
# A regra: exemplo na landing page so existe se ele RODA e a refatoracao e
# PROVADA - mesmo principio dos indicadores (tools/site-numbers.sh): nada de
# transcript digitado a mao, que envelhece calado e mente.
#
# Cada tests/site/<nn-nome>/ tem:
#   app.hbp (+ fontes)   projeto compilavel
#   cmd                  a linha do hbrefactor (sem o binario)
#   show                 qual fonte exibir antes/depois
#   expect               (opcional) exit code esperado; default 0
#
# Para cada exemplo: compila o ANTES (porta), roda o comando, confere o exit,
# compila o DEPOIS (porta) e emite o bloco HTML entre marcadores do index.html.
#
#   site-examples.sh            regenera os blocos no site/index.html
#   site-examples.sh --check    FALHA se algum bloco estiver defasado
set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
HB_BIN="${HB_BIN:-$HOME/devel/harbour-core/harbour/bin/linux/gcc}"
BIN="${BIN:-$HERE/bin/hbrefactor}"
HBMK2="$HB_BIN/hbmk2"
PAGE="$HERE/site/index.html"
SITEDIR="$HERE/tests/site"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

[ -x "$BIN" ] || { echo "site-examples: $BIN ausente - rode 'make build'"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FRAG="$TMP/frags"
mkdir -p "$FRAG"
FAILED=0

for dir in "$SITEDIR"/*/; do
   name="$(basename "$dir")"
   [ -f "$dir/cmd" ] || continue
   cmd="$(cat "$dir/cmd")"
   show="$(cat "$dir/show")"
   expect=0
   [ -f "$dir/expect" ] && expect="$(cat "$dir/expect")"
   kind=refactor
   [ -f "$dir/kind" ] && kind="$(cat "$dir/kind")"

   w="$TMP/$name"
   mkdir -p "$w"
   cp "$dir"/* "$w"/ 2>/dev/null
   rm -f "$w/cmd" "$w/show" "$w/expect" "$w/kind"

   cp "$w/$show" "$TMP/$name.before"

   # PORTA 1: o ANTES tem de compilar limpo (fixture que nao compila mente)
   ( cd "$w" && "$HBMK2" app.hbp -q0 -s > "$TMP/$name.build0" 2>&1 )
   if [ $? -ne 0 ]; then
      echo "site-examples: FALHA [$name] o fonte ANTES nao compila:"
      sed 's/^/    /' "$TMP/$name.build0"
      FAILED=1; continue
   fi

   # roda a refatoracao
   ( cd "$w" && HB_BIN="$HB_BIN" "$BIN" $cmd > "$TMP/$name.out" 2>&1 )
   rc=$?
   if [ "$rc" -ne "$expect" ]; then
      echo "site-examples: FALHA [$name] exit $rc (esperado $expect):"
      sed 's/^/    /' "$TMP/$name.out"
      FAILED=1; continue
   fi

   cp "$w/$show" "$TMP/$name.after"

   # PORTA 2: o DEPOIS tem de compilar limpo (a refatoracao e PROVADA)
   ( cd "$w" && "$HBMK2" app.hbp -q0 -s > "$TMP/$name.build1" 2>&1 )
   if [ $? -ne 0 ]; then
      echo "site-examples: FALHA [$name] o fonte DEPOIS nao compila:"
      sed 's/^/    /' "$TMP/$name.build1"
      FAILED=1; continue
   fi

   # PORTA 3: recusa OU relatorio tem de deixar o fonte INTACTO
   if [ "$expect" -ne 0 ] || [ "$kind" = "report" ]; then
      if ! cmp -s "$TMP/$name.before" "$TMP/$name.after"; then
         echo "site-examples: FALHA [$name] recusou mas MEXEU no fonte"
         FAILED=1; continue
      fi
   fi

   python3 "$HERE/tools/site-examples-emit.py" \
      "$name" "$show" "$cmd" \
      "$TMP/$name.before" "$TMP/$name.after" "$TMP/$name.out" "$expect" "$kind" \
      > "$FRAG/$name.html" || { echo "site-examples: FALHA [$name] emit"; FAILED=1; }
done

[ "$FAILED" -eq 0 ] || { echo "site-examples: exemplos REPROVADOS - a pagina nao foi tocada"; exit 1; }

python3 "$HERE/tools/site-examples-inject.py" "$PAGE" "$FRAG" "$CHECK"
