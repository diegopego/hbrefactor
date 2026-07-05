#!/bin/bash
# porta de precisão da Fase B1: gera dumps ast do corpus e roda o lexdiff
# (AST do compilador vs TokenScan da primeira encarnação) + o comparador de
# paridade occ<->ast quando o binário antigo estiver disponível.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
HB_BIN="${1:?uso: lexdiff.sh <dir HB_BIN com harbour -x ast>}"
HB=${HB:-$HOME/devel/harbour-core/harbour}
OLD_BIN="${OLD_BIN:-}"   # binário da era occ (opcional; aponte p/ um build
                          # do branch feature/refactoring-mechanism se quiser
                          # reativar a paridade occ<->ast — andaime da B1)
D="$HERE/tmp/lexdiff"; rm -rf "$D"; mkdir -p "$D"

CORPUS="$ROOT/tests/fix01/a.prg $ROOT/tests/fix01/b.prg \
        $ROOT/work/hbhttpd/core.prg $ROOT/work/hbhttpd/log.prg $ROOT/work/hbhttpd/widgets.prg"
INCS="-I$ROOT/tests/fix01 -I$HB/include -I$HB/contrib/hbssl -I$ROOT/work/hbhttpd"

for f in $CORPUS; do
   "$HB_BIN/harbour" "$f" -n -q2 -gh -o"$D/tmp.hrb" -x"$D/" $INCS 2>/dev/null
done

"$ROOT/bin/lexdiff" "$D" $CORPUS || exit 1

if [ -n "$OLD_BIN" ] && [ -x "$OLD_BIN/harbour" ] && ! cmp -s "$OLD_BIN/harbour" "$HB_BIN/harbour"; then
   echo "--- paridade occ<->ast:"
   fail=0
   for f in $CORPUS; do
      b=$(basename "$f" .prg)
      "$OLD_BIN/harbour" "$f" -n -q2 -gh -o"$D/o.hrb" -x"$D/$b.occ.json" $INCS 2>/dev/null
      python3 "$HERE/occ_ast_diff.py" "$D/$b.occ.json" "$D/$b.ast.json" | tail -1 || fail=1
   done
   exit $fail
fi
