#!/bin/bash
# hbrefactor test runner - second incarnation (compiler AST, schema ast-2/3)
# Every fixture is a PROJECT (>= 2 .prg + shared .ch + .hbp): the tool must
# prove it operates at project level, never on a lone file.
#
# Case numbers 0-30 preserve the behaviour contract of the occ era
# (roadmap v2); the degraded-coverage case (old 31) is gone with the mode
# itself - partial coverage returns when a real broken project re-enters
# the scope. New powers of the AST era: case 31 (multi-line reorder call
# site + ','/')' inside string arguments), case 32 (rename-function inside
# a ';'-continued statement). Cases 38-43 are phase B4 (pp DSLs over
# ppRules/ppApplications, specs S1-S5 of the roadmap): fixtures fixdsl/
# (user DSL, three rule families) and fixcls/ (hbclass.ch classes).
# Cases 44-46 are phase B4b (dynamically scoped memvars): fixture fixmv/
# armed with shadowing on both axes, '&' creation and an implicit memvar.
# Cases 47-49 are phase B4c (rename-method): fixture fixmth/ with two
# classes - since B4d the class facts come from the DERIVATION TRACE the
# pp records at expansion time ("from" in the ast-3 dump), not from shape
# anchors over the expanded code. Cases 50-53 are phase B4d (specs G2-G6):
# fixture fixppm/ with an INVENTED DSL - nothing of it exists in any core
# include and the tool mentions none of its words; usages lifts and
# rename-pp-marker predicts every derived artifact from the trace alone.

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

freshdsl() { # freshdsl <case-name> -> fixture with a user pp DSL (B4)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixdsl/*.prg "$HERE"/fixdsl/*.ch "$HERE"/fixdsl/*.hbp "$d"/
   echo "$d"
}

freshcls() { # freshcls <case-name> -> fixture with hbclass.ch classes (B4)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixcls/*.prg "$HERE"/fixcls/*.hbp "$d"/
   echo "$d"
}

freshmv() { # freshmv <case-name> -> fixture with dynamically scoped memvars (B4b)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixmv/*.prg "$HERE"/fixmv/*.hbp "$d"/
   echo "$d"
}

freshmth() { # freshmth <case-name> -> fixture with two classes (B4c)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixmth/*.prg "$HERE"/fixmth/*.hbp "$d"/
   echo "$d"
}

freshppm() { # freshppm <case-name> -> fixture with an INVENTED pp DSL (B4d)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixppm/*.prg "$HERE"/fixppm/*.ch "$HERE"/fixppm/*.hbp "$d"/
   echo "$d"
}

