#!/bin/bash
# hbrefactor test runner - Phase 0 fixtures
# Every fixture is a PROJECT (>= 2 .prg + shared .ch + .hbp): the tool must
# prove it operates at project level, never on a lone file.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="${BIN:-$HERE/../bin/hbrefactor}"
export HB_BIN="${HB_BIN:?HB_BIN must point to the harbour binaries dir}"

PASS=0
FAIL=0

note()  { printf '  %s\n' "$*"; }
check() { # check <desc> <cond-exit>
   if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); note "ok:   $1"
   else FAIL=$((FAIL+1)); note "FAIL: $1"; fi
}

fresh() { # fresh <case-name> -> echoes work dir
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fix01/*.prg "$HERE"/fix01/*.ch "$HERE"/fix01/*.hbp "$d"/
   echo "$d"
}

echo "case 1: rename nTotal->nSoma in Main (success + verification)"
D=$(fresh case1)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Main nTotal nSoma > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
diff -q "$D/a.prg" "$HERE/fix01/expected/a_renamed.prg" > /dev/null 2>&1
check "a.prg matches expected"     $?
cmp -s "$D/b.prg" "$HERE/fix01/b.prg"
check "b.prg untouched"            $?
grep -q "verified: all 2 module" "$D/out.log"
check "reports 2 modules verified" $?

echo "case 2: collision with existing local (refuse)"
D=$(fresh case2)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Main nTotal i > out.log 2>&1 )
RC=$?
check "exit != 0"                  $([ $RC -ne 0 ] && echo 0 || echo 1)
cmp -s "$D/a.prg" "$HERE/fix01/a.prg"
check "a.prg untouched"            $?

echo "case 3: unrelated #define on the declaration line (safe rename succeeds)"
D=$(fresh case3)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg LimiteMax nMax nTeto > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "nTeto := K_LIMITE" "$D/a.prg"
check "nTeto renamed, define kept" $?
grep -q "verified: all 2 module" "$D/out.log"
check "verification passed"        $?

echo "case 4: new name is reserved word written as 'nIL' (refuse)"
D=$(fresh case4)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Main nTotal nIL > out.log 2>&1 )
RC=$?
check "exit != 0"                  $([ $RC -ne 0 ] && echo 0 || echo 1)

echo "case 5: homonymous codeblock parameter shadows target (refuse)"
D=$(fresh case5)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Sombra xVal xNovo > out.log 2>&1 )
RC=$?
check "exit != 0"                  $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -qi "shadow" "$D/out.log"
check "reason mentions shadowing"  $?
cmp -s "$D/a.prg" "$HERE/fix01/a.prg"
check "a.prg untouched"            $?

echo "case 6: variable does not exist (refuse)"
D=$(fresh case6)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Main naoExiste nQualquer > out.log 2>&1 )
RC=$?
check "exit != 0"                  $([ $RC -ne 0 ] && echo 0 || echo 1)

echo "case 7: symbol consumed by stringify marker - verification must roll back"
D=$(fresh case7)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Rotulada nVisto nOutro > out.log 2>&1 )
RC=$?
check "exit != 0"                  $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -qi "rolled back" "$D/out.log"
check "reports rollback"           $?
cmp -s "$D/a.prg" "$HERE/fix01/a.prg"
check "a.prg restored byte-exact"  $?

echo "case 8: usages of a function across modules"
D=$(fresh case8)
( cd "$D" && "$BIN" usages fix01.hbp Dupla > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "b.prg:5: definition (function)" "$D/out.log"
check "definition found in b.prg"  $?
grep -q "a.prg:10: call in MAIN" "$D/out.log"
check "call found in a.prg (Main)" $?

echo "case 9: usages of a local variable (scope-aware, incl. codeblock)"
D=$(fresh case9)
( cd "$D" && "$BIN" usages fix01.hbp nTotal --func Main > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "a.prg:5: declaration (local) in MAIN" "$D/out.log"
check "declaration listed"         $?
grep -q "a.prg:6: ref (detached, codeblock) in MAIN" "$D/out.log"
check "detached codeblock capture listed" $?
grep -q "a.prg:13: read (local) in MAIN" "$D/out.log"
check "read listed"                $?

echo "case 10: rename-function across modules + idempotence (A->B->A)"
D=$(fresh case10)
( cd "$D" && "$BIN" rename-function fix01.hbp Dupla Dobrar > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "FUNCTION Dobrar( nV )" "$D/b.prg"
check "definition renamed (b.prg)" $?
grep -q "Dobrar( i )" "$D/a.prg"
check "call renamed (a.prg)"       $?
grep -q "pcode byte-identical" "$D/out.log"
check "structural verification"    $?
( cd "$D" && "$BIN" rename-function fix01.hbp Dobrar Dupla > out2.log 2>&1 )
cmp -s "$D/a.prg" "$HERE/fix01/a.prg" && cmp -s "$D/b.prg" "$HERE/fix01/b.prg"
check "idempotence: A->B->A restores sources" $?

echo "case 11: string literal with the function name (refuse without --force)"
D=$(fresh case11)
printf '\nFUNCTION NomeEmTexto()\n\n   RETURN "Dupla"\n' >> "$D/a.prg"
( cd "$D" && "$BIN" rename-function fix01.hbp Dupla Dobrar > out.log 2>&1 )
RC=$?
check "exit != 0 without --force"  $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "string equals 'Dupla' - likely a call by name" "$D/out.log"
check "warning classifies exact-name string" $?
( cd "$D" && "$BIN" usages fix01.hbp Dupla > usages.log 2>&1 )
grep -q "possible reference in string" "$D/usages.log"
check "usages reports the string reference" $?
( cd "$D" && "$BIN" rename-function fix01.hbp Dupla Dobrar --force > out2.log 2>&1 )
RC=$?
check "exit 0 with --force"        $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q '"Dupla"' "$D/a.prg"
check "string left untouched"      $?
grep -q "FUNCTION Dobrar( nV )" "$D/b.prg"
check "definition renamed"         $?

echo "case 12: STATIC FUNCTION renamed inside its module only"
D=$(fresh case12)
( cd "$D" && "$BIN" rename-function fix01.hbp Meio Metade > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "STATIC FUNCTION Metade( nN )" "$D/b.prg"
check "static definition renamed"  $?
grep -q "Metade( nV ) + Metade( nV )" "$D/b.prg"
check "internal calls renamed"     $?
cmp -s "$D/a.prg" "$HERE/fix01/a.prg"
check "a.prg untouched"            $?

echo "case 13: rename-param (parameter is a local; non-param refused)"
D=$(fresh case13)
( cd "$D" && "$BIN" rename-param fix01.hbp b.prg Dupla nV nValor > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "FUNCTION Dupla( nValor )" "$D/b.prg"
check "parameter renamed in signature" $?
grep -q "nValor + nValor" "$D/b.prg"
check "parameter renamed in body"  $?
( cd "$D" && "$BIN" rename-param fix01.hbp b.prg Dupla nR nRes > out2.log 2>&1 )
RC=$?
check "non-parameter refused"      $([ $RC -ne 0 ] && echo 0 || echo 1)

echo "case 14: reorder-params preserves behavior (program output identical)"
D=$(fresh case14)
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
( cd "$D" && "$BIN" reorder-params fix01.hbp Sub2 nB,nA > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "FUNCTION Sub2( nB, nA )" "$D/b.prg"
check "definition reordered"       $?
grep -q "Sub2( 3, 10 )" "$D/a.prg"
check "call site arguments swapped" $?
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
diff -q "$D/saida_antes.txt" "$D/saida_depois.txt" > /dev/null 2>&1
check "program output identical"   $?

echo "case 15: reorder-params refuses call site with fewer arguments"
D=$(fresh case15)
printf '\nFUNCTION ChamaCurta()\n\n   RETURN Sub2( 5 )\n' >> "$D/a.prg"
( cd "$D" && "$BIN" reorder-params fix01.hbp Sub2 nB,nA > out.log 2>&1 )
RC=$?
check "exit != 0"                  $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "implicit NIL would move" "$D/out.log"
check "reason mentions implicit NIL" $?
cmp -s "$D/b.prg" "$HERE/fix01/b.prg"
check "b.prg untouched"            $?

echo "case 16: extract-function (FOR loop) preserves behavior"
D=$(fresh case16)
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
( cd "$D" && "$BIN" extract-function fix01.hbp a.prg 9-11 Acumula > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "STATIC PROCEDURE Acumula( bAcum, i )" "$D/a.prg"
check "new static procedure created" $?
grep -q "^   Acumula( bAcum, i )$" "$D/a.prg"
check "selection replaced by call" $?
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
diff -q "$D/saida_antes.txt" "$D/saida_depois.txt" > /dev/null 2>&1
check "program output identical"   $?

echo "case 17: extract-function refuses a cut FOR/NEXT and RETURN in range"
D=$(fresh case17)
( cd "$D" && "$BIN" extract-function fix01.hbp a.prg 9-10 Metade2 > out.log 2>&1 )
RC=$?
check "cut FOR refused"            $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "closes outside it" "$D/out.log"
check "reason mentions open structure" $?
( cd "$D" && "$BIN" extract-function fix01.hbp a.prg 13-16 Fim2 > out2.log 2>&1 )
RC=$?
check "RETURN in range refused"    $([ $RC -ne 0 ] && echo 0 || echo 1)
cmp -s "$D/a.prg" "$HERE/fix01/a.prg"
check "a.prg untouched"            $?

echo "case 18: usages --json emits LSP Location[]"
D=$(fresh case18)
( cd "$D" && "$BIN" usages fix01.hbp Dupla --json locs.json > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
python3 - "$D/locs.json" <<'PYEOF'
import json, sys
locs = json.load(open(sys.argv[1]))
assert isinstance(locs, list) and len(locs) >= 2, "few locations"
assert any(l["uri"].endswith("b.prg") and l["range"]["start"]["line"] == 4 for l in locs), "definition loc"
assert any(l["uri"].endswith("a.prg") for l in locs), "call loc"
PYEOF
check "Location[] valid with def+call" $?

echo "case 19: unused-locals reports never-used and assigned-never-read"
D=$(fresh case19)
printf '\nFUNCTION ComSobras()\n\n   LOCAL nNada\n   LOCAL nSobra := 1\n   LOCAL nUsada := 2\n\n   RETURN nUsada\n' >> "$D/b.prg"
( cd "$D" && "$BIN" unused-locals fix01.hbp > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "'NNADA' declared but not used" "$D/out.log"
check "never-used local reported"  $?
grep -q "'NSOBRA' is assigned but not used" "$D/out.log"
check "assigned-never-read reported" $?
grep -qv "NUSADA" "$D/out.log"
check "used local not reported"    $?

echo "case 20: call-graph shows cross-module and external calls"
D=$(fresh case20)
( cd "$D" && "$BIN" call-graph fix01.hbp > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "a.prg: MAIN -> DUPLA  \[b.prg\]" "$D/out.log"
check "cross-module edge with module" $?
grep -q "a.prg: MAIN -> QOUT  \[external\]" "$D/out.log"
check "external callee tagged"     $?
( cd "$D" && "$BIN" call-graph fix01.hbp Dupla > filt.log 2>&1 )
grep -q "MAIN -> DUPLA" "$D/filt.log" && ! grep -q "QOUT" "$D/filt.log"
check "filter by function works"   $?

echo "case 21: rename-static (file-wide) with byte-identical verification"
D=$(fresh case21)
( cd "$D" && "$BIN" rename-static fix01.hbp b.prg s_nContador s_nSeq > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "STATIC s_nSeq := 0" "$D/b.prg"
check "file-wide declaration renamed" $?
grep -q "RETURN s_nSeq" "$D/b.prg"
check "use inside function renamed" $?
grep -q "verified: all 2 module" "$D/out.log"
check "byte-identical verification" $?
cmp -s "$D/a.prg" "$HERE/fix01/a.prg"
check "a.prg untouched"            $?

echo "case 22: find-dynamic-calls audits strings and macro zones"
D=$(fresh case22)
printf '\nFUNCTION NomeEmTexto()\n\n   RETURN "Dupla"\n\nFUNCTION Dinamica( cVar )\n\n   RETURN &cVar\n' >> "$D/a.prg"
( cd "$D" && "$BIN" find-dynamic-calls fix01.hbp > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "string 'Dupla' names a project function \[b.prg\]" "$D/out.log"
check "string naming function reported" $?
grep -q "function DINAMICA uses & macros" "$D/out.log"
check "macro zone reported"        $?

echo "case 23: dump v3 - sends (Eval) and PRIVATE initialization visible"
D=$(fresh case23)
( cd "$D" && "$BIN" usages fix01.hbp Eval > eval.log 2>&1 )
RC=$?
check "usages Eval exit 0"         $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "a.prg:10: send in MAIN" "$D/eval.log"
check "Eval listed as send"        $?
( cd "$D" && "$BIN" usages fix01.hbp xCfg > priv.log 2>&1 )
RC=$?
check "usages xCfg exit 0"         $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "write (memvar) in COMPRIVADA" "$D/priv.log"
check "PRIVATE init write listed"  $?
grep -q "read (memvar_implicit) in COMPRIVADA" "$D/priv.log"
check "later read listed"          $?

echo "case 24: rename inside a ;-continued statement (token on middle line)"
D=$(fresh case24)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Continuada cMsg cTexto > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "^           cTexto + ;$" "$D/a.prg"
check "middle continuation line renamed" $?
grep -q "RETURN cTexto" "$D/a.prg"
check "last line renamed"          $?
grep -q "verified: all 2 module" "$D/out.log"
check "byte-identical verification" $?

echo "case 25: aliased variables (M-> and alias->) visible in usages"
D=$(fresh case25)
printf '\nFUNCTION UsaAlias()\n\n   M->xGlob := 1\n\n   RETURN M->xGlob + CLIENTES->saldo\n' >> "$D/b.prg"
( cd "$D" && "$BIN" usages fix01.hbp xGlob > mv.log 2>&1 && "$BIN" usages fix01.hbp saldo > fld.log 2>&1 )
check "both usages exit 0"         $?
grep -q "write (memvar) in USAALIAS" "$D/mv.log"
check "M-> write listed as memvar" $?
grep -q "read (field) in USAALIAS" "$D/fld.log"
check "alias-> read listed as field" $?

echo "case 26: usages --json carries real columns"
D=$(fresh case26)
( cd "$D" && "$BIN" usages fix01.hbp Dupla --json locs.json > out.log 2>&1 )
python3 - "$D/locs.json" <<'PYEOF'
import json, sys
locs = json.load(open(sys.argv[1]))
assert any(l["range"]["start"]["character"] > 0 for l in locs), "no real column found"
assert all(l["range"]["end"]["character"] >= l["range"]["start"]["character"] for l in locs)
PYEOF
check "columns present in Location[]" $?

echo "case 27: rename-function warns about DYNAMIC in .hbx export file"
D=$(fresh case27)
printf 'DYNAMIC Dupla\n' > "$D/exports.hbx"
printf 'exports.hbx\n' >> "$D/fix01.hbp"
( cd "$D" && "$BIN" rename-function fix01.hbp Dupla Dobrar > out.log 2>&1 )
RC=$?
check "refused without --force"    $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "DYNAMIC DUPLA in export file" "$D/out.log"
check "hbx warning listed"         $?

echo "case 28: project as a plain list of .prg files (no .hbp)"
D=$(fresh case28)
( cd "$D" && "$BIN" usages "a.prg,b.prg" Dupla > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "definition (function)" "$D/out.log"
check "definition found"           $?
grep -q "call in MAIN" "$D/out.log"
check "call found"                 $?

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
