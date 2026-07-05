#!/bin/bash
# hbrefactor test runner - second incarnation (compiler AST, schema ast-1)
# Every fixture is a PROJECT (>= 2 .prg + shared .ch + .hbp): the tool must
# prove it operates at project level, never on a lone file.
#
# Case numbers 0-30 preserve the behaviour contract of the occ era
# (roadmap v2); the degraded-coverage case (old 31) is gone with the mode
# itself - partial coverage returns when a real broken project re-enters
# the scope. New powers of the AST era: case 31 (multi-line reorder call
# site + ','/')' inside string arguments), case 32 (rename-function inside
# a ';'-continued statement).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="${BIN:-$HERE/../bin/hbrefactor}"
export HB_BIN="${HB_BIN:?HB_BIN must point to the harbour binaries dir (branch feature/compiler-ast-dump)}"

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

echo "case 0: base fixtures compile clean under the flags the .hbp declares"
# the fixture project declares -w3 -es2; the fixtures themselves must be
# warning-clean idiomatic Harbour (a warning that slips through here is a
# fixture bug, e.g. a bare PRIVATE reference without a MEMVAR declaration)
for f in a.prg b.prg; do
   "$HB_BIN/harbour" "$HERE/fix01/$f" -n -q0 -w3 -es2 -s -I"$HERE/fix01" > /dev/null 2>&1
   check "$f clean under -w3 -es2"  $?
done

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
grep -qi "rollback" "$D/out.log"
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
grep -q "string igual a 'Dupla' - possível chamada por nome" "$D/out.log"
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
grep -q "STATIC PROCEDURE Acumula( bAcum )" "$D/a.prg"
check "new static procedure created" $?
grep -q "^   Acumula( bAcum )$" "$D/a.prg"
check "selection replaced by call" $?
# 'i' is used only inside the selection: its declaration must migrate into
# the new function (leaving it in Main breaks the project's -w3 -es2 build)
grep -q "^   LOCAL i$" "$D/a.prg"
check "selection-only local moved into new function" $?
[ "$(grep -c "LOCAL i" "$D/a.prg")" -eq 1 ]
check "declaration removed from Main" $?
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
diff -q "$D/saida_antes.txt" "$D/saida_depois.txt" > /dev/null 2>&1
check "program output identical"   $?

echo "case 17: extract-function refuses a cut FOR/NEXT and RETURN in range"
D=$(fresh case17)
( cd "$D" && "$BIN" extract-function fix01.hbp a.prg 9-10 Metade2 > out.log 2>&1 )
RC=$?
check "cut FOR refused"            $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "fecha fora dela" "$D/out.log"
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

echo "case 23: sends (Eval) and PRIVATE initialization visible"
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
grep -q "read (memvar) in COMPRIVADA" "$D/priv.log"
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
grep -q "DYNAMIC DUPLA em export (.hbx)" "$D/out.log"
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

echo "case 29: real-project .hbp dialect (-inc, \${hb_name}.hbx, .hbc dep, class)"
# mirrors what dogfooding on contrib/hbhttpd required: hbmk2 switches the
# tool must skip (-inc), target-name macros, a dependency .hbc contributing
# incpaths=, the system include dir (hbclass.ch) derived from HB_BIN, and
# methods addressable by name (hbclass.ch names them <Class>_<Method>)
D=$(fresh case29)
mkdir -p "$D/dep"
printf 'incpaths=.\n' > "$D/dep/dep.hbc"
printf '#define DEP_TAXA 0\n' > "$D/dep/dep.ch"
cat > "$D/c.prg" <<'EOF'
#include "hbclass.ch"
#include "dep.ch"

CREATE CLASS Conta

   VAR nSaldo INIT 0

   METHOD Deposita( nValor )

ENDCLASS

METHOD Deposita( nValor ) CLASS Conta

   LOCAL nNovo := ::nSaldo + nValor + DEP_TAXA

   ::nSaldo := nNovo

   RETURN Self
EOF
printf -- '-inc\n-w3 -es2\n${hb_name}.hbx\n\na.prg\nb.prg\nc.prg\n\ndep/dep.hbc\n' > "$D/case29.hbp"
printf 'DYNAMIC Dupla\n' > "$D/case29.hbx"
( cd "$D" && "$BIN" usages case29.hbp Deposita > out.log 2>&1 )
RC=$?
check "usages exit 0 (project compiles)" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "possible method definition (CONTA_DEPOSITA, name convention)" "$D/out.log"
check "method definition via name convention" $?
( cd "$D" && "$BIN" rename-local case29.hbp c.prg Deposita nNovo nCalc > ren.log 2>&1 )
RC=$?
check "rename-local by method name"  $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "verified: all 3 module" "$D/ren.log"
check "3 modules verified"           $?
( cd "$D" && "$BIN" rename-local case29.hbp c.prg Conta:Deposita nCalc nNovo > ren2.log 2>&1 )
RC=$?
check "rename-local by Class:Method" $([ $RC -eq 0 ] && echo 0 || echo 1)
( cd "$D" && "$BIN" rename-function case29.hbp Dupla Dobrar > hbx.log 2>&1 )
RC=$?
check "hbx via \${hb_name} refused without --force" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "DYNAMIC DUPLA em export (.hbx)" "$D/hbx.log"
check "hbx warning proves macro expansion" $?