freshsig() { # freshsig <case-name> -> fixture with 2+ param methods (B4e P1a/P1b)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixsig/*.prg "$HERE"/fixsig/*.hbp "$d"/
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
# spec ABSOLUTO (o caminho que a extensão VSCode sempre passa): o URI não
# pode duplicar o prefixo do cwd - regressão do LocationsJson (hb_PathJoin,
# não hb_FNameMerge, para não concatenar caminho já absoluto)
( cd "$D" && "$BIN" usages "$D/fix01.hbp" Dupla --json absl.json > /dev/null 2>&1 )
python3 - "$D/absl.json" <<'PYEOF'
import json, sys
locs = json.load(open(sys.argv[1]))
for l in locs:
    p = l["uri"][len("file://"):]
    assert p.count("/absl") == 0, "path prefix doubled: " + l["uri"]
    assert "/case18/case18" not in p, "cwd doubled in uri: " + l["uri"]
assert any(l["uri"].endswith("b.prg") for l in locs), "def loc present"
PYEOF
check "absolute spec: URI not doubled (extension path)" $?

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
grep -q "method definition Deposita (class Conta)" "$D/out.log"
check "method definition lifted to source vocabulary (B4)" $?
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

echo "case 38: S1 - user pp DSL (three families): usages + rename-dsl round-trip"
# fixtures compile clean first (working rule: never test with a broken fixture)
for f in a.prg b.prg; do
   "$HB_BIN/harbour" "$HERE/fixdsl/$f" -n -q0 -w3 -es2 -s -I"$HERE/fixdsl" > /dev/null 2>&1
   check "fixdsl/$f clean under -w3 -es2" $?
done
D=$(freshdsl case38)
( cd "$D" && "$BIN" usages fixdsl.hbp MENUITEM > dsl.log 2>&1 )
RC=$?
check "usages of a DSL word exit 0"  $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "menu.ch:8: directive (#command MENUITEM, 4 marker(s))" "$D/dsl.log"
check "directive found (pp convention: line = last physical line)" $?
grep -q "a.prg:11:4: application (#command MENUITEM, menu.ch:8)" "$D/dsl.log"
check "application with exact column"  $?
grep -q "b.prg:6:4: application" "$D/dsl.log"
check "application in second module"   $?
( cd "$D" && "$BIN" usages fixdsl.hbp ACTION > act.log 2>&1 )
grep -q "a.prg:11:21: keyword (#command MENUITEM" "$D/act.log"
check "secondary DSL word reported as keyword of the rule" $?
( cd "$D" && "$BIN" rename-dsl fixdsl.hbp MENUITEM MENU_ITEM > ren.log 2>&1 )
RC=$?
check "rename-dsl exit 0"            $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "3 application site(s) + 1 directive occurrence(s); .ppo and .hrb byte-identical" "$D/ren.log"
check "verification: .ppo/.hrb byte-identical" $?
grep -q "MENU_ITEM <label>" "$D/menu.ch"
check "directive head renamed in menu.ch" $?
grep -q 'MENU_ITEM "Abrir"' "$D/a.prg" && grep -q 'MENU_ITEM "Sub"' "$D/b.prg"
check "application sites renamed in both modules" $?
( cd "$D" && "$BIN" rename-dsl fixdsl.hbp MENU_ITEM MENUITEM > /dev/null 2>&1 )
cmp -s "$D/a.prg" "$HERE/fixdsl/a.prg" && cmp -s "$D/b.prg" "$HERE/fixdsl/b.prg" && \
   cmp -s "$D/menu.ch" "$HERE/fixdsl/menu.ch"
check "A->B->A round-trip byte-exact (sources + .ch)" $?
# o #define constante é o caso degenerado (regra sem markers)
( cd "$D" && "$BIN" rename-dsl fixdsl.hbp LIMITE_TETO LIMITE_TOPO > def.log 2>&1 && \
             "$BIN" rename-dsl fixdsl.hbp LIMITE_TOPO LIMITE_TETO > /dev/null 2>&1 )
check "#define rename (degenerate rule) round-trips" $?
cmp -s "$D/b.prg" "$HERE/fixdsl/b.prg" && cmp -s "$D/menu.ch" "$HERE/fixdsl/menu.ch"
check "#define round-trip byte-exact"  $?
( cd "$D" && "$BIN" rename-dsl fixdsl.hbp MENUITEM MENU_X --dry-run > dry.log 2>&1 )
cmp -s "$D/a.prg" "$HERE/fixdsl/a.prg" && cmp -s "$D/menu.ch" "$HERE/fixdsl/menu.ch"
check "dry run writes nothing"        $?
# recusas: sequestro de identificador, abreviação dBase, palavra inexistente
( cd "$D" && "$BIN" rename-dsl fixdsl.hbp MENUITEM MenuAdd > hij.log 2>&1 )
RC=$?
check "new word already an identifier refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "capturaria" "$D/hij.log"
check "refusal explains the capture"  $?
( cd "$D" && "$BIN" rename-dsl fixdsl.hbp MENUITEM MENU > abr.log 2>&1 )
RC=$?
check "dBase 4-letter abbreviation clash refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "abreviação" "$D/abr.log"
check "refusal cites the abbreviation rule" $?
( cd "$D" && "$BIN" rename-dsl fixdsl.hbp NAOEXISTE Outra > nex.log 2>&1 )
RC=$?
check "word that is not a rule head refused" $([ $RC -ne 0 ] && echo 0 || echo 1)

echo "case 39: S2 - hbclass.ch classes: usages answers in method/class vocabulary"
for f in w1.prg w2.prg; do
   "$HB_BIN/harbour" "$HERE/fixcls/$f" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" > /dev/null 2>&1
   check "fixcls/$f clean under -w3 -es2" $?
done
D=$(freshcls case39)
( cd "$D" && "$BIN" usages fixcls.hbp Paint > out.log 2>&1 )
RC=$?
check "usages Paint exit 0"           $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "w1.prg:11: method definition Paint (class UWMenu)" "$D/out.log"
check "definition lifted to method/class vocabulary" $?
! grep -q "UWMENU_PAINT" "$D/out.log"
check "generated name never leaks without --show-expansion" $?
grep -q "w2.prg:7: send in MAIN" "$D/out.log"
check "send site found across modules" $?
( cd "$D" && "$BIN" usages fixcls.hbp Paint --show-expansion > exp.log 2>&1 )
grep -q "method definition Paint (class UWMenu) -> UWMENU_PAINT" "$D/exp.log"
check "--show-expansion reveals the generated function" $?
( cd "$D" && "$BIN" usages fixcls.hbp METHOD > mth.log 2>&1 )
grep -q "hbclass.ch:" "$D/mth.log"
check "hbclass.ch rules reported as the DSL they are" $?
grep -q "w1.prg:11:1: application (#xcommand METHOD" "$D/mth.log"
check "hbclass.ch application with span in USER source" $?

echo "case 40: S3 - builtin rules (std.ch family): facts yes, rename no"
D=$(freshdsl case40)
( cd "$D" && "$BIN" usages fixdsl.hbp SAY > say.log 2>&1 )
RC=$?
check "usages of builtin rule word exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "a.prg:23:11: keyword (#command @, builtin)" "$D/say.log"
check "builtin @..SAY application with exact column" $?
grep -q "sem posição no fonte" "$D/say.log"
check "multi-pass reapplication visible (no source position)" $?
( cd "$D" && "$BIN" rename-dsl fixdsl.hbp "@" ARROBA > bi.log 2>&1 )
RC=$?
check "rename-dsl of builtin rule refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "builtin" "$D/bi.log"
check "refusal explains there is no directive file" $?
( cd "$D" && "$BIN" rename-dsl fixdsl.hbp SAY XSAY > say2.log 2>&1 )
RC=$?
check "rename of secondary word refused (not a head)" $([ $RC -ne 0 ] && echo 0 || echo 1)

echo "case 41: S4 - the two families: #[x]command statement-wide, #[x]translate mid-statement"
D=$(freshdsl case41)
# xcommand: uso continuado por ';' - cada token na sua linha física real
( cd "$D" && "$BIN" usages fixdsl.hbp MENUITEM > cont.log 2>&1 )
grep -q "a.prg:12:4: application (#command MENUITEM" "$D/cont.log"
check "';'-continued command use: word at its physical line" $?
( cd "$D" && "$BIN" usages fixdsl.hbp ACTION > act.log 2>&1 )
grep -q "a.prg:13:7: keyword" "$D/act.log"
check "keyword on the continuation line has its own position" $?
# xtranslate: substituição no meio da statement, duas na MESMA linha
( cd "$D" && "$BIN" usages fixdsl.hbp SQUARED > sq.log 2>&1 )
grep -q "a.prg:17:6: application (#xtranslate SQUARED" "$D/sq.log" && \
   grep -q "a.prg:17:20: application (#xtranslate SQUARED" "$D/sq.log"
check "two mid-statement applications on one line, distinct columns" $?
( cd "$D" && "$BIN" rename-dsl fixdsl.hbp REPEAT LACO > rep.log 2>&1 && \
             "$BIN" rename-dsl fixdsl.hbp LACO REPEAT > /dev/null 2>&1 )
check "xcommand rename round-trips"   $?
cmp -s "$D/a.prg" "$HERE/fixdsl/a.prg" && cmp -s "$D/menu.ch" "$HERE/fixdsl/menu.ch"
check "xcommand round-trip byte-exact" $?

echo "case 42: S5 - ppApplications matches the pp trace (.ppt) 1:1"
D=$(freshdsl case42)
( cd "$D" && "$BIN" dump fixdsl.hbp > dump.log 2>&1 )
RC=$?
check "dump exit 0"                   $([ $RC -eq 0 ] && echo 0 || echo 1)
DIR=$(sed -n 's/^dumps em: //p' "$D/dump.log")
( cd "$D" && "$HB_BIN/harbour" a.prg -n -q0 -i. -s '-p+' > /dev/null 2>&1 )
python3 - "$D/a.ppt" "$DIR/a.ast.json" <<'PYEOF'
import json, re, sys
traces = []
pend = None
for line in open(sys.argv[1]):
    m = re.match(r'^\S+\((\d+)\) >', line)
    if m:
        pend = int(m.group(1))
    elif line.startswith('#') and pend is not None:
        traces.append((pend, line[1:].split('>')[0].strip()))
        pend = None
d = json.load(open(sys.argv[2]))
apps = [(a['line'], d['ppRules'][a['rule']]['kind']) for a in d['ppApplications']]
sys.exit(0 if traces == apps and len(apps) > 0 else 1)
PYEOF
check "count, order, lines and kinds match the .ppt trace" $?

echo "case 43: DSL-created block structure guards extract-function"
D=$(freshdsl case43)
( cd "$D" && "$BIN" extract-function fixdsl.hbp a.prg 19-20 Pedaco > ext.log 2>&1 )
RC=$?
check "selection cutting REPEAT without UNTIL refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "abre while (linha 19) que fecha fora dela" "$D/ext.log"
check "refusal is structural (block facts), line exact" $?
cmp -s "$D/a.prg" "$HERE/fixdsl/a.prg"
check "a.prg untouched"               $?

echo "case 44: B4b - memvar visibility map (creators, reach, shadows, holes)"
# a fixture usa memvar implícita de propósito (W0001) - compila sem -es2
for f in a.prg b.prg; do
   "$HB_BIN/harbour" "$HERE/fixmv/$f" -n -q0 -w3 -s -I"$HERE/fixmv" > /dev/null 2>&1
   check "fixmv/$f compiles under -w3"  $?
done
D=$(freshmv case44)
( cd "$D" && "$BIN" usages fixmv.hbp xSaldo > map.log 2>&1 )
RC=$?
check "usages of a memvar exit 0"     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "creator: PUBLIC in MAIN (a.prg:7)" "$D/map.log"
check "PUBLIC creator with exact line" $?
grep -q "creator: PRIVATE in COMSOMBRAPRIVADA (a.prg:23)" "$D/map.log"
check "PRIVATE creator (dynamic shadow) found" $?
grep -q "dynamic shadowing: PRIVATE sombreia o PUBLIC" "$D/map.log"
check "dynamic-axis shadowing reported" $?
grep -q "dynamic reach: DEPOSITA$" "$D/map.log"
check "reach of the PRIVATE is its dynamic extension only" $?
grep -q "hole in reach: VIAMACRO (b.prg) usa macro" "$D/map.log"
check "macro hole in the PUBLIC's reach" $?
grep -q "lexical shadow: COMLOCALHOMONIMO" "$D/map.log"
check "lexical-axis shadow reported (uses there are NOT the memvar)" $?
grep -q "macro creation: VIAMACRO (b.prg:31)" "$D/map.log"
check "invisible '&' creation reported" $?
( cd "$D" && "$BIN" usages fixmv.hbp xTaxa > imp.log 2>&1 )
grep -q "implicit use: IMPLICITA" "$D/imp.log"
check "implicit memvar highlighted in map" $?

echo "case 45: B4b - rename-memvar on a closed clean reach (behaviour identical)"
D=$(freshmv case45)
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
check "fixture runs before"           $?
# a criação via '&' FORA do alcance é aviso (não roda com o PRIVATE vivo):
# sem --force recusa e não escreve; com --force executa
( cd "$D" && "$BIN" rename-memvar fixmv.hbp xConta xCaixa > ren0.log 2>&1 )
RC=$?
check "out-of-reach '&' creation gates without --force" $([ $RC -ne 0 ] && echo 0 || echo 1)
cmp -s "$D/a.prg" "$HERE/fixmv/a.prg"
check "nothing written without --force" $?
( cd "$D" && "$BIN" rename-memvar fixmv.hbp xConta xCaixa --force > ren.log 2>&1 )
RC=$?
check "rename-memvar exit 0 (clean closure)" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "verified: 5 edit(s); symbol renamed, pcode byte-identical" "$D/ren.log"
check "verification: symbol renamed, pcode byte-identical" $?
grep -q "MEMVAR xSaldo, xCaixa" "$D/a.prg" && grep -q "PRIVATE xCaixa := 10" "$D/a.prg" \
   && grep -q "xCaixa += nAux - 1" "$D/b.prg"
check "declaration, creator and cross-module use renamed" $?
( cd "$D" && $HB_BIN/hbmk2 a.prg b.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execution identical after rename" $?
( cd "$D" && "$BIN" rename-memvar fixmv.hbp xCaixa xConta --force > /dev/null 2>&1 )
cmp -s "$D/a.prg" "$HERE/fixmv/a.prg" && cmp -s "$D/b.prg" "$HERE/fixmv/b.prg"
check "A->B->A round-trip byte-exact"  $?

echo "case 46: B4b - rename-memvar refusals explain the hole"
D=$(freshmv case46)
( cd "$D" && "$BIN" rename-memvar fixmv.hbp xSaldo xGrana > r1.log 2>&1 )
RC=$?
check "more than one creator refused"  $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "mais de um criador" "$D/r1.log" && grep -q "PUBLIC em MAIN" "$D/r1.log"
check "refusal lists the creators"     $?
( cd "$D" && "$BIN" rename-memvar fixmv.hbp xTaxa xImposto > r2.log 2>&1 )
RC=$?
check "implicit memvar (no creator) refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "não tem criador" "$D/r2.log"
check "refusal explains missing creator" $?
( cd "$D" && "$BIN" rename-memvar fixmv.hbp xOculta xVista > r3.log 2>&1 )
RC=$?
check "macro-created memvar refused"   $([ $RC -ne 0 ] && echo 0 || echo 1)
( cd "$D" && "$BIN" rename-memvar fixmv.hbp xConta nAux > r4.log 2>&1 )
RC=$?
check "new name is LOCAL in a using function refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "mudariam de binding em silêncio" "$D/r4.log"
check "refusal names the silent binding change" $?
( cd "$D" && "$BIN" rename-memvar fixmv.hbp xConta xSaldo > r5.log 2>&1 )
RC=$?
check "new name already a living memvar refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "fundiria duas variáveis" "$D/r5.log"
check "refusal explains the merge"     $?
# o inverso da recusa-chave: rename-local para nome de memvar usada na função
( cd "$D" && "$BIN" rename-local fixmv.hbp b.prg SomaConta nAux xConta > r6.log 2>&1 )
RC=$?
check "rename-local to a memvar used in the function refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "sombrearia esses usos" "$D/r6.log"
check "reverse guard explains the shadowing" $?
cmp -s "$D/a.prg" "$HERE/fixmv/a.prg" && cmp -s "$D/b.prg" "$HERE/fixmv/b.prg"
check "sources untouched by all refusals" $?

echo "case 47: B4c - rename-method (decl + impl + sends; INLINE; string gate)"
for f in c1.prg c2.prg; do
   "$HB_BIN/harbour" "$HERE/fixmth/$f" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" > /dev/null 2>&1
   check "fixmth/$f clean under -w3 -es2"  $?
done
D=$(freshmth case47)
( cd "$D" && $HB_BIN/hbmk2 c1.prg c2.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
check "fixture runs before"           $?
( cd "$D" && "$BIN" rename-method fixmth.hbp Caixa:Info Mostra > ren.log 2>&1 )
RC=$?
check "clean method rename exit 0"    $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "c1.prg:8:11" "$D/ren.log" && grep -q "c1.prg:17:8" "$D/ren.log" \
   && grep -q "c2.prg:29:7" "$D/ren.log"
check "declaration, implementation and cross-module send sites" $?
grep -q "message and generated function renamed, other modules byte-identical" "$D/ren.log"
check "verification with the two expected symbol renames" $?
( cd "$D" && $HB_BIN/hbmk2 c1.prg c2.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execution identical after rename" $?
( cd "$D" && "$BIN" rename-method fixmth.hbp Caixa:Mostra Info > /dev/null 2>&1 )
cmp -s "$D/c1.prg" "$HERE/fixmth/c1.prg" && cmp -s "$D/c2.prg" "$HERE/fixmth/c2.prg"
check "A->B->A round-trip byte-exact"  $?
# INLINE: o nome também vive numa string do usuário -> --force obrigatório
( cd "$D" && "$BIN" rename-method fixmth.hbp Caixa:Dobro Duplo > inl0.log 2>&1 )
RC=$?
check "user string with the name gates without --force" $([ $RC -ne 0 ] && echo 0 || echo 1)
cmp -s "$D/c1.prg" "$HERE/fixmth/c1.prg"
check "nothing written without --force" $?
( cd "$D" && "$BIN" rename-method fixmth.hbp Caixa:Dobro Duplo --force > inl.log 2>&1 && \
             "$BIN" rename-method fixmth.hbp Caixa:Duplo Dobro --force > /dev/null 2>&1 )
check "INLINE method renames with --force and returns" $?
cmp -s "$D/c1.prg" "$HERE/fixmth/c1.prg" && cmp -s "$D/c2.prg" "$HERE/fixmth/c2.prg"
check "INLINE round-trip byte-exact"   $?

echo "case 48: B4c - send is dynamic dispatch: refusals explain the ambiguity"
D=$(freshmth case48)
( cd "$D" && "$BIN" rename-method fixmth.hbp Caixa:Soma Junta > r1.log 2>&1 )
RC=$?
check "method owned by two classes refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "também é membro de: OUTRA" "$D/r1.log" && grep -q "despacho dinâmico" "$D/r1.log"
check "refusal names the other class and the dispatch problem" $?
( cd "$D" && "$BIN" rename-method fixmth.hbp Caixa:Info Soma > r2.log 2>&1 )
RC=$?
check "new name already a registered message refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "fundiria mensagens" "$D/r2.log"
check "refusal explains the message merge" $?
( cd "$D" && "$BIN" rename-method fixmth.hbp Caixa:Info Fantasma > r3.log 2>&1 )
RC=$?
check "new name already sent somewhere refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "passaria a respondê-la" "$D/r3.log"
check "refusal explains the hijack"    $?
( cd "$D" && "$BIN" rename-method fixmth.hbp Caixa:nTot nTotal > r4.log 2>&1 )
RC=$?
check "VAR/DATA member (setter send _NTOT) refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "send _NTOT" "$D/r4.log"
check "refusal shows the assignment send" $?
cmp -s "$D/c1.prg" "$HERE/fixmth/c1.prg" && cmp -s "$D/c2.prg" "$HERE/fixmth/c2.prg"
check "sources untouched by all refusals" $?

echo "case 49: B4c - bare method name resolves when unique in the project"
D=$(freshmth case49)
( cd "$D" && "$BIN" rename-method fixmth.hbp Zera Limpa > z.log 2>&1 && \
             "$BIN" rename-method fixmth.hbp Limpa Zera > /dev/null 2>&1 )
check "unique bare name renames and returns" $?
cmp -s "$D/c2.prg" "$HERE/fixmth/c2.prg"
check "bare-name round-trip byte-exact" $?
( cd "$D" && "$BIN" rename-method fixmth.hbp Soma Junta > amb.log 2>&1 )
RC=$?
check "ambiguous bare name refused"    $([ $RC -ne 0 ] && echo 0 || echo 1)

echo "case 50: B4d G2/G6 - invented DSL: usages lifts in source vocabulary"
for f in e1.prg e2.prg; do
   "$HB_BIN/harbour" "$HERE/fixppm/$f" -n -q0 -w3 -es2 -s -I"$HERE/fixppm" > /dev/null 2>&1
   check "fixppm/$f clean under -w3 -es2"  $?
done
D=$(freshppm case50)
( cd "$D" && "$BIN" usages fixppm.hbp Click > out.log 2>&1 )
RC=$?
check "usages of a prefix-pasted marker name exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "e1.prg:8: handler definition Click" "$D/out.log"
check "definition lifted in the DSL's own vocabulary (rule head)" $?
! grep -q "on_Click" "$D/out.log"
check "generated name never leaks without --show-expansion" $?
( cd "$D" && "$BIN" usages fixppm.hbp Click --show-expansion > exp.log 2>&1 )
grep -q "handler definition Click -> ON_CLICK" "$D/exp.log"
check "--show-expansion reveals the pasted function" $?
( cd "$D" && "$BIN" usages fixppm.hbp Salva > sal.log 2>&1 )
grep -q "e1.prg:5: registro definition Salva" "$D/sal.log" && \
   grep -q "e2.prg:8:12: name through pp rule (#xcommand DISPARA" "$D/sal.log"
check "definition and derived cross-module use site, exact positions" $?
( cd "$D" && $HB_BIN/hbmk2 e1.prg e2.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
check "fixture runs before"           $?
( cd "$D" && "$BIN" rename-pp-marker fixppm.hbp Click Novo > ren.log 2>&1 )
RC=$?
check "prefix-paste marker rename exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "predicted: ON_CLICK -> ON_NOVO" "$D/ren.log"
check "ON_CLICK -> ON_NOVO predicted from the trace (G2)" $?
grep -q "verified: 1 edit(s); derived artifacts renamed as predicted" "$D/ren.log"
check "verification computed from the trace" $?
( cd "$D" && $HB_BIN/hbmk2 e1.prg e2.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execution identical after rename" $?
( cd "$D" && "$BIN" rename-pp-marker fixppm.hbp Novo Click > /dev/null 2>&1 )
cmp -s "$D/e1.prg" "$HERE/fixppm/e1.prg" && cmp -s "$D/e2.prg" "$HERE/fixppm/e2.prg"
check "A->B->A round-trip byte-exact"  $?

echo "case 51: B4d G3 - pure stringify: the derived string is a predicted fact"
D=$(freshppm case51)
( cd "$D" && "$BIN" rename-pp-marker fixppm.hbp Pronto Feito > ren.log 2>&1 )
RC=$?
check "stringify-only marker rename exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q 'predicted string: "Pronto" -> "Feito"' "$D/ren.log"
check "derived string change predicted, not warned" $?
( cd "$D" && $HB_BIN/hbmk2 e1.prg e2.prg -oapp -gtcgi -q0 > /dev/null 2>&1 && ./app > saida.txt 2>/dev/null )
grep -q '\[Feito\]' "$D/saida.txt" && ! grep -q '\[Pronto\]' "$D/saida.txt"
check "runtime string regenerated from the edited identifier" $?
( cd "$D" && "$BIN" rename-pp-marker fixppm.hbp Feito Pronto > /dev/null 2>&1 )
cmp -s "$D/e2.prg" "$HERE/fixppm/e2.prg"
check "A->B->A round-trip byte-exact"  $?

echo "case 52: B4d G4 - clone+paste+stringify in ONE rule; derived call crosses modules"
D=$(freshppm case52)
( cd "$D" && $HB_BIN/hbmk2 e1.prg e2.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
check "fixture runs before"           $?
( cd "$D" && "$BIN" rename-pp-marker fixppm.hbp Salva Grava > ren.log 2>&1 )
RC=$?
check "multi-derivation marker rename exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "e1.prg:5:10" "$D/ren.log" && grep -q "e2.prg:8:12" "$D/ren.log"
check "definition and derived call site edited, both modules" $?
grep -q "predicted: REG_SALVA -> REG_GRAVA" "$D/ren.log" && \
   grep -q 'predicted string: "Salva" -> "Grava"' "$D/ren.log"
check "pasted symbol and stringified string both predicted" $?
( cd "$D" && $HB_BIN/hbmk2 e1.prg e2.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
sed 's/Salva/Grava/g' "$D/saida_antes.txt" | cmp -s - "$D/saida_depois.txt"
check "output changed exactly as the prediction says" $?
( cd "$D" && "$BIN" rename-pp-marker fixppm.hbp Grava Salva > /dev/null 2>&1 )
cmp -s "$D/e1.prg" "$HERE/fixppm/e1.prg" && cmp -s "$D/e2.prg" "$HERE/fixppm/e2.prg"
check "A->B->A round-trip byte-exact"  $?

echo "case 53: B4d G5 - co-derivation: neighbour intact; collisions refused by name"
D=$(freshppm case53)
( cd "$D" && "$BIN" rename-pp-marker fixppm.hbp Motor Trem > ren.log 2>&1 )
RC=$?
check "renaming one of two co-derived names exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "predicted: MOTOR_RODA -> TREM_RODA" "$D/ren.log"
check "pasted artifact predicted with the neighbour (Roda) intact" $?
( cd "$D" && "$BIN" rename-pp-marker fixppm.hbp Trem Motor > /dev/null 2>&1 )
cmp -s "$D/e1.prg" "$HERE/fixppm/e1.prg"
check "A->B->A round-trip byte-exact"  $?
( cd "$D" && "$BIN" rename-pp-marker fixppm.hbp Motor Freio > col.log 2>&1 )
RC=$?
check "predicted symbol colliding with existing function refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "FREIO_RODA" "$D/col.log" && grep -q "já existe como função" "$D/col.log"
check "refusal NAMES the predicted artifact (G5)" $?
printf '\nFUNCTION Chama()\n   RETURN on_Click()\n' >> "$D/e1.prg"
cp "$D/e1.prg" "$D/e1.saved"
( cd "$D" && "$BIN" rename-pp-marker fixppm.hbp Click Novo > orf.log 2>&1 )
RC=$?
check "source spelling a generated name gates the rename" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "soletra o nome gerado 'on_Click'" "$D/orf.log"
check "refusal points at the spelled generated name" $?
cmp -s "$D/e1.prg" "$D/e1.saved" && cmp -s "$D/e2.prg" "$HERE/fixppm/e2.prg"
check "sources untouched by all refusals" $?

echo "case 54: B4e regression - shared-origin sites must not double-apply an edit"
# a função gerada pf_Dobra tem o parâmetro nX declarado E usado no corpo -
# ambos são clones do MESMO token-fonte (o marker em PARAMFN Dobra( nX )),
# então nascem com a mesma (linha,col). Sem dedup por posição-fonte, o
# rename escrevia na span duas vezes; com nome novo que ESTENDE o antigo
# (nX->nXX) o guard textual era enganado e o resultado era nXXXX - e como
# nome de parâmetro não entra no pcode, o verify byte-idêntico deixava
# passar (corrupção silenciosa, exit 0). Regressão do fix de dedup.
D=$(freshppm case54)
( cd "$D" && "$BIN" rename-param fixppm.hbp e1.prg pf_Dobra nX nXX > ren.log 2>&1 )
RC=$?
check "rename-param on a DSL-generated function param exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "PARAMFN Dobra( nXX )" "$D/e1.prg" && ! grep -q "nXXXX" "$D/e1.prg"
check "edit applied exactly once (no nXXXX corruption)" $?
test "$(grep -c 'e1.prg:18:' "$D/ren.log")" = "1"
check "the shared-origin site is listed only once" $?
( cd "$D" && "$BIN" rename-param fixppm.hbp e1.prg pf_Dobra nXX nX > /dev/null 2>&1 )
cmp -s "$D/e1.prg" "$HERE/fixppm/e1.prg"
check "A->B->A round-trip byte-exact"  $?

echo "case 55: B4e P1a - rename-param aware of the METHOD signature (2+ params)"
# renomear o param de um método tem que mover a DECLARAÇÃO fora do corpo: o
# protótipo no CREATE CLASS e a linha METHOD ... CLASS. Em tokens[] a posição
# da assinatura COLAPSA para a do protótipo (clone multi-passe), então o span
# da função só via o uso no corpo - o rename esquecia a assinatura e o build
# recusava (hbclass casa protótipo<->impl pela assinatura inteira, nomes de
# param inclusos). Os sites da assinatura vêm dos markers posicionados de
# ppApplications, escopados pela identidade do nome gerado (classe+método).
for f in w1.prg w2.prg; do
   "$HB_BIN/harbour" "$HERE/fixsig/$f" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" > /dev/null 2>&1
   check "fixsig/$f clean under -w3 -es2"  $?
done
D=$(freshsig case55)
( cd "$D" && $HB_BIN/hbmk2 w1.prg w2.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
check "fixture runs before"           $?
( cd "$D" && "$BIN" rename-param fixsig.hbp w1.prg Widget:Resize nW nLargura > ren.log 2>&1 )
RC=$?
check "rename-param on a 2-param method exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "w1.prg:7:19" "$D/ren.log" && grep -q "w1.prg:11:16" "$D/ren.log" \
   && grep -q "w1.prg:13:29" "$D/ren.log"
check "prototype, implementation signature AND body edited" $?
grep -q "METHOD Resize( nLargura, nH )" "$D/w1.prg" \
   && test "$(grep -c "METHOD Resize( nLargura, nH )" "$D/w1.prg")" = "2"
check "both signature lines carry the new param, neighbour nH intact" $?
grep -q "verified: all 2 module(s) byte-identical" "$D/ren.log"
check "verification byte-identical (param name not in pcode)" $?
( cd "$D" && $HB_BIN/hbmk2 w1.prg w2.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execution identical after rename" $?
( cd "$D" && "$BIN" rename-param fixsig.hbp w1.prg Widget:Resize nLargura nW > /dev/null 2>&1 )
cmp -s "$D/w1.prg" "$HERE/fixsig/w1.prg"
check "A->B->A round-trip byte-exact"  $?
# a assinatura de OUTRO método (Grow) não é tocada ao renomear Resize
( cd "$D" && "$BIN" rename-param fixsig.hbp w1.prg Widget:Grow nDy nDelta > g.log 2>&1 )
RC=$?
check "second method's param renames independently" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "METHOD Grow( nDx, nDelta )" "$D/w1.prg" && grep -q "METHOD Resize( nW, nH )" "$D/w1.prg"
check "Grow signature moved, Resize signature untouched" $?

echo "case 56: B4e P1b - reorder-params ciente de método (assinatura + sends + unicidade)"
# reordenar o param de um método move a assinatura (protótipo + METHOD...CLASS,
# via ppApplications como na P1a) E os argumentos nos call sites de SEND
# (o:Msg(a,b)). Só reordena sends quando a mensagem é de UMA classe do projeto
# (senão o despacho é dinâmico e ambíguo - recusa nomeando as classes, mesma
# política do rename-method). O corpo não é tocado; o pcode muda legitimamente
# (ordem de push) e a verificação exige símbolos/funções intactos.
D=$(freshsig case56)
( cd "$D" && $HB_BIN/hbmk2 w1.prg w2.prg -oapp_before -gtcgi -q0 > /dev/null 2>&1 && ./app_before > saida_antes.txt 2>/dev/null )
check "fixture runs before"           $?
( cd "$D" && "$BIN" reorder-params fixsig.hbp Widget:Grow "nDy,nDx" > ren.log 2>&1 )
RC=$?
check "reorder of a unique method exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
test "$(grep -c "METHOD Grow( nDy, nDx )" "$D/w1.prg")" = "2"
check "prototype AND implementation signature reordered" $?
grep -q "hb_ntos( nDx + nDy )" "$D/w1.prg"
check "method body left untouched (params keep their names)" $?
grep -q "oW:Grow( 2, 1 )" "$D/w2.prg"
check "send call site arguments reordered" $?
grep -q "símbolos intactos" "$D/ren.log"
check "verified: symbols/functions intact (pcode legitimately changed)" $?
( cd "$D" && $HB_BIN/hbmk2 w1.prg w2.prg -oapp_after -gtcgi -q0 > /dev/null 2>&1 && ./app_after > saida_depois.txt 2>/dev/null )
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execution identical after reorder" $?
( cd "$D" && "$BIN" reorder-params fixsig.hbp Widget:Grow "nDx,nDy" > /dev/null 2>&1 )
cmp -s "$D/w1.prg" "$HERE/fixsig/w1.prg" && cmp -s "$D/w2.prg" "$HERE/fixsig/w2.prg"
check "A->B->A round-trip byte-exact"  $?
# Resize é homônimo (Widget e Panel) -> send é despacho dinâmico -> recusa
( cd "$D" && "$BIN" reorder-params fixsig.hbp Widget:Resize "nH,nW" > amb.log 2>&1 )
RC=$?
check "method owned by two classes refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "mais de uma classe" "$D/amb.log" && grep -q "PANEL" "$D/amb.log"
check "refusal names the classes and the dynamic dispatch" $?
cmp -s "$D/w1.prg" "$HERE/fixsig/w1.prg" && cmp -s "$D/w2.prg" "$HERE/fixsig/w2.prg"
check "sources untouched by the refusal" $?

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
