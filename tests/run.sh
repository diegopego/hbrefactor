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
# tcheck: asserts que eram heredocs python3 (B-infra Etapa 2 - toolchain única)
TCHECK="${TCHECK:-$HERE/../bin/tcheck}"
[ -x "$TCHECK" ] || { echo "tcheck ausente ($TCHECK) - rode via make test"; exit 1; }
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

freshext() { # freshext <case-name> -> fixture for extract-to-method (B4e P2a)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixext/*.prg "$HERE"/fixext/*.hbp "$HERE"/fixext/*.ch "$d"/
   echo "$d"
}

freshrcv() { # freshrcv <case-name> -> fixture for the language type channel (B4f)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixrcv/*.prg "$HERE"/fixrcv/*.hbp "$HERE"/fixrcv/*.ch "$d"/
   echo "$d"
}

freshdis() { # freshdis <case-name> -> fixture for dispatch resolution (B4f-2)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixdis/*.prg "$HERE"/fixdis/*.hbp "$d"/
   echo "$d"
}

freshb7() { # freshb7 <case-name> -> fixture for interprocedural types (B7)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixb7/*.prg "$HERE"/fixb7/*.hbp "$d"/
   echo "$d"
}

freshb7b() { # freshb7b <case-name> -> fixture for inference slice 3 (B7b)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixb7b/*.prg "$HERE"/fixb7b/*.ch "$HERE"/fixb7b/*.hbp "$d"/
   echo "$d"
}

freshkt() { # freshkt <case-name> -> fixture for imposed type checks (B9, -kt)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixkt/*.prg "$HERE"/fixkt/*.hbp "$d"/
   echo "$d"
}

freshhom() { # freshhom <case-name> -> fixture for DSL homonym generality (B4f-3)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixhom/*.prg "$HERE"/fixhom/*.hbp "$HERE"/fixhom/*.ch "$d"/
   echo "$d"
}