echo "case 30: broken build is reported, never silent"
D=$(fresh case30)
printf '\nFUNCTION Quebrada()\n\n   RETURN NaoFecha(\n' >> "$D/b.prg"
( cd "$D" && "$BIN" unused-locals fix01.hbp > out.log 2>&1 )
RC=$?
check "unused-locals exit != 0"    $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "não compila" "$D/out.log"
check "refusal names the failure"  $?
grep -q " Error E" "$D/out.log"
check "compiler error line shown"  $?
( cd "$D" && "$BIN" usages fix01.hbp Dupla > usages.log 2>&1 )
RC=$?
check "usages exit != 0"           $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q " Error E" "$D/usages.log"
check "usages surfaces the error"  $?

echo "case 31: reorder-params on multi-line call site and ','/')' inside strings"
# new power of the AST era: the occ incarnation refused multi-line call
# sites; token spans make them (and quoted ','/')' in arguments) trivial
D=$(fresh case31)
cat >> "$D/a.prg" <<'EOF'

FUNCTION ChamaLonga()

   RETURN Sub2( 10 + 1, ;
                3 )

FUNCTION ChamaTexto()

   RETURN Sub2( Len( "a,b)c" ), 2 )
EOF
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
( cd "$D" && "$BIN" reorder-params fix01.hbp Sub2 nB,nA > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "Sub2( 3, ;" "$D/a.prg"
check "multi-line call: first arg swapped in" $?
grep -q "^                10 + 1 )$" "$D/a.prg"
check "multi-line call: second line swapped" $?
grep -q 'Sub2( 2, Len( "a,b)c" ) )' "$D/a.prg"
check "quoted ','/')' argument moved intact" $?
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
diff -q "$D/saida_antes.txt" "$D/saida_depois.txt" > /dev/null 2>&1
check "program output identical"   $?

echo "case 32: rename-function call site inside a ;-continued statement"
# the call record points at the LAST physical line; the statement token
# spans must still find the name on the middle line
D=$(fresh case32)
cat >> "$D/a.prg" <<'EOF'

FUNCTION ChamaContinuada()

   LOCAL n := 1 + ;
              Dupla( 4 ) + ;
              2

   RETURN n
EOF
( cd "$D" && "$BIN" rename-function fix01.hbp Dupla Dobrar > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "^              Dobrar( 4 ) + ;$" "$D/a.prg"
check "middle continuation line renamed" $?
grep -q "FUNCTION Dobrar( nV )" "$D/b.prg"
check "definition renamed"         $?
grep -q "pcode byte-identical" "$D/out.log"
check "structural verification"    $?

echo "case 33: extract-function migrates decls from a mixed LOCAL line (per-var)"
# LOCAL nJ, cCh, cSai := "": nJ and cCh are selection-only and must migrate
# even though cSai (kept, has initializer) shares the line - the neighbour
# gaps of each name decide, not the whole line (proven on hbhttpd's
# UHtmlEncode). cSai is written first via ref (+=) and read after: it comes
# back as an in-out parameter and return value.
D=$(fresh case33)
cat >> "$D/a.prg" <<'EOF'

FUNCTION MontaTexto( cBase )

   LOCAL nJ, cCh, cSai := ""

   FOR nJ := 1 TO Len( cBase )
      cCh := SubStr( cBase, nJ, 1 )
      cSai += cCh + "."
   NEXT

   RETURN cSai
EOF
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
( cd "$D" && "$BIN" extract-function fix01.hbp a.prg 53-56 Pontilha > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "^   LOCAL cSai := \"\"$" "$D/a.prg"
check "kept var stays with its initializer" $?
grep -q "cSai := Pontilha( cBase, cSai )" "$D/a.prg"
check "in-out variable assigned from call" $?
grep -q "^   LOCAL nJ, cCh$" "$D/a.prg"
check "selection-only locals migrated together" $?
[ "$(grep -c "LOCAL nJ" "$D/a.prg")" -eq 1 ]
check "migrated decls removed from origin" $?
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
diff -q "$D/saida_antes.txt" "$D/saida_depois.txt" > /dev/null 2>&1
check "program output identical"   $?

echo "case 34: reorder-params moves a multi-line ARGUMENT intact (B3)"
# the ';' continuation travels inside the argument text and the result
# stays valid - the argument spans are real source ranges, not line-bound
D=$(fresh case34)
cat >> "$D/a.prg" <<'EOF'

FUNCTION ChamaArgLongo()

   RETURN Sub2( 10 ;
                + 1, 3 )
EOF
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
( cd "$D" && "$BIN" reorder-params fix01.hbp Sub2 nB,nA > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "Sub2( 3, 10 ;" "$D/a.prg"
check "multi-line argument moved to 2nd slot" $?
grep -q "^                + 1 )$" "$D/a.prg"
check "continuation line preserved" $?
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
diff -q "$D/saida_antes.txt" "$D/saida_depois.txt" > /dev/null 2>&1
check "program output identical"   $?

echo "case 35: inline-local replaces reads with the init expression (B3)"
# Dupla is executed by Main: behaviour must be identical after inlining nR
D=$(fresh case35)
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
( cd "$D" && "$BIN" inline-local fix01.hbp b.prg Dupla nR > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "RETURN ( nV + nV )" "$D/b.prg"
check "read replaced by parenthesized expression" $?
! grep -q "LOCAL nR" "$D/b.prg"
check "declaration removed"        $?
grep -q "símbolos intactos" "$D/out.log"
check "structural verification"    $?
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
diff -q "$D/saida_antes.txt" "$D/saida_depois.txt" > /dev/null 2>&1
check "program output identical"   $?

echo "case 36: inline-local refusals (purity is the gate)"
D=$(fresh case36)
cat >> "$D/b.prg" <<'EOF'

FUNCTION ComImpura( nQtd )

   LOCAL nDobro := Dupla( 4 )
   LOCAL nMuda := 1

   nMuda++

   RETURN nQtd + nDobro + nMuda
EOF
( cd "$D" && "$BIN" inline-local fix01.hbp b.prg ComImpura nDobro > imp.log 2>&1 )
RC=$?
check "function call in init refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "impura" "$D/imp.log"
check "reason mentions purity"     $?
( cd "$D" && "$BIN" inline-local fix01.hbp b.prg ComImpura nMuda > mut.log 2>&1 )
RC=$?
check "rewritten variable refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
( cd "$D" && "$BIN" inline-local fix01.hbp a.prg Main nTotal > blk.log 2>&1 )
RC=$?
check "codeblock capture refused"  $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "codeblock" "$D/blk.log"
check "reason mentions codeblock"  $?
( cd "$D" && "$BIN" inline-local fix01.hbp a.prg Rotulada nVisto > str.log 2>&1 )
RC=$?
check "stringified name refused"   $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "stringify" "$D/str.log"
check "reason mentions stringify"  $?
( cd "$D" && "$BIN" inline-local fix01.hbp a.prg LimiteMax nMax > def.log 2>&1 )
RC=$?
check "#define init (no source position) refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
cmp -s "$D/a.prg" "$HERE/fix01/a.prg"
check "a.prg untouched"            $?

echo "case 37: name validity comes from the project's compiler, not from lists"
# WHILE is rejected by the compiler as a variable name -> clean refusal
D=$(fresh case37)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Main nTotal while > out.log 2>&1 )
RC=$?
check "compiler-rejected name refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "compilador do projeto rejeita" "$D/out.log"
check "refusal cites the compiler"  $?
# LOOP is ACCEPTED by the compiler as a local name (the occ-era list wrongly
# refused it - grammar truth restored); byte-identical verification still rules
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg LimiteMax nMax Loop > loop.log 2>&1 )
RC=$?
check "compiler-accepted keyword-like name renames" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "verified: all 2 module" "$D/loop.log"
check "byte-identical verification" $?
# hard-reserved RTL names (Len, Space...) the compiler itself refuses to
# redefine - the probe relays that; names it does accept (OutStd) but the
# RUNTIME knows (hb_IsFunction) get a shadowing warning + --force gate
( cd "$D" && "$BIN" rename-function fix01.hbp Sub2 Len > rtl.log 2>&1 )
RC=$?
check "compiler-protected RTL name refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "compilador do projeto rejeita" "$D/rtl.log"
check "probe relays the compiler refusal" $?
( cd "$D" && "$BIN" rename-function fix01.hbp Sub2 hb_ntos > rtl2.log 2>&1 )
RC=$?
check "runtime function name refused without --force" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "função do runtime Harbour" "$D/rtl2.log"
check "warning explains the shadowing" $?
# hb_MilliSeconds is NOT linked into the tool itself: only the canonical
# core list (include/harbour.hbx, found via the project's -i paths) knows
# it - hb_IsFunction alone would miss the shadowing
( cd "$D" && "$BIN" rename-function fix01.hbp Sub2 hb_MilliSeconds > rtl3.log 2>&1 )
RC=$?
check "core function unknown to the tool's runtime still refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "função do runtime Harbour" "$D/rtl3.log"
check "harbour.hbx caught it" $?
# renaming to a name the project already CALLS (even an external one, like
# QOut) would hijack those calls
( cd "$D" && "$BIN" rename-function fix01.hbp Sub2 QOut > hij.log 2>&1 )
RC=$?
check "name already called in project refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "sequestraria" "$D/hij.log"
check "refusal explains the hijack" $?

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
