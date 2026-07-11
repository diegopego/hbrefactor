#!/bin/bash
# tests/ppcorpus.sh - suite EXPLORATORIA do PP (fase P, P-DOC). SEPARADA do
# contrato (tests/run.sh / `make test`, byte-identico) de proposito: e
# exploratoria, e durante a exploracao o CORE sera modificado para gerar mais
# informacao (.ppt/.ppo/ast dump mais ricos - permissao do Diego 2026-07-11).
# O contrato tem de ficar estavel; o corpus e onde essas extensoes nascem e se
# provam.
#
# Metodo: cada familia do corpus (docs/pp-corpus.md) casa uma diretiva REAL do
# Harbour com os QUATRO ORACULOS - .ppo (expandido) + .ppt (traco passo a passo)
# + ast dump (o fato estruturado, mkinds) + um teste em codigo COMPILAVEL - e
# assere as transformacoes-chave que o doc afirma. Se o core mudar a expansao,
# isto quebra e o doc e corrigido: o conhecimento fica ancorado no FATO
# corrente, nunca numa copia congelada. Sequencial (exploratorio, pequeno).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
export HB_BIN="${HB_BIN:?HB_BIN must point to the harbour binaries dir (branch feature/compiler-ast-dump)}"
HB="$HB_BIN/harbour"

PASS=0
FAIL=0
note()  { printf '  %s\n' "$*"; }
check() { # check <desc> <cond-exit>
   if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); note "ok:   $1"
   else FAIL=$((FAIL+1)); note "FAIL: $1"; fi
}

# gen4 <familia-dir> <prg> -> ecoa um workdir com os .ppo/.ppt/.ast.json
# gerados (os quatro oraculos; o 4o - o codigo compilavel - e a propria fixture)
gen4() {
   local fam="$1" prg="$2" d="$HERE/tmp/.ppcorpus/$1"
   rm -rf "$d"; mkdir -p "$d"; cp "$HERE/$fam"/*.prg "$d"/ 2>/dev/null
   ( cd "$d" && "$HB" "$prg" -n -q0 -p    > /dev/null 2>&1 )                     # .ppo
   ( cd "$d" && "$HB" "$prg" -n -q0 -p+   > /dev/null 2>&1 )                     # .ppt
   ( cd "$d" && "$HB" "$prg" -n -q0 -x"${prg%.prg}.ast.json" > /dev/null 2>&1 )  # ast dump
   echo "$d"
}

# --------------------------------------------------------------------------
# Familia SET (std.ch) - `SET EXACT <x:ON,OFF,&> => Set( _SET_EXACT, <(x)> )`
# restrict no match + smart-quote (strsmart) no result; multi-passe (#define)
# --------------------------------------------------------------------------
corpus_set() {
   echo "corpus: familia SET (std.ch) - SET EXACT (restrict + smart-quote)"
   ( cd "$HERE/ppc-set" && "$HB" setx.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 )
   check "ppc-set/setx.prg compila limpo sob -w3 -es2 (codigo comprovado)" $?
   local D; D=$(gen4 ppc-set setx.prg)
   # .ppo: smart-quote cita o bareword ON, passa a expressao (lFlag) crua; _SET_EXACT vira 1
   grep -q 'Set( 1, "ON" )' "$D/setx.ppo" && grep -q 'Set( 1, lFlag )' "$D/setx.ppo"
   check ".ppo: smart-quote cita bareword ON, passa (lFlag) crua, _SET_EXACT->1" $?
   # .ppt: o multi-passe visivel - #command e depois #define
   grep -q '#command >Set( _SET_EXACT, "ON" )<' "$D/setx.ppt" && grep -q '#define >1<' "$D/setx.ppt"
   check ".ppt: os dois passes visiveis (#command depois #define _SET_EXACT)" $?
   # ast dump: os mkinds que o corpus cita (a ponte com P4/P5)
   grep -q '"mkind": "restrict"' "$D/setx.ast.json" && grep -q '"mkind": "strsmart"' "$D/setx.ast.json"
   check "ast dump: mkinds restrict (match) e strsmart (result)" $?
}

corpus_set

echo
echo "ppcorpus: passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