freshcst() { # freshcst <case-name> -> fixture with the REAL xhb cstruct DSL
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixcst/*.prg "$HERE"/fixcst/*.hbp "$d"/
   cp "$HB_BIN/../../../contrib/xhb/cstruct.ch" "$HB_BIN/../../../contrib/xhb/hbctypes.ch" "$d"/
   echo "$d"
}

freshb4g() { # freshb4g <case-name> -> fixture da regra por dentro (B4g/ast-5)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixb4g/* "$d"/
   echo "$d"
}

freshofi() { # freshofi <case-name> -> fixture with a NON-mirror user DSL (revisão Q1-Q3/Q7)
   local d="$HERE/tmp/$1"
   rm -rf "$d"; mkdir -p "$d"
   cp "$HERE"/fixofi/*.prg "$HERE"/fixofi/*.ch "$HERE"/fixofi/*.hbp "$d"/
   echo "$d"
}

extrun() { # extrun <dir> <out-file> -> build fixext copy and run it
   ( cd "$1" && rm -rf .hbmk && "$HB_BIN/hbmk2" e1.prg e2.prg -oapp -gtcgi -q0 > /dev/null 2>&1 && ./app > "$2" 2>/dev/null )
}

ofirun() { # ofirun <dir> <out-file> -> build fixofi copy and run it
   ( cd "$1" && rm -rf .hbmk && "$HB_BIN/hbmk2" o1.prg o2.prg -oapp -gtcgi -q0 > /dev/null 2>&1 && ./app > "$2" 2>/dev/null )
}

# ---------------------------------------------------------------------------
# B-infra: cada caso e uma funcao auto-contida (R3). Os casos 67-69
# continuam no $D do caso 66 e releem o pm.log dele - sao UMA unidade
# (unit_66). Nao ha outro acoplamento entre casos (auditoria 2026-07-07:
# nenhuma variavel herdada entre blocos, compiles em fixture compartilhada
# sao todos -s, so leitura).
# ---------------------------------------------------------------------------

unit_0() {
echo "case 0: base fixtures compile clean under the flags the .hbp declares"
# the fixture project declares -w3 -es2; the fixtures themselves must be
# warning-clean idiomatic Harbour (a warning that slips through here is a
# fixture bug, e.g. a bare PRIVATE reference without a MEMVAR declaration)
for f in a.prg b.prg; do
   "$HB_BIN/harbour" "$HERE/fix01/$f" -n -q0 -w3 -es2 -s -I"$HERE/fix01" > /dev/null 2>&1
   check "$f clean under -w3 -es2"  $?
done

}

unit_1() {
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

}

unit_2() {
echo "case 2: collision with existing local (refuse)"
D=$(fresh case2)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Main nTotal i > out.log 2>&1 )
RC=$?
check "exit != 0"                  $([ $RC -ne 0 ] && echo 0 || echo 1)
cmp -s "$D/a.prg" "$HERE/fix01/a.prg"
check "a.prg untouched"            $?

}

unit_3() {
echo "case 3: unrelated #define on the declaration line (safe rename succeeds)"
D=$(fresh case3)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg LimiteMax nMax nTeto > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "nTeto := K_LIMITE" "$D/a.prg"
check "nTeto renamed, define kept" $?
grep -q "verified: all 2 module" "$D/out.log"
check "verification passed"        $?

}

unit_4() {
echo "case 4: new name is reserved word written as 'nIL' (refuse)"
D=$(fresh case4)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Main nTotal nIL > out.log 2>&1 )
RC=$?
check "exit != 0"                  $([ $RC -ne 0 ] && echo 0 || echo 1)

}

unit_5() {
echo "case 5: homonymous codeblock parameter shadows target (refuse)"
D=$(fresh case5)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Sombra xVal xNovo > out.log 2>&1 )
RC=$?
check "exit != 0"                  $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -qi "shadow" "$D/out.log"
check "reason mentions shadowing"  $?
cmp -s "$D/a.prg" "$HERE/fix01/a.prg"
check "a.prg untouched"            $?

}

unit_6() {
echo "case 6: variable does not exist (refuse)"
D=$(fresh case6)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Main naoExiste nQualquer > out.log 2>&1 )
RC=$?
check "exit != 0"                  $([ $RC -ne 0 ] && echo 0 || echo 1)

}

unit_7() {
echo "case 7: symbol consumed by stringify marker - verification must roll back"
D=$(fresh case7)
( cd "$D" && "$BIN" rename-local fix01.hbp a.prg Rotulada nVisto nOutro > out.log 2>&1 )
RC=$?
check "exit != 0"                  $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -qi "rollback" "$D/out.log"
check "reports rollback"           $?
cmp -s "$D/a.prg" "$HERE/fix01/a.prg"
check "a.prg restored byte-exact"  $?

}

unit_8() {
echo "case 8: usages of a function across modules"
D=$(fresh case8)
( cd "$D" && "$BIN" usages fix01.hbp Dupla > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "b.prg:5: definition (function)" "$D/out.log"
check "definition found in b.prg"  $?
grep -q "a.prg:10: call in MAIN" "$D/out.log"
check "call found in a.prg (Main)" $?

}

unit_9() {
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

}

unit_10() {
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

}

unit_11() {
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

}

unit_12() {
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

}

unit_13() {
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

}

unit_14() {
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

}

unit_15() {
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

}

unit_16() {
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

}

unit_17() {
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

}

unit_18() {
echo "case 18: usages --json emits LSP Location[]"
D=$(fresh case18)
( cd "$D" && "$BIN" usages fix01.hbp Dupla --json locs.json > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
"$TCHECK" locs18 "$D/locs.json"
check "Location[] valid with def+call" $?
# spec ABSOLUTO (o caminho que a extensão VSCode sempre passa): o URI não
# pode duplicar o prefixo do cwd - regressão do LocationsJson (hb_PathJoin,
# não hb_FNameMerge, para não concatenar caminho já absoluto)
( cd "$D" && "$BIN" usages "$D/fix01.hbp" Dupla --json absl.json > /dev/null 2>&1 )
"$TCHECK" absuri18 "$D/absl.json"
check "absolute spec: URI not doubled (extension path)" $?

}

unit_19() {
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

}

unit_20() {
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

}

unit_21() {
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

}

unit_22() {
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

}

unit_23() {
echo "case 23: sends (Eval) and PRIVATE initialization visible"
D=$(fresh case23)
( cd "$D" && "$BIN" usages fix01.hbp Eval > eval.log 2>&1 )
RC=$?
check "usages Eval exit 0"         $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "a.prg:10: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/eval.log"
check "Eval listed as possible send (B4f: receiver unknown)" $?
( cd "$D" && "$BIN" usages fix01.hbp xCfg > priv.log 2>&1 )
RC=$?
check "usages xCfg exit 0"         $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "write (memvar) in COMPRIVADA" "$D/priv.log"
check "PRIVATE init write listed"  $?
grep -q "read (memvar) in COMPRIVADA" "$D/priv.log"
check "later read listed"          $?

}

unit_24() {
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

}

unit_25() {
echo "case 25: aliased variables (M-> and alias->) visible in usages"
D=$(fresh case25)
printf '\nFUNCTION UsaAlias()\n\n   M->xGlob := 1\n\n   RETURN M->xGlob + CLIENTES->saldo\n' >> "$D/b.prg"
( cd "$D" && "$BIN" usages fix01.hbp xGlob > mv.log 2>&1 && "$BIN" usages fix01.hbp saldo > fld.log 2>&1 )
check "both usages exit 0"         $?
grep -q "write (memvar) in USAALIAS" "$D/mv.log"
check "M-> write listed as memvar" $?
grep -q "read (field) in USAALIAS" "$D/fld.log"
check "alias-> read listed as field" $?

}

unit_26() {
echo "case 26: usages --json carries real columns"
D=$(fresh case26)
( cd "$D" && "$BIN" usages fix01.hbp Dupla --json locs.json > out.log 2>&1 )
"$TCHECK" cols26 "$D/locs.json"
check "columns present in Location[]" $?

}

unit_27() {
echo "case 27: rename-function warns about DYNAMIC in .hbx export file"
D=$(fresh case27)
printf 'DYNAMIC Dupla\n' > "$D/exports.hbx"
printf 'exports.hbx\n' >> "$D/fix01.hbp"
( cd "$D" && "$BIN" rename-function fix01.hbp Dupla Dobrar > out.log 2>&1 )
RC=$?
check "refused without --force"    $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "DYNAMIC DUPLA em export (.hbx)" "$D/out.log"
check "hbx warning listed"         $?

}

unit_28() {
echo "case 28: project as a plain list of .prg files (no .hbp)"
D=$(fresh case28)
( cd "$D" && "$BIN" usages "a.prg,b.prg" Dupla > out.log 2>&1 )
RC=$?
check "exit 0"                     $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "definition (function)" "$D/out.log"
check "definition found"           $?
grep -q "call in MAIN" "$D/out.log"
check "call found"                 $?

}

unit_29() {
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

}

unit_30() {
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

}

unit_31() {
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

}

unit_32() {
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

}

unit_33() {
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

}

unit_34() {
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

}

unit_35() {
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

}

unit_36() {
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

}

unit_37() {
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

}

unit_38() {
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

}

unit_39() {
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
grep -q "w2.prg:7: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/out.log"
check "send site across modules: possible honesto (RE.3 - cadeia de construção é inferência)" $?
( cd "$D" && "$BIN" usages fixcls.hbp Paint --show-expansion > exp.log 2>&1 )
grep -q "method definition Paint (class UWMenu) -> UWMENU_PAINT" "$D/exp.log"
check "--show-expansion reveals the generated function" $?
( cd "$D" && "$BIN" usages fixcls.hbp METHOD > mth.log 2>&1 )
grep -q "hbclass.ch:" "$D/mth.log"
check "hbclass.ch rules reported as the DSL they are" $?
grep -q "w1.prg:11:1: application (#xcommand METHOD" "$D/mth.log"
check "hbclass.ch application with span in USER source" $?

}

unit_40() {
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

}

unit_41() {
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

}

unit_42() {
echo "case 42: S5 - ppApplications matches the pp trace (.ppt) 1:1"
D=$(freshdsl case42)
( cd "$D" && "$BIN" dump fixdsl.hbp > dump.log 2>&1 )
RC=$?
check "dump exit 0"                   $([ $RC -eq 0 ] && echo 0 || echo 1)
DIR=$(sed -n 's/^dumps em: //p' "$D/dump.log")
( cd "$D" && "$HB_BIN/harbour" a.prg -n -q0 -i. -s '-p+' > /dev/null 2>&1 )
"$TCHECK" ppt42 "$D/a.ppt" "$DIR/a.ast.json"
check "count, order, lines and kinds match the .ppt trace" $?

}

unit_43() {
echo "case 43: DSL-created block structure guards extract-function"
D=$(freshdsl case43)
( cd "$D" && "$BIN" extract-function fixdsl.hbp a.prg 19-20 Pedaco > ext.log 2>&1 )
RC=$?
check "selection cutting REPEAT without UNTIL refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "abre while (linha 19) que fecha fora dela" "$D/ext.log"
check "refusal is structural (block facts), line exact" $?
cmp -s "$D/a.prg" "$HERE/fixdsl/a.prg"
check "a.prg untouched"               $?

}

unit_44() {
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

}

unit_45() {
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

}

unit_46() {
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

}

unit_47() {
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

}

unit_48() {
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

}

unit_49() {
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

}

unit_50() {
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

}

unit_51() {
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

}

unit_52() {
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

}

unit_53() {
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

}

unit_54() {
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

}

unit_55() {
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

}

unit_56() {
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

}

unit_57() {
echo "case 57: B4e P2b - call-graph resolve método -> símbolo; sends = arestas dinâmicas"
# call-graph <método> responde a DEFINIÇÃO (nome gerado) e lista os SENDS que
# o invocam como arestas DINÂMICAS (~>), nunca estáticas. Mensagem homônima em
# duas classes = alvo de dispatch ambíguo (todos listados).
D=$(freshsig case57)
( cd "$D" && "$BIN" call-graph fixsig.hbp Widget:Grow > cg.log 2>&1 )
check "call-graph on a method exit 0" $?
grep -q "definition WIDGET:GROW -> WIDGET_GROW" "$D/cg.log"
check "method resolved to its generated symbol (definition)" $?
grep -q "MAIN ~> GROW  \[dynamic: WIDGET_GROW\]" "$D/cg.log"
check "send site listed as a dynamic edge to the method" $?
! grep -q "MAIN -> GROW" "$D/cg.log"
check "no invented STATIC edge for the dispatched method" $?
( cd "$D" && "$BIN" call-graph fixsig.hbp Resize > cgr.log 2>&1 )
grep -q "definition WIDGET:RESIZE -> WIDGET_RESIZE" "$D/cgr.log" && \
   grep -q "definition PANEL:RESIZE -> PANEL_RESIZE" "$D/cgr.log"
check "homonym message shows both classes' definitions" $?
grep -q "dynamic: WIDGET_RESIZE | PANEL_RESIZE" "$D/cgr.log"
check "dynamic edge shows the ambiguous dispatch targets" $?

}

unit_58() {
echo "case 58: B4e P3 - find-dynamic-calls filtra o ruído do & da expansão hbclass"
# a função da classe (CREATE CLASS) tem usesMacro=T por causa do & INTERNO da
# expansão do hbclass.ch - falso positivo. Só macro REAL do usuário (token '&'
# posicionado, prov 's') deve ser reportada.
D=$(freshsig case58)
( cd "$D" && "$BIN" find-dynamic-calls fixsig.hbp > fd.log 2>&1 )
grep -q "^0 finding" "$D/fd.log"
check "clean class project reports 0 (hbclass & noise suppressed)" $?
! grep -qi "WIDGET uses & macros" "$D/fd.log" && ! grep -qi "PANEL uses & macros" "$D/fd.log"
check "the class functions are not flagged" $?
printf '\nFUNCTION Dyn( cMsg )\n   RETURN &cMsg.()\n' >> "$D/w2.prg"
( cd "$D" && "$BIN" find-dynamic-calls fixsig.hbp > fd2.log 2>&1 )
grep -q "function DYN uses & macros" "$D/fd2.log"
check "a real user macro is still flagged" $?
grep -q "^1 finding" "$D/fd2.log"
check "exactly the user macro, none of the class noise" $?

}

unit_59() {
echo "case 59: B4e P2a - extract-function em corpo de método (extract-to-method)"
# range que usa ::/Self extrai para um NOVO METHOD da mesma classe: corpo
# verbatim (::/sends/Super continuam válidos - mesma classe), protótipo
# inserido após o do método de origem (mesma seção de visibilidade),
# assinatura proto == impl (o hbclass casa a assinatura inteira - P1a).
# Verificação por fatos previstos: +símbolo gerado (PredictText sobre o
# composto), símbolo da mensagem, string de registro no pcode da classe.
for f in e1.prg e2.prg; do
   "$HB_BIN/harbour" "$HERE/fixext/$f" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" -I"$HERE/fixext" > /dev/null 2>&1
   check "fixext/$f clean under -w3 -es2"  $?
done
# (a) membros lidos E escritos + send interno + migração de declaração
D=$(freshext case59a)
extrun "$D" saida_antes.txt
check "fixture runs before"           $?
( cd "$D" && "$BIN" extract-function fixext.hbp e1.prg 21-25 Miolo > ex.log 2>&1 )
RC=$?
check "extract of a ::-using range exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "novo método Conta:Miolo( nValor )" "$D/ex.log"
check "reports the new METHOD of the class" $?
grep -q "::Miolo( nValor )" "$D/e1.prg"
check "call site is a send on Self (::)" $?
test "$(sed -n '10p' "$D/e1.prg")" = "   METHOD Miolo( nValor )"
check "prototype inserted right after the source method's prototype" $?
grep -q "METHOD Miolo( nValor ) CLASS Conta" "$D/e1.prg"
check "implementation signature matches the prototype" $?
grep -q "LOCAL nTaxa, nLiquido" "$D/e1.prg"
check "selection-only locals migrated into the new method" $?
grep -q "verified: símbolos preservados (+Conta_Miolo), mensagem Miolo registrada" "$D/ex.log"
check "verification: predicted symbol + message registration" $?
extrun "$D" saida_depois.txt
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execution identical after extract" $?
# (b) range com ::Super: o método novo fica na MESMA classe - binding igual
D=$(freshext case59b)
extrun "$D" saida_antes.txt
( cd "$D" && "$BIN" extract-function fixext.hbp e1.prg 64-65 PosDeposito > ex.log 2>&1 )
RC=$?
check "extract of a ::Super-using range exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "::PosDeposito( nValor, nAntes )" "$D/e1.prg"
check "crossing locals become send arguments" $?
extrun "$D" saida_depois.txt
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execution identical (Super binding preserved)" $?
# (c) local escrita no range e usada depois: vira valor de retorno
D=$(freshext case59c)
extrun "$D" saida_antes.txt
( cd "$D" && "$BIN" extract-function fixext.hbp e1.prg 31-34 SomaTudo > ex.log 2>&1 )
RC=$?
check "extract with an out-value exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "nTotal := ::SomaTudo( nQtde )" "$D/e1.prg"
check "out-value assigned from the send" $?
grep -q "   RETURN nTotal" "$D/e1.prg"
check "new method returns the out-value" $?
extrun "$D" saida_depois.txt
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execution identical with out-value" $?
# (d) range SEM ::/Self dentro de método TAMBÉM extrai método (o alvo é
# decidido pelo CONTÊINER, não pelo range - dogfooding do Diego, hbhttpd:
# extrair função de dentro de método surpreende)
D=$(freshext case59d)
extrun "$D" saida_antes.txt
( cd "$D" && "$BIN" extract-function fixext.hbp e1.prg 21-22 CalculaLiquido > ex.log 2>&1 )
RC=$?
check "extract of a Self-free range in a method exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "novo método Conta:CalculaLiquido( nValor )" "$D/ex.log"
check "container is a method => target is a METHOD even without Self" $?
grep -q "nLiquido := ::CalculaLiquido( nValor )" "$D/e1.prg"
check "call site is a send with the out-value" $?
extrun "$D" saida_depois.txt
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execution identical for the Self-free extract" $?

}

unit_60() {
echo "case 60: B4e P2a - recusas fato-a-fato e aviso honesto"
# cada recusa nasce de um FATO do dump (occurrence de SELF, membro registrado
# por stringify, send existente, protótipo sem posição); pai fora do projeto
# é fato inexistente em compilação -> AVISO, nunca palpite (regra do Diego)
D=$(freshext case60)
( cd "$D" && "$BIN" extract-function fixext.hbp e1.prg 43-43 Pedaco > r1.log 2>&1 )
RC=$?
check "range reassigning Self refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "reatribui Self" "$D/r1.log"
check "refusal names the Self reassignment" $?
( cd "$D" && "$BIN" extract-function fixext.hbp e1.prg 47-47 Pedaco > r2.log 2>&1 )
RC=$?
check "range passing @Self refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "por referência" "$D/r2.log"
check "refusal names the by-reference Self" $?
( cd "$D" && "$BIN" extract-function fixext.hbp e1.prg 21-25 nReservado > r3.log 2>&1 )
RC=$?
check "name colliding with a class VAR refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "já é membro (VAR/DATA/METHOD) da classe CONTA" "$D/r3.log"
check "refusal names the owning class (registration fact)" $?
( cd "$D" && "$BIN" extract-function fixext.hbp e1.prg 64-65 nReservado > r4.log 2>&1 )
RC=$?
check "name colliding with an INHERITED member refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "já é membro (VAR/DATA/METHOD) da classe CONTA" "$D/r4.log"
check "ancestor chain walked to the in-project parent" $?
( cd "$D" && "$BIN" extract-function fixext.hbp e1.prg 21-25 Extrato > r5.log 2>&1 )
RC=$?
check "name whose generated symbol exists refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "Conta_Extrato" "$D/r5.log"
check "refusal names the generated symbol" $?
( cd "$D" && "$BIN" extract-function fixext.hbp e1.prg 21-25 Processa > r6.log 2>&1 )
RC=$?
check "name already SENT in the project refused (dynamic dispatch)" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "já é mensagem enviada em e2.prg:5" "$D/r6.log"
check "refusal points at the existing send site" $?
( cd "$D" && "$BIN" extract-function fixext.hbp e2.prg 17-17 Pedaco > r7.log 2>&1 )
RC=$?
check "Self-using range OUTSIDE a method refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "não é método de classe" "$D/r7.log"
check "refusal says the container is not a method" $?
( cd "$D" && "$BIN" extract-function fixext.hbp e2.prg 9-10 Pedaco > r8.log 2>&1 )
RC=$?
check "method of a class declared in an include refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "classe declarada em include" "$D/r8.log"
check "refusal explains the prototype lives in an include" $?
cmp -s "$D/e1.prg" "$HERE/fixext/e1.prg" && cmp -s "$D/e2.prg" "$HERE/fixext/e2.prg"
check "sources untouched by all refusals" $?
# pai fora do projeto: extração procede com AVISO nomeando o não-verificável
extrun "$D" saida_antes.txt
( cd "$D" && "$BIN" extract-function fixext.hbp e2.prg 27-28 Passo > w1.log 2>&1 )
RC=$?
check "class FROM an out-of-project parent still extracts" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "warning: pai HBPERSISTENT fora do projeto" "$D/w1.log"
check "honest warning names the unverifiable parent" $?
test "$(grep -c "warning: pai" "$D/w1.log")" = "1"
check "only the real parent is warned (FROM word filtered by stream fact)" $?
extrun "$D" saida_depois.txt
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execution identical after warned extract" $?

}

unit_61() {
echo "case 61: B4f fatia 0 - usages aceita Classe:Método + camada 'possible' nos sends"
# Backlog 5 (dogfooding hbhttpd): no ast-3 o send não carregava a classe do
# receptor e TODO send era 'possible (dynamic dispatch, receiver unknown)' -
# removia a mentira do rótulo 'uso' seco. RE.3 (2026-07-09): a cadeia de
# construção é INFERÊNCIA e saiu do veredito de produto - send sem fato
# declarado volta ao possible pleno; o fato de VALOR (a := {}) segue
# excluindo. A forma Classe:Método resolve pela mesma via do PickFunc
# (rastro B4d) e filtra a DEFINIÇÃO pela classe.
D=$(freshcls case61)
printf '\nPROCEDURE Solto()\n\n   LOCAL a := {}\n\n   a:Paint()\n\n   RETURN\n' >> "$D/w2.prg"
"$HB_BIN/harbour" "$D/w2.prg" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" > /dev/null 2>&1
check "fixture with Diego's a := {} case compiles clean" $?
( cd "$D" && "$BIN" usages fixcls.hbp UWMenu:Paint > cm.log 2>&1 )
RC=$?
check "usages Classe:Método exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "w1.prg:11: method definition Paint (class UWMenu)" "$D/cm.log"
check "definition resolved and filtered by class" $?
grep -q "w2.prg:7: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/cm.log"
check "send sem fato declarado: possible pleno (RE.3), nunca 'uso' seco" $?
grep -q "w2.prg:15: excluded send (receiver holds a value of kind array) in SOLTO" "$D/cm.log"
check "a:Paint() with a := {} is excluded by the value fact (B4f fatia 1)" $?
! grep -q "UWMENU_PAINT" "$D/cm.log"
check "generated name never leaks without --show-expansion" $?
# homônimos: a definição é da classe pedida; os SENDS sem fato declarado
# ficam possible (RE.3 - a separação por cadeia de construção era inferência)
D=$(freshmth case61b)
( cd "$D" && "$BIN" usages fixmth.hbp Caixa:Soma > ca.log 2>&1 )
RC=$?
check "usages Caixa:Soma exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "c1.prg:11: method definition Soma (class Caixa)" "$D/ca.log"
check "only the asked class's definition listed" $?
! grep -q "class Outra" "$D/ca.log"
check "homonym method of the other class filtered out" $?
grep -q "c2.prg:28: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/ca.log" && \
   grep -q "c2.prg:30: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/ca.log"
check "sends sem fato declarado: possible pleno nos dois (RE.3)" $?
( cd "$D" && "$BIN" usages fixmth.hbp Outra:Soma > ou.log 2>&1 )
grep -q "c2.prg:10: method definition Soma (class Outra)" "$D/ou.log" && \
   ! grep -q "class Caixa" "$D/ou.log"
check "the mirror query resolves the other class" $?
( cd "$D" && "$BIN" usages fixmth.hbp Caixa: > mf.log 2>&1 )
RC=$?
check "malformed Classe: refused" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "malformada" "$D/mf.log"
check "refusal names the malformed form" $?

}

unit_62() {
echo "case 62: B4f fatia 1 - canal de tipos: declarado, cadeia de ctor, valor, honestos"
# ast-4 transporta o CANAL DE TIPOS DA LINGUAGEM (AS CLASS nas declarations,
# tabelas DECLARE/_HB_CLASS/_HB_MEMBER em declared) e a ferramenta PROPAGA
# tipos declarados (TypeOf, regra fechada). A cadeia Caixa():New() é toda
# declarada pelo hbclass (_HB_CLASS auto-declara a função-classe; o ctor
# declara o retorno) - nenhuma convenção reconhecida por nome.
for f in r1.prg r2.prg; do
   "$HB_BIN/harbour" "$HERE/fixrcv/$f" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" -I"$HERE/fixrcv" > /dev/null 2>&1
   check "fixrcv/$f clean under -w3 -es2" $?
done
D=$(freshrcv case62)
( cd "$D" && "$BIN" usages fixrcv.hbp Caixa:Soma > cs.log 2>&1 )
check "usages Caixa:Soma exit 0" $?
grep -q "confirmed send (receiver class CAIXA via declared types) in CENARIOS  | g:Soma( 2 )" "$D/cs.log"
check "g := Caixa():New() confirmed pela cadeia declarada (ctor)" $?
grep -q "excluded send (receiver holds a value of kind array) in CENARIOS  | a:Soma( 1 )" "$D/cs.log"
check "a := {} excluded pelo fato de valor" $?
grep -q "confirmed send (receiver declared AS CLASS CAIXA) in CENARIOS  | d:Soma( 3 )" "$D/cs.log"
check "AS CLASS explícito confirmed por declaração direta" $?
grep -q "confirmed send (receiver declared AS CLASS CAIXA) in CAIXA_DOBRA  | ::Soma( ::nTot )" "$D/cs.log"
check "::/Self confirmed (Self AS CLASS da expansão hbclass)" $?
grep -q "possible send (dynamic dispatch, receiver unknown) in CENARIOS  | r:Soma( 4 )" "$D/cs.log"
check "variável passada por @ fica possible (ref quebra o binding único)" $?
grep -q "possible send (dynamic dispatch, receiver unknown) in CENARIOS  | m:Soma( 5 )" "$D/cs.log" && \
   grep -q "possible send (dynamic dispatch, receiver unknown) in CENARIOS  | m:Soma( 8 )" "$D/cs.log"
check "variável reatribuída fica possible (2 writes)" $?
grep -q "confirmed send (receiver class CAIXA via declared types) in CENARIOS  | f:Soma( 7 )" "$D/cs.log"
check "DECLARE escrito à mão classifica o funcall (canal sem DSL)" $?
grep -q "confirmed send (receiver class CAIXA via declared types) in USA  | x:Soma( 6 )" "$D/cs.log"
check "cross-módulo: declared de r1 classifica send em r2" $?
# --json (o que a extensão VSCode consome no find-references): excluded é
# não-referência PROVADA e NÃO pode virar Location; confirmed/possible sim
( cd "$D" && "$BIN" usages fixrcv.hbp Caixa:Soma --json locs.json > /dev/null 2>&1 )
"$TCHECK" json62 "$D/locs.json"
check "--json: excluded fora das Locations, confirmed/possible dentro" $?

}

unit_63() {
echo "case 63: B4f/RE.3 - honestidade: sem fato declarado, possible; declarado confirma"
# RE.3 (2026-07-09): a cadeia de construção + oráculo (B7/D3) é INFERÊNCIA
# e saiu do veredito - Semctor():New() sem fato declarado fica possible,
# como Misterio(). O canal DECLARADO segue decidindo: g com tipo declarado
# confirma pela cadeia de declarados (via declared types).
D=$(freshrcv case63)
( cd "$D" && "$BIN" usages fixrcv.hbp Zap > zp.log 2>&1 )
check "usages Zap exit 0" $?
grep -q "method definition Zap (class Semctor)" "$D/zp.log"
check "definição lifted no vocabulário de classe" $?
grep -q "possible send (dynamic dispatch, receiver unknown) in USA  | s:Zap()" "$D/zp.log"
check "classe sem ctor declarado: possible pleno (RE.3 - cadeia era inferência)" $?
grep -q "possible send (dynamic dispatch, receiver unknown) in USA  | t:Zap()" "$D/zp.log"
check "função sem declaração: send fica possible (honesto)" $?
( cd "$D" && "$BIN" usages fixrcv.hbp Soma > sm.log 2>&1 )
grep -q "confirmed send (receiver class CAIXA via declared types) in CENARIOS  | g:Soma( 2 )" "$D/sm.log"
check "consulta por nome cru também classifica em camadas" $?

}

unit_64() {
echo "case 64: B4f - A PROVA DO REQUISITO: DSL inventado refatorável sem tocar em nada"
# gizmo.ch define comandos PRÓPRIOS (CONTRAPTION/APTITUDE/GIZMO) que
# declaram pelo canal da linguagem na expansão. A classificação sai
# confirmed SEM nenhuma mudança em harbour ou hbrefactor - e a ferramenta
# não menciona nenhuma palavra do DSL (o hbclass é só o primeiro cliente
# do mesmo canal).
D=$(freshrcv case64)
( cd "$D" && "$BIN" usages fixrcv.hbp Duplicador:Espelho > de.log 2>&1 )
check "usages de método de DSL inventado exit 0" $?
grep -q "confirmed send (receiver class DUPLICADOR via declared types) in USA  | w:Espelho()" "$D/de.log"
check "w := MakeDup() confirmed pela declaração do PRÓPRIO DSL" $?
test "$(grep -c "confirmed send (receiver class DUPLICADOR via declared types) in USA  | w:Espelho():Espelho()" "$D/de.log")" = "2"
check "send ENCADEADO confirmed (retorno declarado do método do DSL)" $?
! grep -qiE "contraption|aptitude|gizmo|duplicador" "$HERE/../src/hbrefactor.prg"
check "a ferramenta não menciona NENHUMA palavra do DSL (genérico de fato)" $?
# sem palavra do DSL e sem NENHUMA mensagem reconhecida por nome ("NEW"
# etc.) - o writer transporta o canal 1:1, convenção não entra no core
test -f "$HB_BIN/../../../src/compiler/compast.c" && \
   ! grep -qiE "contraption|aptitude|gizmo" "$HB_BIN/../../../src/compiler/compast.c" && \
   ! grep -q '"NEW"' "$HB_BIN/../../../src/compiler/compast.c"
check "o core tampouco (transporte 1:1 do canal, sem convenções)" $?

}

unit_65() {
echo "case 65: B4f - consistência do dump: canal re-derivável dos fatos brutos"
# invariantes do ast-4 verificados sobre o dump real: Self tipado em todo
# método, declared coerente (classe/função/ctor), e o binding único usado
# pelo TypeOf re-derivado de occurrences+statements (mesma resposta).
D=$(freshrcv case65)
DIR=$( cd "$D" && "$BIN" dump fixrcv.hbp 2>/dev/null | sed -n 's/^dumps em: //p' )
test -n "$DIR" && test -f "$DIR/r1.ast.json"
check "dump ast-4 gerado" $?
"$TCHECK" cons65 "$DIR" > "$D/cons.log" 2>&1
grep -q "^consistente$" "$D/cons.log"
check "invariantes do canal verificados sobre o dump real" $?

}

unit_66() {
echo "case 66: RE.3 - homônimos SEM dispatch por grafo: fato decide, resto possible"
# duas classes com métodos homônimos (UWMain/UWSecondary, ambas Add/Paint).
# A B4f-2 excluía pelo dispatch sobre o grafo as-written; o RE.3 (portão
# do Diego, 2026-07-09) removeu o grafo do veredito - a exclusão dependia
# de mundo fechado sobre parents de FORMA (inferência). O que decide hoje:
# o canal declarado do PRÓPRIO receptor - classe igual à consultada
# confirma; classe conhecida DIFERENTE fica possible NOMEANDO o que se
# sabe (receiver class X, relation unknown); sem fato, possible pleno.
# A separação de homônimos por SEND volta ao materializador/RE.6.
for f in d1.prg d2.prg d3.prg d4.prg; do
   "$HB_BIN/harbour" "$HERE/fixdis/$f" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" > /dev/null 2>&1
   check "fixdis/$f clean under -w3 -es2" $?
done
D=$(freshdis case66)
( cd "$D" && "$BIN" usages fixdis.hbp UWMain:Paint --json pm.json > pm.log 2>&1 )
check "usages UWMain:Paint exit 0" $?
grep -q "confirmed send (receiver class UWMAIN via declared types) in USA66  | oM:Paint()" "$D/pm.log"
check "oM (instância exata de UWMain) segue confirmed" $?
grep -q "possible send (receiver class UWSECONDARY, relation to UWMAIN unknown) in USA66  | oS:Paint()" "$D/pm.log"
check "oS (classe conhecida != consultada): possible nomeando o fato (RE.3)" $?
grep -q "possible send (receiver class UWSECONDARY, relation to UWMAIN unknown) in USA66PROM  | oP:Paint()" "$D/pm.log"
check "receptor DECLARADO de outra classe: mesmo possible (promessa não exclui)" $?
grep -q "possible send (dynamic dispatch, receiver unknown) in USA66NC  | oNm:Paint()" "$D/pm.log" && \
   grep -q "possible send (dynamic dispatch, receiver unknown) in USA66NC  | oNs:Paint()" "$D/pm.log"
check "sem ctor declarado: possible pleno (cadeia de construção era inferência)" $?
( cd "$D" && "$BIN" usages fixdis.hbp UWSecondary:Paint > ps.log 2>&1 )
grep -q "possible send (receiver class UWMAIN, relation to UWSECONDARY unknown) in USA66  | oM:Paint()" "$D/ps.log" && \
   grep -q "confirmed send (receiver class UWSECONDARY via declared types) in USA66  | oS:Paint()" "$D/ps.log"
check "a consulta espelhada inverte o confirmed; o resto fica possible" $?
"$TCHECK" json66 "$D/pm.json" "$D/d1.prg" > "$D/pj.log" 2>&1
grep -q "^json ok$" "$D/pj.log"
check "possible (pós-RE.3) entra nas Location[]; nenhum excluded sem fato" $?

echo "case 67: RE.3 - herança simples: sem grafo no veredito, classe != consultada é possible"
# Q4 já tinha rebaixado o alcance por vínculo escrito a possible NOMEADO;
# o RE.3 tira também a nomeação (derivava do grafo as-written) - fica o
# possible com o fato do próprio receptor. Acerto próprio (override) segue
# confirmando SÓ pela igualdade de classe declarada.
grep -q "possible send (receiver class UWCHILD, relation to UWMAIN unknown) in USA67  | oC:Paint()" "$D/pm.log"
check "filho sem override: possible com o fato do receptor (RE.3)" $?
grep -q "possible send (receiver class UWOVER, relation to UWMAIN unknown) in USA67  | oO:Paint()" "$D/pm.log"
check "filho com override: possible na consulta do pai (exclusão por grafo saiu)" $?
grep -q "possible send (receiver class UWCHILD, relation to UWMAIN unknown) in USA67  | oD:Paint()" "$D/pm.log"
check "receptor declarado do filho: mesmo possible (vínculo não é fato)" $?
( cd "$D" && "$BIN" usages fixdis.hbp UWOver:Paint > po.log 2>&1 )
grep -q "possible send (receiver class UWCHILD, relation to UWOVER unknown) in USA67  | oC:Paint()" "$D/po.log" && \
   grep -q "confirmed send (receiver class UWOVER via declared types) in USA67  | oO:Paint()" "$D/po.log"
check "consulta do override: só o receptor do override confirma; filho é possible" $?

echo "case 68: RE.3 - herança múltipla: sem walk pela ordem escrita, possible com o fato"
# o walk pela ordem escrita e o teste de descendentes eram leitura do
# grafo as-written (inferência) - saíram do veredito com o RE.3. Fica o
# fato do próprio receptor; o declarado da consultada segue confirmando.
( cd "$D" && "$BIN" usages fixdis.hbp HMAlpha:Paint > ha.log 2>&1 )
grep -q "possible send (receiver class HMBOTH, relation to HMALPHA unknown) in USA68  | oB:Paint()" "$D/ha.log"
check "herança múltipla: possible com o fato do receptor (RE.3)" $?
grep -q "possible send (receiver class HMBETA, relation to HMALPHA unknown) in USA68  | oPb:Paint()" "$D/ha.log"
check "promessa de outra classe nunca exclui (independe de descendentes)" $?
( cd "$D" && "$BIN" usages fixdis.hbp HMBeta:Paint > hb.log 2>&1 )
grep -q "possible send (receiver class HMBOTH, relation to HMBETA unknown) in USA68  | oB:Paint()" "$D/hb.log" && \
   grep -q "confirmed send (receiver declared AS CLASS HMBETA) in USA68  | oPb:Paint()" "$D/hb.log"
check "consulta do 2º pai: declarado confirma; HMBoth fica possible" $?

echo "case 69: RE.3 - vínculo de fora do projeto: possible com o fato, sem candidato"
# OPFirst e OPLast convergem no mesmo rótulo honesto: classe conhecida,
# relação com a consultada não provada - a nomeação do candidato pelo walk
# as-written saiu com o RE.3.
( cd "$D" && "$BIN" usages fixdis.hbp OPBase:Paint > ob.log 2>&1 )
grep -q "possible send (receiver class OPFIRST, relation to OPBASE unknown) in USA69  | oF:Paint()" "$D/ob.log"
check "vínculo de fora ANTES do hit: possible honesto, nunca excluded" $?
grep -q "possible send (receiver class OPLAST, relation to OPBASE unknown) in USA69  | oL:Paint()" "$D/ob.log"
check "hit no projeto pelo vínculo escrito: mesmo possible com o fato (RE.3)" $?
! grep -q "excluded.*OPFIRST\|OPFIRST.*excluded" "$D/pm.log" "$D/ob.log"
check "nenhuma consulta exclui send de receptor com cadeia indecidível" $?

}

unit_70() {
echo "case 70: B4f-2 - homônimos de DECLARAÇÃO: protótipo/impl de outra classe fora do find-references"
# Relato do Diego pós-entrega: os SENDS homônimos saíram, mas os protótipos
# 'METHOD Paint()' das outras classes continuavam nas Location[] via camada
# de strings (a string de registro da expansão, sem vínculo de classe). O
# passe de declaração vincula cada site à dona (containment por índice na
# função gerada - mesmos fatos da PpMarkerOwners, site a site) e decide com
# o ResolveDispatch da CONSULTADA: dona == consultada -> declaração; outra
# dona provada no grafo -> excluded (fora das Location[]); indecidível ->
# possible. Q4: resolução da consultada que atravessa vínculo escrito é
# rebaixada a indecidível (o "alvo do dispatch por herança" virou possible).
D=$(freshdis case70)
( cd "$D" && "$BIN" usages fixdis.hbp UWMain:Paint --json pm.json > pm.log 2>&1 )
check "usages UWMain:Paint exit 0" $?
grep -q "d1.prg:13: method declaration (class UWMAIN)  | METHOD Paint()" "$D/pm.log"
check "protótipo da consultada vira declaração (era 'possible reference in string')" $?
grep -q "d1.prg:31: excluded method declaration (declares UWSECONDARY:PAINT)" "$D/pm.log"
check "protótipo homônimo da outra classe excluído com a dona nomeada" $?
grep -q "d1.prg:41: excluded method definition (implements UWSECONDARY:PAINT)" "$D/pm.log"
check "implementação homônima excluída no relato (antes: omitida em silêncio)" $?
! grep -q "possible reference in string" "$D/pm.log"
check "nenhuma string de registro sobra na camada genérica de strings" $?
"$TCHECK" json70 "$D/pm.json" > "$D/pj.log" 2>&1
grep -q "^json ok$" "$D/pj.log"
check "Location[] só com os sites da consultada (o furo da extensão fecha)" $?
( cd "$D" && "$BIN" usages fixdis.hbp UWChild:Paint > ch.log 2>&1 )
grep -q "d1.prg:23: possible method definition (registered under UWMAIN, relation to UWCHILD unknown)" "$D/ch.log" && \
   grep -q "d1.prg:13: possible method declaration (registered under UWMAIN, relation to UWCHILD unknown)" "$D/ch.log"
check "consulta da herdeira: decl/impl do pai vira possible (Q4 - vínculo não prova o alvo)" $?
( cd "$D" && "$BIN" usages fixdis.hbp OPFirst:Paint > of.log 2>&1 )
! grep -q "excluded" "$D/of.log"
check "consultada com cadeia indecidível (fato 9) não exclui NENHUM site" $?

}

unit_71() {
echo "case 71: extensão VSCode - consulta por POSIÇÃO (Q5: methodQuery morto)"
# a extensão não promove nada por regex: manda a posição do cursor
# (usages --at arq:linha:col, 1-based - a conversão do 0-based do editor
# é o risco real e o harness a testa) e o CLI resolve por FATO na MESMA
# invocação (caso 81 é o contrato da resolução). Posição sem
# identificador de compilação cai para a consulta crua da palavra. O
# harness extrai as funções REAIS do extension.js (técnica do harness
# anterior) e ASSERTA a morte da regex de construto (V1).
node "$HERE/../vscode/test-resolveat.js" > /dev/null 2>&1
check "extensão por posição: conversão real + fallback + methodQuery morto" $?

}

unit_72() {
echo "case 72: B4f-3 - A PROVA DA GENERALIDADE: homônimos em DSLs customizadas (#xcommand)"
# DSLs INVENTADAS (rig.ch: RIG/COG/FORGE, espelho estrutural do hbclass;
# amuleto.ch: AMULETO/DOTE, declarativa PURA - só o canal, sem função
# geradora) com donos homônimos ENTRE SI (Totem/Idolo com Brilho; Sol/Lua
# com Fulgor) e CRUZADOS com classe hbclass (Farol:Brilho). A resolução
# decide TUDO pelos fatos genéricos (canal declared no stream, registro
# por string com containment, grafo) - zero ajuste por-caso: a régua do
# caso 64 vale (nenhuma palavra das DSLs na ferramenta) e os rótulos saem
# no VOCABULÁRIO de cada DSL (cabeça da regra raiz: cog, dote, forge).
for f in m1.prg m2.prg m3.prg; do
   "$HB_BIN/harbour" "$HERE/fixhom/$f" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" -I"$HERE/fixhom" > /dev/null 2>&1
   check "fixhom/$f clean under -w3 -es2" $?
done
D=$(freshhom case72)
( cd "$D" && "$BIN" usages fixhom.hbp Totem:Brilho --json tb.json > tb.log 2>&1 )
check "usages Totem:Brilho (dono de DSL) exit 0" $?
grep -q "m1.prg:19: cog declaration (rig TOTEM)  | COG Brilho GIVES Totem" "$D/tb.log"
check "declaração do próprio DSL confirmada NO VOCABULÁRIO do DSL (cog + dono rig, Q6)" $?
grep -q "m1.prg:27: excluded cog declaration (declares IDOLO:BRILHO)" "$D/tb.log"
check "homônimo ENTRE donos de DSL excluído" $?
grep -q "m1.prg:9: excluded method declaration (declares FAROL:BRILHO)" "$D/tb.log" && \
   grep -q "m1.prg:15: excluded method definition (implements FAROL:BRILHO)" "$D/tb.log"
check "homônimo CRUZADO (classe hbclass) excluído da consulta do DSL" $?
grep -q "m1.prg:23: forge definition Brilho (rig Totem)" "$D/tb.log" && \
   grep -q "m1.prg:30: excluded forge definition (implements IDOLO:BRILHO)" "$D/tb.log"
check "implementação por colagem do DSL: própria confirmada, homônima excluída" $?
grep -q "possible send (receiver class FAROL, relation to TOTEM unknown) in USARIG  | oF:Brilho()" "$D/tb.log" && \
   grep -q "confirmed send (receiver class TOTEM via declared types) in USARIG  | oT:Brilho()" "$D/tb.log" && \
   grep -q "possible send (receiver class IDOLO, relation to TOTEM unknown) in USARIG  | oI:Brilho()" "$D/tb.log"
check "sends: o próprio confirma pelo declarado; homônimos ficam possible (RE.3)" $?
"$TCHECK" json72 "$D/tb.json" > "$D/tj.log" 2>&1
grep -q "^json ok$" "$D/tj.log"
check "Location[] com os 3 sites do Totem + os possible pós-RE.3" $?
( cd "$D" && "$BIN" usages fixhom.hbp Sol:Fulgor > sf.log 2>&1 )
grep -q "m2.prg:7: dote declaration (amuleto SOL)  | DOTE Fulgor RENDE Sol" "$D/sf.log" && \
   grep -q "m2.prg:11: excluded dote declaration (declares LUA:FULGOR)" "$D/sf.log"
check "DSL declarativa PURA: declaração própria confirmada, homônima excluída" $?
grep -q "possible send (receiver class LUA, relation to SOL unknown) in USAAMULETO  | l:Fulgor()" "$D/sf.log" && \
   grep -q "confirmed send (receiver class SOL via declared types) in USAAMULETO  | s:Fulgor()" "$D/sf.log"
check "DSL declarativa: declarado confirma o próprio; homônimo é possible (RE.3)" $?
( cd "$D" && "$BIN" usages fixhom.hbp Farol:Brilho > fb.log 2>&1 )
grep -q "m1.prg:9: method declaration (class FAROL)" "$D/fb.log" && \
   grep -q "m1.prg:19: excluded cog declaration (declares TOTEM:BRILHO)" "$D/fb.log" && \
   grep -q "possible send (receiver class TOTEM, relation to FAROL unknown) in USARIG  | oT:Brilho()" "$D/fb.log"
check "consulta espelhada: DECLARAÇÃO homônima segue excluída; send é possible (RE.3)" $?
# fatia 2 (alinhamento do Diego): a generalidade também é de COMANDOS
# NOVOS embrulhando classes JÁ EXISTENTES (`#command mybrowse <a> <b> =>
# tbrowse`) - a instância e o send existem só na EXPANSÃO; o escrito só
# tem o comando. Nenhum ajuste: os fatos fluem da árvore expandida e o
# site relatado é o ESCRITO.
( cd "$D" && "$BIN" usages fixhom.hbp Grade:Pintar > gp.log 2>&1 )
grep -q "confirmed send (receiver class GRADE via declared types) in USAB  | MYPAINT g" "$D/gp.log"
check "send que SÓ existe na expansão: confirmado no site ESCRITO do comando" $?
grep -q "possible send (receiver class LOUSA, relation to GRADE unknown) in USAB  | MYPAINT l" "$D/gp.log"
check "homônimo ATRAVÉS do comando embrulhador: possible com o fato (RE.3)" $?
grep -q "confirmed send (receiver class GRADE via declared types) in USAB  | g:Pintar()" "$D/gp.log"
check "instância criada NA EXPANSÃO classifica o send escrito depois" $?
grep -q "possible send (dynamic dispatch, receiver unknown) in USAB  | MYPAINT t" "$D/gp.log"
check "comando sobre classe de FORA do projeto (TBrowse): possible honesto" $?
# fatia 3: a ESCRITA `o:x := v` envia a mensagem `_X` (fato 11) e a árvore
# guarda ASSIGN->SEND do nome BASE; VAR registra o PAR leitura/escrita em
# runtime (provado: __objHasMsg NT e _NT) e declara via `_HB_MEMBER { a, b }`
# (a lista do canal). Consumo genérico: writes casam, resolvem pelo par e
# o site do VAR aparece.
( cd "$D" && "$BIN" usages fixhom.hbp Grade:nT --json gn.json > gn.log 2>&1 )
grep -q "confirmed send (receiver declared AS CLASS GRADE) in GRADE_NEW  | ::nT := n" "$D/gn.log"
check "ESCRITA ::nT := n casa e confirma (fato 11 + Self tipado)" $?
grep -q "possible send (receiver class LOUSA, relation to GRADE unknown) in LOUSA_NEW" "$D/gn.log"
check "escrita homônima na outra classe: possible com o fato do Self (RE.3)" $?
grep -q "m3.prg:10: var declaration (class GRADE)  | VAR nT INIT 0" "$D/gn.log" && \
   grep -q "m3.prg:23: excluded var declaration (declares LOUSA:NT)" "$D/gn.log"
check "VAR: site de declaração via lista { } do canal, confirmado/excluído" $?
! grep -qiwE "rig|cog|forge|totem|idolo|farol|brilho|amuleto|dote|fulgor|zenite|mybrowse|mylousa|mypaint|mytela|grade|lousa|pintar" "$HERE/../src/hbrefactor.prg"
check "a ferramenta não menciona NENHUMA palavra das DSLs (régua do caso 64)" $?

}

unit_73() {
echo "case 73: B4f-3 - DSL REAL do contrib (xhb/cstruct.ch): classes de RUNTIME, relato honesto"
# apontada pelo Diego como exemplo do que qualquer programador cria no seu
# aplicativo: cstruct cria as classes em RUNTIME (hb_CStructure/__clsNew),
# define regras de pp DE DENTRO da expansão de outras regras (#xtranslate
# IS <stru> nasce do C STRUCTURE) e registra membros por stringify num
# INIT PROCEDURE colado (__INIT_<stru>, sufixo $ do compilador). Nada
# estático cruza classe de runtime: o teto é da linguagem - o contrato é
# relato HONESTO (possible; sites escritos listados), NUNCA over-claim.
D=$(freshcst case73)
( cd "$D" && "$HB_BIN/harbour" c1.prg -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" -I. > /dev/null 2>&1 )
check "fixcst/c1.prg (cstruct REAL) clean under -w3 -es2" $?
( cd "$D" && "$BIN" usages c1.hbp Ponto:x --json px.json > px.log 2>&1 )
check "usages Ponto:x sobre o DSL real exit 0" $?
grep -q "possible send (dynamic dispatch, receiver unknown) in USACST  | p:x := 1" "$D/px.log"
check "ESCRITA p:x := 1 listada (fato 11) como possible honesto" $?
grep -q "possible reference in string  | MEMBER x IS CTYPE_INT" "$D/px.log"
check "MEMBER x (registro por stringify) listado como possible honesto" $?
! grep -qE "excluded|confirmed" "$D/px.log"
check "classe de RUNTIME nunca gera excluded/confirmed (o teto é da linguagem)" $?
( cd "$D" && "$BIN" usages c1.hbp x > x.log 2>&1 )
check "consulta crua x também exit 0 (regras de pp criadas por expansão não quebram)" $?

}

unit_74() {
echo "case 74: B4f-3 - o princípio é CONSTRUTO-AGNÓSTICO: açúcar sobre FUNÇÕES e LOCAIS"
# alinhamento do Diego: classes são SÓ UM CASO. O harbour inteiro se apoia
# em diretivas para criar açúcar sintático; o hbrefactor refatora qualquer
# construto através dele. fixsug: chamada de função que SÓ existe na
# expansão (DOBRA k -> k := Dobro(k)) e local declarado por comando
# (CONTA m -> LOCAL m := 0). Onde o fato não alcança (nome de função no
# CORPO de uma regra), o oráculo RECUSA com rollback - nunca árvore quebrada.
D="$HERE/tmp/case74"; rm -rf "$D"; mkdir -p "$D"
cp "$HERE"/fixsug/* "$D"/
( cd "$D" && "$HB_BIN/harbour" sf1.prg -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" -I. > /dev/null 2>&1 )
check "fixsug/sf1.prg clean under -w3 -es2" $?
( cd "$D" && "$BIN" usages sf1.hbp Dobro > fd.log 2>&1 )
grep -q "sf1.prg:12: call in USAS  | DOBRA k" "$D/fd.log"
check "chamada que SÓ existe na expansão listada no site ESCRITO do comando" $?
( cd "$D" && "$BIN" usages sf1.hbp m --func UsaS > fm.log 2>&1 )
grep -q "sf1.prg:8: declaration (local) in USAS  | CONTA m" "$D/fm.log"
check "LOCAL declarado por comando: declaração no site escrito" $?
( cd "$D" && "$BIN" rename-local sf1.hbp sf1.prg UsaS m mm > rl.log 2>&1 )
RC=$?
check "rename-local através do açúcar exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "CONTA mm" "$D/sf1.prg" && grep -q "mm := Dobro( mm )" "$D/sf1.prg" && \
   grep -q "byte-identical" "$D/rl.log"
check "rename editou o site do comando e verificou byte-idêntico" $?
( cd "$D" && "$BIN" rename-function sf1.hbp Dobro Duplo > rf.log 2>&1 )
RC=$?
check "rename-function com o nome no CORPO da regra: recusa ACIONÁVEL (exit != 0)" $([ $RC -ne 0 ] && echo 0 || echo 1)
# B4g: a recusa deixou de ser cega - nomeia diretiva+posição (match[]/
# result[] do ast-5) ANTES de qualquer edição e oferece --edit-rules
grep -q "suga.ch:2:" "$D/rf.log" && grep -q "in rule result (#command DOBRA)" "$D/rf.log" && \
   grep -q -- "--edit-rules" "$D/rf.log" && grep -q "FUNCTION Dobro( n )" "$D/sf1.prg" && \
   grep -q "Dobro( <v> )" "$D/suga.ch"
check "recusa NOMEIA diretiva+posição, oferece --edit-rules; nada editado" $?
# --edit-rules: a diretiva entra no conjunto de edições e passa pelo MESMO
# oráculo (mapa de símbolos + rollback); execução idêntica fecha o contrato
cp "$D/sf1.prg" "$D/sf1.antes"; cp "$D/suga.ch" "$D/suga.antes"
( cd "$D" && rm -rf .hbmk && "$HB_BIN/hbmk2" sf1.prg -oapp -gtcgi -q0 -main=UsaS > /dev/null 2>&1 && ./app > saida_antes.txt 2>/dev/null )
( cd "$D" && "$BIN" rename-function sf1.hbp Dobro Duplo --edit-rules > rf2.log 2>&1 )
RC=$?
check "rename-function --edit-rules exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "FUNCTION Duplo( n )" "$D/sf1.prg" && grep -q "Duplo( <v> )" "$D/suga.ch" && \
   grep -q "verified" "$D/rf2.log"
check "--edit-rules editou fonte E diretiva; oráculo verificou" $?
( cd "$D" && rm -rf .hbmk && "$HB_BIN/hbmk2" sf1.prg -oapp2 -gtcgi -q0 -main=UsaS > /dev/null 2>&1 && ./app2 > saida_depois.txt 2>/dev/null )
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execução idêntica após o rename com --edit-rules" $?
( cd "$D" && "$BIN" rename-function sf1.hbp Duplo Dobro --edit-rules > rf3.log 2>&1 )
RC=$?
cmp -s "$D/sf1.prg" "$D/sf1.antes" && cmp -s "$D/suga.ch" "$D/suga.antes" && [ $RC -eq 0 ]
check "ida-e-volta A->B->A byte-exata (fonte e diretiva)" $?

}

unit_75() {
echo "case 75: Q4 (revisao-generalidade) - vínculo escrito NÃO é pai: sem confirmed/excluded falso"
# O probe da revisão provou o veneno (2026-07-07): a DSL fixq4 põe o
# FORJADOR na linha da declaração, passado por @ref - a MESMA forma do pai
# do hbclass (nenhuma forma distingue; a linguagem não tem canal de
# herança). Antes do conserto, t:Pintar() saía "confirmed ... dispatches
# to LOUSA:PINTAR" - MENTIRA: a dona do forjador não é pai e em runtime o
# send seria erro. Conserto (DispatchVia): alcance que atravessa vínculo
# escrito nunca confirma/exclui - possible nomeando o candidato; acerto
# PRÓPRIO segue decidindo (regra do VM).
D="$HERE/tmp/case75"; rm -rf "$D"; mkdir -p "$D"
cp "$HERE"/fixq4/* "$D"/
( cd "$D" && "$HB_BIN/harbour" m1.prg -n -q0 -w3 -es2 -s -I. > /dev/null 2>&1 && \
  "$HB_BIN/harbour" m2.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 )
check "fixq4 (DSL com forjador na linha) clean under -w3 -es2" $?
( cd "$D" && "$BIN" usages fixq4.hbp Lousa:Pintar > lp.log 2>&1 )
check "usages Lousa:Pintar exit 0" $?
grep -q "confirmed send (receiver class LOUSA via declared types) in USAARMAS  | l:Pintar()" "$D/lp.log"
check "receptor da própria classe: confirmado (acerto próprio decide)" $?
grep -q "possible send (receiver class TOTEM, relation to LOUSA unknown) in USAARMAS  | t:Pintar()" "$D/lp.log"
check "forjador na linha NÃO vira pai: possible com o fato (RE.3 tirou a nomeação)" $?
! grep -qE "(confirmed|excluded)[^|]*\| *(t:Pintar|f:Pintar)" "$D/lp.log"
check "nenhum confirmed/excluded falso sobre os sends da classe forjada" $?
grep -q "possible send (receiver class FACA, relation to LOUSA unknown) in USAARMAS  | f:Pintar()" "$D/lp.log"
check "vínculo para função comum degrada honesto (nunca decide)" $?
! grep -qiwE "arma|tempera|gume|endarma|afia|faca|lamina|pedrabase|afiapedra|armamake|arsenal" "$HERE/../src/hbrefactor.prg"
check "a ferramenta não menciona NENHUMA palavra da DSL fixq4 (régua do caso 64)" $?

}

unit_76() {
echo "case 76: Q1 (revisao-generalidade) - reorder-params em 'método' de DSL própria NÃO-espelho"
# fixofi: a DSL cola a MENSAGEM primeiro e a dona por último
# (Talha_na_Banca), assinatura numa única linha (sem par protótipo/impl) e
# dispatch REAL de runtime (__clsNew/__clsAddMsg). A assinatura vem de
# SigParamHits (markers posicionados escopados pela identidade inteira),
# os sends de SendSitesArgs, a unicidade de PpMarkerOwners - tudo do
# rastro. CONSERTO Q1: a MENSAGEM do composto é a parte que NÃO nomeia
# função-de-classe (fato da co-derivação) - eleger a última parte (ATail)
# era forma-de-hbclass e elegia a DONA na forma crua do comando.
for f in o1.prg o2.prg; do
   "$HB_BIN/harbour" "$HERE/fixofi/$f" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" -I"$HERE/fixofi" > /dev/null 2>&1
   check "fixofi/$f clean under -w3 -es2"  $?
done
D=$(freshofi case76)
ofirun "$D" saida_antes.txt
check "fixture runs before (dispatch real)" $?
( cd "$D" && "$BIN" reorder-params fixofi.hbp Banca:Talha "nFundo,nLado" > ren.log 2>&1 )
RC=$?
check "reorder Dona:Membro de DSL própria exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "OFICIO Talha DA Banca PEDE nFundo, nLado" "$D/o1.prg"
check "assinatura única (sem protótipo espelho) reordenada" $?
grep -q "nLado \* 10 - nFundo" "$D/o1.prg"
check "corpo do ofício intacto (params mantêm os nomes)" $?
grep -q "OFICIO Verniz DA Banca PEDE nLado, nBrilho" "$D/o1.prg"
check "param homônimo (nLado) de OUTRO ofício intacto (escopo por identidade)" $?
grep -q "b:Talha( 5, 2 )" "$D/o2.prg"
check "send call site com argumentos reordenados" $?
grep -q "símbolos intactos" "$D/ren.log"
check "verificação: símbolos/funções intactos" $?
ofirun "$D" saida_depois.txt
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execução idêntica após o reorder" $?
# volta pela forma CRUA: a mensagem é achada pelo FATO (antes do conserto
# a última parte da colagem - a DONA - era eleita e o comando derrapava)
( cd "$D" && "$BIN" reorder-params fixofi.hbp Talha "nLado,nFundo" > /dev/null 2>&1 )
RC=$?
check "forma crua (mensagem única) resolve pelo fato" $([ $RC -eq 0 ] && echo 0 || echo 1)
cmp -s "$D/o1.prg" "$HERE/fixofi/o1.prg" && cmp -s "$D/o2.prg" "$HERE/fixofi/o2.prg"
check "A->B->A round-trip byte-exact"  $?
# Lustro é de duas donas (Banca e Tear) - send é despacho dinâmico
( cd "$D" && "$BIN" reorder-params fixofi.hbp Banca:Lustro "nPano,nCera" > amb.log 2>&1 )
RC=$?
check "mensagem de duas donas de DSL recusada" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "mais de uma classe" "$D/amb.log" && grep -q "TEAR" "$D/amb.log"
check "recusa nomeia as donas e o despacho dinâmico" $?
cmp -s "$D/o1.prg" "$HERE/fixofi/o1.prg" && cmp -s "$D/o2.prg" "$HERE/fixofi/o2.prg"
check "fontes intactos após a recusa" $?

}

unit_77() {
echo "case 77: Q2 (revisao-generalidade) - rename-method Dona:Membro resolve dona de DSL própria"
# o açúcar Dona:Membro é SÓ política de unicidade sobre o motor genérico
# (PpMarkerSeeds/Artifacts/Owners): a dona vem da co-derivação, a previsão
# do artefato (PredictText) opera por faixas - a colagem invertida
# (CINZELA_NA_BANCA) sai prevista sem nenhum separador assumido.
D=$(freshofi case77)
ofirun "$D" saida_antes.txt
check "fixture runs before"           $?
( cd "$D" && "$BIN" rename-method fixofi.hbp Banca:Talha Cinzela > ren.log 2>&1 )
RC=$?
check "rename Dona:Membro de DSL própria exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "LAVRA Cinzela" "$D/o1.prg" && grep -q "OFICIO Cinzela DA Banca PEDE" "$D/o1.prg"
check "declaração e implementação editadas no site escrito" $?
grep -q "b:Cinzela( 2, 5 )" "$D/o2.prg"
check "send editado no módulo consumidor" $?
grep -q "predicted: TALHA_NA_BANCA -> CINZELA_NA_BANCA" "$D/ren.log"
check "artefato da colagem INVERTIDA previsto do rastro" $?
grep -q 'predicted string: "Talha" -> "Cinzela"' "$D/ren.log"
check "string de registro prevista e conferida" $?
ofirun "$D" saida_depois.txt
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execução idêntica após o rename" $?
( cd "$D" && "$BIN" rename-method fixofi.hbp Banca:Cinzela Talha > /dev/null 2>&1 )
cmp -s "$D/o1.prg" "$HERE/fixofi/o1.prg" && cmp -s "$D/o2.prg" "$HERE/fixofi/o2.prg"
check "A->B->A round-trip byte-exact"  $?
( cd "$D" && "$BIN" rename-method fixofi.hbp Talha Cinzela --dry-run > bare.log 2>&1 )
grep -q "rename-method: BANCA:Talha -> Cinzela" "$D/bare.log"
check "forma crua resolve a dona única pelo fato (dry-run)" $?
( cd "$D" && "$BIN" rename-method fixofi.hbp Banca:Lustro Polir > amb.log 2>&1 )
RC=$?
check "membro homônimo em duas donas recusado" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "também é membro de: TEAR (o2.prg)" "$D/amb.log"
check "recusa nomeia a outra dona (política de unicidade)" $?
cmp -s "$D/o1.prg" "$HERE/fixofi/o1.prg" && cmp -s "$D/o2.prg" "$HERE/fixofi/o2.prg"
check "fontes intactos após a recusa" $?

}

unit_78() {
echo "case 78: Q3 (revisao-generalidade) - call-graph resolve membro de DSL própria"
# CONSERTO Q3: o índice de mensagens elegia a última parte da colagem
# (forma-de-hbclass) - numa DSL mensagem-primeiro a DONA virava chave e o
# comando respondia VAZIO em silêncio. Agora a mensagem é a parte que não
# nomeia função-de-classe (mesmo fato do extract/reorder).
D=$(freshofi case78)
( cd "$D" && "$BIN" call-graph fixofi.hbp Banca:Talha > cg.log 2>&1 )
check "call-graph Dona:Membro exit 0" $?
grep -q "o1.prg: definition BANCA:TALHA -> TALHA_NA_BANCA" "$D/cg.log"
check "definição resolvida para o símbolo da colagem invertida" $?
grep -q "MAIN ~> TALHA  \[dynamic: TALHA_NA_BANCA\]" "$D/cg.log"
check "send listado como aresta DINÂMICA para o método da DSL" $?
! grep -q "MAIN -> TALHA" "$D/cg.log"
check "nenhuma aresta estática inventada para o dispatch" $?
( cd "$D" && "$BIN" call-graph fixofi.hbp Talha > cgb.log 2>&1 )
grep -q "definition BANCA:TALHA -> TALHA_NA_BANCA" "$D/cgb.log"
check "mensagem crua resolve (índice pelo fato, não pela posição)" $?
( cd "$D" && "$BIN" call-graph fixofi.hbp Lustro > cgh.log 2>&1 )
grep -q "definition BANCA:LUSTRO -> LUSTRO_NA_BANCA" "$D/cgh.log" && \
   grep -q "definition TEAR:LUSTRO -> LUSTRO_NA_TEAR" "$D/cgh.log"
check "mensagem homônima mostra as definições das duas donas" $?
grep -q "dynamic: LUSTRO_NA_BANCA | LUSTRO_NA_TEAR" "$D/cgh.log"
check "aresta dinâmica mostra o alvo ambíguo (unicidade visível)" $?

}

unit_79() {
echo "case 79: Q7 (revisao-generalidade) - extract em corpo de ofício: função verificada OU recusa limpa"
# a síntese de método (METHOD ... CLASS + protótipo) é a exceção
# DOCUMENTADA do hbclass (V4: o pp não roda ao contrário) - o portão é o
# vocábulo da regra raiz que consumiu o nome no site escrito. Contêiner de
# DSL própria degrada para FUNÇÃO verificada com o fato relatado; range
# com o Self-análogo (QSelf vira nó SELF na árvore - fato do dump) RECUSA
# LIMPO nomeando a exceção: numa função extraída o receptor não viaja e o
# comportamento mudaria em silêncio (provado no probe da revisão).
D=$(freshofi case79)
ofirun "$D" saida_antes.txt
check "fixture runs before"           $?
( cd "$D" && "$BIN" extract-function fixofi.hbp o1.prg 23-23 Ajusta > ex.log 2>&1 )
RC=$?
check "range SEM Self-análogo em corpo de ofício extrai" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "contêiner de DSL própria (regra 'oficio')" "$D/ex.log" && \
   grep -q "exceção do hbclass" "$D/ex.log"
check "relato nomeia a regra da DSL e a exceção de síntese" $?
grep -q "nTom := Ajusta( nLado, nBrilho )" "$D/o1.prg" && \
   grep -q "STATIC FUNCTION Ajusta( nLado, nBrilho )" "$D/o1.prg"
check "alvo é FUNÇÃO (nunca síntese de METHOD em projeto alheio)" $?
ofirun "$D" saida_depois.txt
cmp -s "$D/saida_antes.txt" "$D/saida_depois.txt"
check "execução idêntica após o extract-para-função" $?
D=$(freshofi case79b)
( cd "$D" && "$BIN" extract-function fixofi.hbp o1.prg 22-22 Rotula > rec.log 2>&1 )
RC=$?
check "range COM QSelf em corpo de ofício recusado" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "QSelf()/Self" "$D/rec.log" && grep -q "receptor não viajaria" "$D/rec.log" && \
   grep -q "exceção do hbclass" "$D/rec.log"
check "recusa nomeia o fato (nó SELF) e a exceção de síntese" $?
cmp -s "$D/o1.prg" "$HERE/fixofi/o1.prg" && cmp -s "$D/o2.prg" "$HERE/fixofi/o2.prg"
check "fontes intactos após a recusa" $?
! grep -qiwE "tenda|lavra|oficio|endtenda|banca|tear|talha|verniz|lustro|cinzela|polir|ajusta|rotula|pede|nlado|nfundo|nbrilho|ncera|npano|nfio|ntrama|nmiolo|ntom|cmarca" "$HERE/../src/hbrefactor.prg"
check "a ferramenta não menciona NENHUMA palavra da DSL fixofi (régua do caso 64)" $?

}

unit_80() {
echo "case 80: Q6 (revisao-generalidade) - rótulo do DONO no vocabulário da DSL que o declarou"
# O TIPO do membro já liftava para a cabeça da regra raiz (cog/dote/
# oficio); o do DONO dizia "class" para qualquer DSL (V5). O vocábulo do
# dono agora é a cabeça da regra cuja expansão LIGOU o nome ao canal de
# classe - o `from` do próprio nome (fato do ast-3), no _HB_CLASS do
# stream e no nome da função-dona gerada. NÃO é a regra raiz do site do
# dono: `CREATE CLASS X` tem raiz CREATE (açúcar sobre açúcar), mas quem
# declara é a regra CLASS - hbclass segue "(class ...)" (asserts FAROL/
# GRADE do caso 72). Prova na DSL NÃO-espelho: TENDA gera a dona por
# registro runtime PURO (sem canal declared). Dona sem derivação cai para
# "class" (o nome do canal da linguagem), nunca palpite.
D=$(freshofi case80)
( cd "$D" && "$BIN" usages fixofi.hbp Banca:Talha > bt.log 2>&1 )
check "usages Banca:Talha exit 0" $?
grep -q "o1.prg:12: oficio definition Talha (tenda Banca)  | OFICIO Talha DA Banca PEDE" "$D/bt.log"
check "dono no vocabulário da DSL não-espelho (tenda Banca), membro no da regra raiz (oficio)" $?
! grep -qi "(class banca" "$D/bt.log"
check "nenhum rótulo 'class' para dona de DSL própria" $?

}

unit_81() {
echo "case 81: Q5 (revisao-generalidade) - resolve-at: o cursor vira consulta por FATO"
# O methodQuery da extensão era regex hbclass hard-coded (V1): promovia
# por FORMA e só via METHOD ... CLASS / bloco CREATE CLASS. resolve-at
# responde "o que está sob o cursor" pelos tokens consumidos de
# ppApplications (posição byte-exata) + rastro, em camadas de fato: dona
# por CO-DERIVAÇÃO do site, por APLICAÇÃO-IDENTIDADE (P1a - o from da
# implementação hbclass deriva das posições da DECLARAÇÃO, provado no
# probe da Q5; a identidade inteira na MESMA app liga o site) e pelo
# canal DECLARED sequencial (_HB_CLASS/_HB_MEMBER, cobre DSL declarativa
# pura e a lista { } do VAR). Homônimo resolve pelo SITE (a linha), não
# por unicidade de projeto; palavra de DSL responde a própria; send é
# dispatch dinâmico (consulta crua honesta); posição sem identificador
# recusa - a extensão cai para a palavra crua.
D=$(freshdis case81)
( cd "$D" && "$BIN" resolve-at fixdis.hbp d1.prg 13 11 > r1.log 2>&1 && grep -qi "^query: UWMain:Paint$" r1.log )
check "hbclass protótipo promove (paridade com o methodQuery morto)" $?
( cd "$D" && "$BIN" resolve-at fixdis.hbp d1.prg 23 8 > r2.log 2>&1 && grep -qi "^query: UWMain:Paint$" r2.log )
check "hbclass implementação promove (fato da aplicação-identidade)" $?
( cd "$D" && "$BIN" resolve-at fixdis.hbp d1.prg 31 11 > r3.log 2>&1 && grep -qi "^query: UWSecondary:Paint$" r3.log )
check "homônimo hbclass resolve pelo SITE" $?
D=$(freshofi case81b)
( cd "$D" && "$BIN" resolve-at fixofi.hbp o1.prg 12 8 > r1.log 2>&1 && grep -qi "^query: Banca:Talha$" r1.log )
check "DSL NÃO-espelho: assinatura única promove (a regex nunca cobriu)" $?
( cd "$D" && "$BIN" resolve-at fixofi.hbp o1.prg 7 7 > r2.log 2>&1 && grep -qi "^query: Banca:Talha$" r2.log )
check "site de registro runtime (LAVRA) promove pela co-derivação" $?
D=$(freshhom case81c)
( cd "$D" && "$BIN" resolve-at fixhom.hbp m1.prg 19 5 > r1.log 2>&1 && grep -qi "^query: Totem:Brilho$" r1.log && \
  "$BIN" resolve-at fixhom.hbp m1.prg 27 5 > r2.log 2>&1 && grep -qi "^query: Idolo:Brilho$" r2.log )
check "homônimos de DSL resolvem pelo SITE (19=Totem, 27=Idolo)" $?
( cd "$D" && "$BIN" resolve-at fixhom.hbp m2.prg 7 6 > r3.log 2>&1 && grep -q "^query: Sol:Fulgor$" r3.log )
check "DSL declarativa PURA promove pelo canal declared" $?
( cd "$D" && "$BIN" resolve-at fixhom.hbp m3.prg 10 8 > r4.log 2>&1 && grep -q "^query: Grade:nT$" r4.log )
check "VAR do hbclass promove pela lista { } do canal" $?
( cd "$D" && "$BIN" resolve-at fixhom.hbp m1.prg 19 1 > r5.log 2>&1 && grep -q "^query: COG$" r5.log )
check "palavra de DSL responde a própria palavra" $?
( cd "$D" && "$BIN" resolve-at fixhom.hbp m1.prg 39 8 > r6.log 2>&1 && grep -q "^query: Brilho$" r6.log && grep -q "send" r6.log )
check "send é dispatch dinâmico: consulta crua honesta" $?
( cd "$D" && "$BIN" resolve-at fixhom.hbp m1.prg 39 1 > r7.log 2>&1; [ $? -ne 0 ] )
check "posição sem identificador recusa (fallback da extensão)" $?
# usages --at: o MESMO core numa única invocação/compilação - é o que a
# extensão chama (a linha "query:" sai antes do relato normal do usages)
( cd "$D" && "$BIN" usages fixhom.hbp --at m1.prg:19:5 > u1.log 2>&1 && \
  grep -qi "^query: Totem:Brilho$" u1.log && grep -q "cog declaration (rig TOTEM)" u1.log )
check "usages --at resolve a posição e consulta numa chamada só" $?
( cd "$D" && "$BIN" usages fixhom.hbp --at m1.prg:39:1 > u2.log 2>&1; [ $? -ne 0 ] ) && \
  grep -q "nenhum identificador" "$D/u2.log"
check "usages --at recusa posição vazia nomeando o fato (fallback da extensão)" $?

}

unit_82() {
echo "case 82: B4g - a regra POR DENTRO (match[]/result[] do ast-5)"
# Fixtures promovidas do probe do portão (ADR-001): todos os tipos de
# marker, diretiva continuada, opcionais consecutivos reordenados,
# restrição (que vaza e que não vaza) e regra nascida de expansão (P5).
D=$(freshb4g case82)
( cd "$D" && "$HB_BIN/harbour" forja.prg -n -q0 -w3 -es2 -s -i. > /dev/null 2>&1 )
check "fixb4g/forja.prg clean under -w3 -es2" $?
( cd "$D" && "$HB_BIN/harbour" molde.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 )
check "fixb4g/molde.prg clean under -w3 -es2" $?
DIR=$( cd "$D" && "$BIN" dump forja.hbp 2>/dev/null | sed -n 's/^dumps em: //p' )
DIRM=$( cd "$D" && "$BIN" dump molde.hbp 2>/dev/null | sed -n 's/^dumps em: //p' )
test -n "$DIR" && test -f "$DIR/forja.ast.json" && test -n "$DIRM" && test -f "$DIRM/molde.ast.json"
check "dumps ast-5 gerados" $?
"$TCHECK" b4g82 "$DIR/forja.ast.json" "$DIRM/molde.ast.json" "$D" > "$D/b4g.log" 2>&1
grep -q "^b4g-invariantes-ok$" "$D/b4g.log"
check "invariantes do ast-5 sobre o dump real (byte-exato, P3, mkinds, restrição, reordenação, P5)" $?
( cd "$D" && "$BIN" usages forja.hbp ForjaNova > fn.log 2>&1 )
grep -q "forja.ch:15:13: in rule result (#xcommand FORJA)" "$D/fn.log"
check "usages nomeia identificador citado DENTRO de regra (result)" $?
( cd "$D" && "$BIN" usages forja.hbp TAMANHO > tam.log 2>&1 )
grep -q "forja.ch:12:23: in rule match (#xcommand FORJA)" "$D/tam.log" && \
   grep -q "forja.prg:9:14: keyword (#xcommand FORJA" "$D/tam.log"
check "usages: keyword secundária na diretiva E no site de aplicação" $?
( cd "$D" && "$BIN" usages forja.hbp RAPIDO > rap.log 2>&1 )
grep -q "forja.ch:14:19: in rule restriction (#xcommand FORJA, marker 3)" "$D/rap.log"
check "usages: palavra de restrição com posição-fato" $?
# rename-dsl de keyword SECUNDÁRIA (não-cabeça): diretiva + sites, padrão-ouro
cp "$D/forja.ch" "$D/forja.ch.antes"; cp "$D/forja.prg" "$D/forja.prg.antes"
( cd "$D" && "$BIN" rename-dsl forja.hbp TAMANHO MEDIDA > rd1.log 2>&1 )
RC=$?
check "rename-dsl de keyword secundária exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "MEDIDA <nTam>" "$D/forja.ch" && grep -q "FORJA oIt MEDIDA DOBRO" "$D/forja.prg" && \
   grep -q "byte-identical" "$D/rd1.log"
check "secundária editada na diretiva e no uso; .ppo/.hrb byte-idênticos" $?
( cd "$D" && "$BIN" rename-dsl forja.hbp MEDIDA TAMANHO > rd2.log 2>&1 )
cmp -s "$D/forja.ch" "$D/forja.ch.antes" && cmp -s "$D/forja.prg" "$D/forja.prg.antes"
check "ida-e-volta A->B->A byte-exata da secundária" $?
# restrição que NÃO vaza (marker fora do result): renomeável padrão-ouro
( cd "$D" && "$BIN" rename-dsl forja.hbp FRIO GELADO > rd3.log 2>&1 )
RC=$?
check "rename-dsl de palavra de restrição (não vaza) exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "<m: GELADO, QUENTE>" "$D/forja.ch" && grep -q "RECOZE MODO GELADO" "$D/forja.prg"
check "restrição editada na diretiva e no uso" $?
( cd "$D" && "$BIN" rename-dsl forja.hbp GELADO FRIO > /dev/null 2>&1 )
cmp -s "$D/forja.ch" "$D/forja.ch.antes" && cmp -s "$D/forja.prg" "$D/forja.prg.antes"
check "ida-e-volta da restrição byte-exata" $?
# restrição cujo valor VAZA (stringify do marker): a expansão mudaria em
# silêncio - a rede .ppo recusa com rollback, honesto
( cd "$D" && "$BIN" rename-dsl forja.hbp RAPIDO VELOZ > rd4.log 2>&1 )
RC=$?
check "restrição que vaza: recusa (exit != 0)" $([ $RC -ne 0 ] && echo 0 || echo 1)
grep -q "rollback" "$D/rd4.log" && cmp -s "$D/forja.ch" "$D/forja.ch.antes" && \
   cmp -s "$D/forja.prg" "$D/forja.prg.antes"
check "rollback preservou diretiva e fonte (expansão teria mudado)" $?
# resolve-at DENTRO de diretiva (camada 4): a posição vira palavra de regra
( cd "$D" && "$BIN" resolve-at molde.hbp molde.prg 6 51 > ra.log 2>&1 )
RC=$?
check "resolve-at dentro de diretiva exit 0" $([ $RC -eq 0 ] && echo 0 || echo 1)
grep -q "palavra no result da regra (#xcommand MOLDE, molde.prg:6)" "$D/ra.log" && \
   grep -q "query: CunhoNovo" "$D/ra.log"
check "camada 4: palavra dentro da diretiva por posição-fato, consulta crua" $?
# régua do caso 64: nenhuma palavra das DSLs de fixture na ferramenta nem
# no core (fronteira de palavra: 'forjador' do fixq4 é outro vocabulário)
! grep -qiE "\bforja\b|\bmolde\b|\btempera\b|\bcunho\b|\bprensa\b|\bbatiza\b|\brecoze\b" "$HERE/../src/hbrefactor.prg" && \
   ! grep -qiE "\bforja\b|\bmolde\b|\btempera\b|\bcunho\b|\bprensa\b|\bbatiza\b|\brecoze\b" "$HB_BIN/../../../src/compiler/compast.c" && \
   ! grep -qiE "\bforja\b|\bmolde\b|\btempera\b|\bcunho\b|\bprensa\b|\bbatiza\b|\brecoze\b" "$HB_BIN/../../../src/pp/ppcore.c"
check "régua do caso 64: nenhuma palavra da fixture na ferramenta nem no core" $?

}

unit_83() {
echo "case 83: projects-of - picker ciente do arquivo (B5): pertencer é fato do hbmk2"
# A extensão pergunta "de quais destes projetos o arquivo é fonte" e o
# CLI responde pela linha de comando do compilador que o hbmk2 resolve
# (-traceonly, sem compilar) - nunca parseando .hbp. Identidade por
# caminho canônico COMPLETO: p2 tem um a.prg PRÓPRIO em subdiretório
# (mesmo nome+ext) para provar que base de nome não decide. Órfão =
# resposta válida VAZIA (exit 0, o picker cai para todos); nenhum
# candidato resolvido = pergunta SEM resposta (exit != 0); candidato
# quebrado no meio sai do páreo com nota sem derrubar a resposta.
D="$HERE/tmp/case83"; rm -rf "$D"; mkdir -p "$D/sub"
cat > "$D/a.prg" <<'EOF'
PROCEDURE Main()

   OutStd( Comum() + hb_eol() )

   RETURN
EOF
cat > "$D/s.prg" <<'EOF'
FUNCTION Comum()

   RETURN "c"
EOF
cat > "$D/sub/a.prg" <<'EOF'
PROCEDURE Main()

   OutStd( "sub" + Comum() + hb_eol() )

   RETURN
EOF
cat > "$D/orfao.prg" <<'EOF'
PROCEDURE Main()

   RETURN
EOF
printf -- '-w3\n-es2\na.prg\ns.prg\n' > "$D/p1.hbp"
printf -- '-w3\n-es2\nsub/a.prg\ns.prg\n' > "$D/p2.hbp"
( cd "$D" && "$HB_BIN/harbour" a.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 && \
  "$HB_BIN/harbour" s.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 && \
  "$HB_BIN/harbour" sub/a.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 && \
  "$HB_BIN/harbour" orfao.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 )
check "fixtures do caso 83 clean under -w3 -es2" $?
( cd "$D" && "$BIN" projects-of a.prg p1.hbp p2.hbp > own.log 2>&1 )
check "projects-of a.prg exit 0" $?
[ "$(cat "$D/own.log")" = "p1.hbp" ]
check "a.prg da raiz: só p1 (o a.prg de p2 é OUTRO arquivo - nome+ext não decide)" $?
( cd "$D" && "$BIN" projects-of sub/a.prg p1.hbp p2.hbp > own2.log 2>&1 )
[ "$(cat "$D/own2.log")" = "p2.hbp" ]
check "sub/a.prg: só p2 (identidade por caminho canônico completo)" $?
( cd "$D" && "$BIN" projects-of s.prg p1.hbp p2.hbp > own3.log 2>&1 )
[ "$(printf 'p1.hbp\np2.hbp')" = "$(cat "$D/own3.log")" ]
check "fonte compartilhada: os DOIS projetos, na ordem dos candidatos" $?
( cd "$D" && "$BIN" projects-of "$D/s.prg" "$D/p1.hbp" "$D/p2.hbp" > own6.log 2>&1 )
[ "$(printf '%s\n%s' "$D/p1.hbp" "$D/p2.hbp")" = "$(cat "$D/own6.log")" ]
check "forma da extensão (tudo absoluto): mesma resposta com specs absolutos" $?
( cd "$D" && "$BIN" projects-of orfao.prg p1.hbp p2.hbp > own4.log 2>&1 )
RC=$?
[ $RC -eq 0 ] && [ ! -s "$D/own4.log" ]
check "órfão: resposta válida VAZIA com exit 0 (picker cai para todos)" $?
( cd "$D" && "$BIN" projects-of s.prg p1.hbp p2.hbp --json own.json > /dev/null 2>&1 )
"$TCHECK" pof83 "$D/own.json"
check "--json: o array que a extensão decodifica (tcheck via hb_jsonDecode)" $?
( cd "$D" && "$BIN" projects-of a.prg naoexiste.hbp p1.hbp > own5.log 2> own5.err )
RC=$?
[ $RC -eq 0 ] && [ "$(cat "$D/own5.log")" = "p1.hbp" ] && grep -q "não resolveu no hbmk2" "$D/own5.err"
check "candidato quebrado no meio: fora do páreo com nota, resposta segue" $?
( cd "$D" && "$BIN" projects-of a.prg naoexiste.hbp > /dev/null 2>&1 )
RC=$?
[ $RC -ne 0 ]
check "nenhum candidato resolvido: pergunta sem resposta (exit != 0), não órfão" $?
# as guardas do lado da extensão (pickerChoices/projectsOf) vivem no
# harness do caso 71 (vscode/test-resolveat.js)

}

unit_84() {
echo "case 84: RE.3 - fixext: a cadeia de construção NÃO decide mais (era B7/rito D4)"
# a fixture da spec-b7 vira prova do contrato RE.3: oC/oV nascem de
# construção sem tipo declarado - a cadeia que os tipava é INFERÊNCIA e
# saiu do veredito; TODOS os sends de Deposita degradam para o possible
# pleno, nas duas consultas (nenhum confirmed/excluded falso sobra). Os
# venenos Troca/Ajustada seguem na fixture.
D=$(freshext case84)
( cd "$D" && "$BIN" usages fixext.hbp ContaVip:Deposita > vip.log 2>&1 )
check "usages ContaVip:Deposita exit 0" $?
grep -q "e1.prg:74: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/vip.log"
check "send de oV (construção sem declarado): possible pleno (RE.3)" $?
grep -q "e1.prg:71: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/vip.log" && \
   grep -q "e1.prg:73: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/vip.log"
check "sends de oC: possible pleno (a exclusão por grafo saiu)" $?
grep -q "e1.prg:64: possible send (dynamic dispatch, receiver unknown) in CONTAVIP_DEPOSITA" "$D/vip.log"
check "::Super:Deposita: possible (a cadeia via grafo era inferência)" $?
( cd "$D" && "$BIN" usages fixext.hbp Conta:Deposita > cta.log 2>&1 )
check "usages Conta:Deposita exit 0" $?
grep -q "e1.prg:71: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/cta.log" && \
   grep -q "e1.prg:73: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/cta.log" && \
   grep -q "e1.prg:64: possible send (dynamic dispatch, receiver unknown) in CONTAVIP_DEPOSITA" "$D/cta.log"
check "consulta espelho: os mesmos possible (simetria do contrato)" $?
! grep -qE "confirmed send|excluded send" "$D/vip.log" "$D/cta.log"
check "nenhum confirmed/excluded de send deriva de inferência (critério RE.3)" $?

}

unit_85() {
echo "case 85: RE.3 - fixb7: fábrica/união/conjunto degradam; fato de declaração fica"
# a fixture da spec-b7 vira prova do contrato RE.3: retorno rotulado,
# união de call sites e união de ramos de IIF são INFERÊNCIA - todos os
# sends degradam para possible pleno (inclusive os que a união nomeava).
# O que fica: a exclusão do site de DEFINIÇÃO homônimo (fato do canal
# declarado - homônimos por declaração, "O que NÃO muda" da fase RE).
"$HB_BIN/harbour" "$HERE/fixb7/b1.prg" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" > /dev/null 2>&1
check "fixb7/b1.prg clean under -w3 -es2" $?
D=$(freshb7 case85)
( cd "$D" && "$BIN" usages fixb7.hbp Peca:Gira > pg.log 2>&1 )
check "usages Peca:Gira exit 0" $?
grep -q "b1.prg:53: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/pg.log"
check "fábrica sem DECLARE: possible pleno (retorno rotulado é inferência - RE.3)" $?
grep -q "b1.prg:39: possible send (dynamic dispatch, receiver unknown) in USAQUALQUER" "$D/pg.log"
check "parâmetro: possible pleno (união de call sites era inferência)" $?
grep -q "b1.prg:54: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/pg.log"
check "IIF de condição de runtime: possible pleno (união de ramos era inferência)" $?
grep -q "b1.prg:58: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/pg.log"
check "veneno @ref: possible honesto" $?
grep -q "b1.prg:61: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/pg.log"
check "veneno escrita destacada em bloco: possible honesto" $?
grep -q "b1.prg:30: possible send (dynamic dispatch, receiver unknown) in DISCO_SOLTA" "$D/pg.log"
check "veneno Self reescrito: possible honesto" $?
grep -q "b1.prg:21: excluded method definition (implements DISCO:GIRA)" "$D/pg.log"
check "definição homônima excluída na consulta por classe" $?
( cd "$D" && "$BIN" usages fixb7.hbp Disco:Gira > dg.log 2>&1 )
grep -q "b1.prg:53: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/dg.log"
check "consulta espelho: o mesmo possible (nenhuma exclusão por inferência)" $?

}

unit_86() {
echo "case 86: RE.3 - fixb7b: TODA a fatia B7b degrada para possible no produto"
# a fixture da spec-b7b vira prova do contrato RE.3: retorno de método
# pelos pushes ret, identidade de RETURN Self, Self de INLINE/OPERATOR
# (1º param do bloco), detached de binding único e união dos sites de
# Eval são INFERÊNCIA - todos os sends saem possible pleno, inclusive na
# DSL não-espelho (a generalidade da degradação também é genérica). Os
# venenos, que já eram possible, seguem possible - o contrato colapsou
# inferência boa e veneno no MESMO rótulo honesto; a separação renasce
# no materializador (fatia 2 da B9).
"$HB_BIN/harbour" "$HERE/fixb7b/q1.prg" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" > /dev/null 2>&1
check "fixb7b/q1.prg clean under -w3 -es2" $?
"$HB_BIN/harbour" "$HERE/fixb7b/q2.prg" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" > /dev/null 2>&1
check "fixb7b/q2.prg clean under -w3 -es2" $?
D=$(freshb7b case86)
( cd "$D" && "$BIN" usages fixb7b.hbp Moeda:Soma > ms.log 2>&1 )
check "usages Moeda:Soma exit 0" $?
grep -q "q1.prg:13: possible send (dynamic dispatch, receiver unknown, codeblock) in MOEDA" "$D/ms.log" && \
   grep -q "q1.prg:14: possible send (dynamic dispatch, receiver unknown, codeblock) in MOEDA" "$D/ms.log"
check "INLINE e OPERATOR (money): possible pleno (Self de bloco era inferência)" $?
grep -q "q1.prg:73: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/ms.log"
check "send encadeado: possible pleno (pushes ret eram inferência)" $?
[ "$(grep -c "q1.prg:75: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/ms.log")" = "2" ]
check "identidade em cadeia: os dois sends da linha saem possible (RE.3)" $?
grep -q "q1.prg:77: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/ms.log"
check "veneno Self reescrito: RETURN Self não é identidade - possible" $?
grep -q "q1.prg:78: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/ms.log"
check "veneno ciclo Gira<->Volta nos RETURNs: possible honesto" $?
grep -q "q1.prg:79: possible send (dynamic dispatch, receiver unknown) in MAIN" "$D/ms.log"
check "veneno retornos discordantes (classe x valor): possible honesto" $?
grep -q "q1.prg:82: possible send (dynamic dispatch, receiver unknown, codeblock) in MAIN" "$D/ms.log"
check "bloco lendo detached de binding único: possible pleno (RE.3)" $?
grep -q "q1.prg:85: possible send (dynamic dispatch, receiver unknown, codeblock) in MAIN" "$D/ms.log"
check "parâmetro de bloco (união dos Evals): possible pleno (RE.3)" $?
grep -q "q1.prg:90: possible send (dynamic dispatch, receiver unknown, codeblock) in MAIN" "$D/ms.log"
check "param de bloco em statement continuado: o mesmo possible" $?
grep -q "q1.prg:93: possible send (dynamic dispatch, receiver unknown, codeblock) in MAIN" "$D/ms.log"
check "bloco que sai da função (leitura fora de Eval): possible honesto" $?
grep -q "q1.prg:96: possible send (dynamic dispatch, receiver unknown, codeblock) in MAIN" "$D/ms.log"
check "detached multi-write no bloco: permanece possible (⊤)" $?
( cd "$D" && "$BIN" usages fixb7b.hbp Fornalha:mexe > fm.log 2>&1 )
check "usages Fornalha:mexe exit 0" $?
grep -q "q2.prg:9: possible send (dynamic dispatch, receiver unknown, codeblock) in FORNALHA" "$D/fm.log"
check "PORTÃO DE GENERALIDADE: DSL não-espelho degrada IGUAL (tigela - RE.3)" $?
grep -q "q2.prg:10: possible send (dynamic dispatch, receiver unknown, codeblock) in FORNALHA" "$D/fm.log"
check "2º parâmetro do bloco inline NÃO é o receptor: possible honesto" $?
! grep -qiE 'fornalha|brasa|tigela|forno|tacho' "$HERE/../src/hbrefactor.prg"
check "régua do caso 64: nenhuma palavra da DSL no fonte da ferramenta" $?

}

unit_87() {
echo "case 87: B9 -kt - tipos declarados IMPOSTOS (invariante de runtime)"
# spec-b9 (T1-T5): sob -kt o compilador emite cheques de runtime para as
# anotações AS da linguagem - prólogo (params), pós-atribuição (locals) e
# RETURN via DECLARE. Provas por EXECUÇÃO: NIL falha (T2) e o não-anotado
# segue opcional; is-a passa e não-relacionada falha nomeando (T3);
# classe montada em RUNTIME passa pelo cheque por NOME no objeto vivo (o
# alcance novo - nada keyed a hbclass); forma DIMENSIONADA não é anotação
# (reatribuir é legal). Consumo: camada "guaranteed" no usages (anotação
# em módulo -kt é invariante, acima da promessa declarada - inclusive com
# multi-write DIRETO, porque toda escrita coberta é checada; a cobertura
# de site é o caso 88/RE.2) e a marca "dim" do ast-7
# (o 'A' interno da dimensionada não é promessa: o send que RODA saía
# excluded ERRADO e agora é possible honesto). T1: fonte anotado compila
# limpo TAMBÉM sem a flag; a flag flui por linha de .hbp E por -prgflag=.
"$HB_BIN/harbour" "$HERE/fixkt/t1.prg" -n -q0 -w3 -es2 -kt -s -I"$HB_BIN/../../../include" > /dev/null 2>&1
check "fixkt/t1.prg clean under -w3 -es2 -kt" $?
"$HB_BIN/harbour" "$HERE/fixkt/t2.prg" -n -q0 -w3 -es2 -kt -s -I"$HB_BIN/../../../include" > /dev/null 2>&1
check "fixkt/t2.prg clean under -w3 -es2 -kt" $?
"$HB_BIN/harbour" "$HERE/fixkt/t1.prg" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" > /dev/null 2>&1 && \
   "$HB_BIN/harbour" "$HERE/fixkt/t2.prg" -n -q0 -w3 -es2 -s -I"$HB_BIN/../../../include" > /dev/null 2>&1
check "T1 compatibilidade: fonte anotado compila limpo SEM a flag" $?
D=$(freshkt case87)
( cd "$D" && "$HB_BIN/hbmk2" fixkt.hbp -q0 -gtcgi -okt_hbp > /dev/null 2>&1 && ./kt_hbp > run.log 2>&1 )
check "build via linha -prgflag=-kt no .hbp + execução exit 0" $?
grep -q "cls: declared type check failed: expected S:CONTA, got PEDRA @ GUARDA:OONDE" "$D/run.log"
check "T3: classe não relacionada falha nomeando site/declarado/recebido" $?
grep -q "nil: declared type check failed: expected S:CONTA, got U" "$D/run.log" && \
   grep -q "sem rotulo:0" "$D/run.log"
check "T2: NIL falha no anotado; o parâmetro NÃO anotado segue opcional" $?
[ "$(grep -c '^ok 1$' "$D/run.log")" = "3" ]
check "T3: subclasse, classe exata e classe de RUNTIME passam no cheque" $?
grep -q "kind: declared type check failed: expected N, got C @ METADE:NQUANTO" "$D/run.log"
check "kind errado em parâmetro anotado falha no prólogo" $?
grep -q "local: declared type check failed: expected S:CONTA, got C @ MAIN:OCOFRE" "$D/run.log" && \
   grep -q "cofre:3" "$D/run.log" && grep -q "sobra: C" "$D/run.log"
check "local anotado: atribuição errada falha; a boa encadeia; pós-recover fica o gravado" $?
grep -q "ret: declared type check failed: expected N, got C @ TORCE:return" "$D/run.log"
check "RETURN violando o DECLARE da própria função falha" $?
grep -q "virou string" "$D/run.log" && grep -q "fluxo: 3" "$D/run.log"
check "forma dimensionada NÃO é anotação: reatribuir segue legal sob -kt" $?
grep -v '^-prgflag=-kt$' "$D/fixkt.hbp" > "$D/semflag.hbp"
( cd "$D" && "$HB_BIN/hbmk2" semflag.hbp -q0 -gtcgi -prgflag=-kt -okt_cli > /dev/null 2>&1 && ./kt_cli > run2.log 2>&1 )
cmp -s "$D/run.log" "$D/run2.log"
check "flag via -prgflag= na CLI: execução byte-idêntica à do .hbp" $?
( cd "$D" && "$BIN" usages fixkt.hbp Conta:Credita > cc.log 2>&1 )
check "usages Conta:Credita exit 0" $?
grep -q "t2.prg:17: guaranteed send (receiver AS CLASS CONTA imposed by -kt checks) in FLUXO" "$D/cc.log"
check "camada guaranteed: parâmetro anotado em módulo -kt é invariante" $?
grep -q "t1.prg:72: guaranteed send (receiver AS CLASS CONTA imposed by -kt checks) in MAIN" "$D/cc.log"
check "guaranteed no local anotado MULTI-write (toda escrita DIRETA é checada; site coberto - RE.2)" $?
grep -q "t2.prg:23: possible send (dynamic dispatch, receiver unknown) in FLUXO" "$D/cc.log" && \
   ! grep -q "t2.prg:23: excluded" "$D/cc.log"
check "marca dim (ast-7): o 'A' da dimensionada não é promessa - possible honesto" $?

}

unit_88() {
echo "case 88: RE.2 guaranteed honesto - marca kt só em site COBERTO"
# spec-re (RE.1/RE.2): a fatia 1 do -kt cobre prólogo de parâmetro de
# assinatura e pós-store DIRETO em local de função nomeada; escrita
# dentro de codeblock (store block-relative) e escrita via @ref (o pop
# é do parâmetro do callee) NÃO são checadas - provas probe2/probe3 do
# RE.1. Anotação com escrita não coberta degrada para o canal da
# promessa (declared), sem o selo de invariante; PARAMETERS AS está no
# canal e nunca é imposto (A2 - o gate memvar responde possible); param
# de bloco anotado fica no canal declared (o binding do Eval não é
# checado). Sites cobertos seguem guaranteed - caso 87 intacto.
D=$(freshkt case88)
( cd "$D" && "$BIN" usages fixkt.hbp Conta:Credita > cc.log 2>&1 )
check "usages Conta:Credita exit 0" $?
grep -q "t3.prg:21: confirmed send (receiver declared AS CLASS CONTA) in SOMBRA" "$D/cc.log" && \
   ! grep -q "t3.prg:21: guaranteed" "$D/cc.log"
check "escrita só em codeblock: promessa declared, SEM selo kt" $?
grep -q "t3.prg:33: confirmed send (receiver declared AS CLASS CONTA) in REFEM" "$D/cc.log" && \
   ! grep -q "t3.prg:33: guaranteed" "$D/cc.log"
check "escrita via @ref: promessa declared, SEM selo kt (gap extra do RE.1)" $?
grep -q "t3.prg:45: possible send (dynamic dispatch, receiver unknown) in ANTIGA" "$D/cc.log" && \
   ! grep -q "t3.prg:45: guaranteed" "$D/cc.log"
check "PARAMETERS AS: anotação no canal, nunca imposta - possible honesto" $?
grep -q "t3.prg:53: excluded send (receiver holds a value of kind numeric, codeblock) in MIUDA" "$D/cc.log" && \
   ! grep -q "t3.prg:53: guaranteed" "$D/cc.log"
check "param de bloco anotado: canal declared, SEM selo kt" $?
grep -q "t1.prg:72: guaranteed send" "$D/cc.log" && \
   grep -q "t2.prg:17: guaranteed send" "$D/cc.log"
check "sites cobertos seguem guaranteed (caso 87 intacto)" $?

}

ALL_UNITS="0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88"

# ---------------------------------------------------------------------------
# B-infra: pool dinamico por-caso (docs/testes-paralelos.md; Etapa 2 -
# despacho+join em Harbour). JOBS=N controla o teto (default nproc); JOBS=1
# roda em processo, na ordem, com saida ao vivo (R7 - depuracao identica ao
# runner antigo). JOBS>1 delega ao bin/parrun (hb_processOpen - toolchain
# unica), que respawna este script no modo filho.
# Modo filho (--unit N): TMPDIR proprio (R2 - hb_DirTemp() o respeita),
# saida no artefato proprio (R5 - mata a intercalacao) e contadores
# em-banda na ultima linha (@@counts) - o join imprime os logs NA ORDEM
# dos casos (saida byte-identica a sequencial) e soma o tally. Unidade
# sem @@counts = morreu no meio: conta FAIL e mostra o log (silencio
# nunca parece sucesso).
# ---------------------------------------------------------------------------
PARDIR="$HERE/tmp/.par"

if [ "${1:-}" = "--unit" ]; then
   u="$2"
   export TMPDIR="$PARDIR/$u.tmp"
   mkdir -p "$TMPDIR"
   exec > "$PARDIR/$u.log" 2>&1
   "unit_$u"
   echo "@@counts $PASS $FAIL"
   exit 0
fi

JOBS="${JOBS:-$(nproc)}"
if [ "$JOBS" -le 1 ]; then
   for u in $ALL_UNITS; do
      "unit_$u"
   done
   echo
   echo "passed: $PASS  failed: $FAIL"
   [ "$FAIL" -eq 0 ]
else
   PARRUN="${PARRUN:-$HERE/../bin/parrun}"
   [ -x "$PARRUN" ] || { echo "parrun ausente ($PARRUN) - rode via make test"; exit 1; }
   rm -rf "$PARDIR"
   mkdir -p "$PARDIR"
   exec "$PARRUN" "$HERE/run.sh" "$PARDIR" "$JOBS" $ALL_UNITS
fi
