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
HB_INC="${HB_BIN%/bin/*}/include"   # dir de includes do core (hbclass.ch etc.)

PASS=0
FAIL=0
note()  { printf '  %s\n' "$*"; }
check() { # check <desc> <cond-exit>
   if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); note "ok:   $1"
   else FAIL=$((FAIL+1)); note "FAIL: $1"; fi
}

# gen4 <familia-dir> <prg> -> ecoa um workdir com os .ppo/.ppt/.ast.json
# gerados (os quatro oraculos; o 4o - o codigo compilavel - e a propria fixture)
gen4() {   # gen4 <familia-dir> <prg> [flags extra p/ o harbour, ex.: -I<inc>]
   local fam="$1" prg="$2"; shift 2
   local d="$HERE/tmp/.ppcorpus/$fam"
   rm -rf "$d"; mkdir -p "$d"; cp "$HERE/$fam"/*.prg "$d"/ 2>/dev/null
   ( cd "$d" && "$HB" "$prg" -n -q0 -p    "$@" > /dev/null 2>&1 )                     # .ppo
   ( cd "$d" && "$HB" "$prg" -n -q0 -p+   "$@" > /dev/null 2>&1 )                     # .ppt
   ( cd "$d" && "$HB" "$prg" -n -q0 -x"${prg%.prg}.ast.json" "$@" > /dev/null 2>&1 )  # ast dump
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

# --------------------------------------------------------------------------
# Familia @ ... SAY (std.ch) - `@ <row>,<col> SAY <exp> [PICTURE <pic>] [COLOR
# <clr>]` : multi-marker + grupos OPCIONAIS no match E no result; duas formas
# (DevOut vs DevOutPict) que o pp seleciona pelo que casou
# --------------------------------------------------------------------------
corpus_say() {
   echo "corpus: familia @ ... SAY (std.ch) - grupos opcionais + selecao de forma"
   ( cd "$HERE/ppc-say" && "$HB" sayx.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 )
   check "ppc-say/sayx.prg compila limpo sob -w3 -es2 (codigo comprovado)" $?
   local D; D=$(gen4 ppc-say sayx.prg)
   # .ppo: sem PICTURE/COLOR -> DevOut; PICTURE -> DevOutPict; +COLOR -> 3o arg
   grep -q 'DevPos( 1, 1 ) ; DevOut( "Ola" )' "$D/sayx.ppo" && \
   grep -q 'DevPos( 2, 1 ) ; DevOutPict( nX, "999" )' "$D/sayx.ppo"
   check ".ppo: sem opcionais -> DevOut; [PICTURE] -> DevOutPict (grupo opcional match)" $?
   # o grupo opcional do RESULT ([, <clr>]) so emite se COLOR casou
   grep -q 'DevOutPict( nX, "999", "R/W" )' "$D/sayx.ppo" && \
   grep -q 'DevOut( cName, "W/B" )' "$D/sayx.ppo"
   check ".ppo: grupo opcional do result [, <clr>] emite a cor so quando COLOR casa" $?
   # ast dump: a regra carrega os grupos opcionais como roles opt-open/opt-close
   grep -q '"role": "opt-open"' "$D/sayx.ast.json" && grep -q '"role": "opt-close"' "$D/sayx.ast.json"
   check "ast-5 dump: grupos opcionais viram roles opt-open/opt-close" $?
}

# --------------------------------------------------------------------------
# Familia STORE (std.ch) - `STORE <v> TO <v1> [,<vN>] => <v1> := [ <vN> :=] <v>`
# o grupo opcional REPETE (uma vez por variavel extra) - a multi-atribuicao
# --------------------------------------------------------------------------
corpus_store() {
   echo "corpus: familia STORE (std.ch) - grupo opcional que REPETE (multi-atribuicao)"
   ( cd "$HERE/ppc-store" && "$HB" storex.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 )
   check "ppc-store/storex.prg compila limpo sob -w3 -es2 (codigo comprovado)" $?
   local D; D=$(gen4 ppc-store storex.prg)
   # .ppo: uma variavel -> um :=; tres variaveis -> cadeia (grupo opcional repetiu)
   grep -q 'a := 0' "$D/storex.ppo" && grep -q 'a := b := c := 9' "$D/storex.ppo"
   check ".ppo: STORE 9 TO a,b,c -> a := b := c := 9 (grupo opcional repetido)" $?
   # ast dump: o marker da lista e REGULAR dentro de opt-open/opt-close (nao e mkind list)
   grep -q '"role": "opt-open"' "$D/storex.ast.json"
   check "ast-5 dump: o [,<vN>] e grupo opcional (opt-open/opt-close), vN regular" $?
}

# --------------------------------------------------------------------------
# Familia hbclass (hbclass.ch) - o dialeto OO INTEIRO e diretiva de pp: paste
# do nome gerado (Conta_Deposita), diretiva que GERA diretiva (genealogia
# ast-13), registro oClass:AddMethod/AddMultiData, Self AS CLASS := QSelf().
# hbclass.ch NAO e auto-incluida -> precisa -I<core>/include
# --------------------------------------------------------------------------
corpus_class() {
   echo "corpus: familia hbclass (hbclass.ch) - o dialeto OO e diretiva de pp"
   ( cd "$HERE/ppc-class" && "$HB" clsx.prg -n -q0 -w3 -es2 -s -I"$HB_INC" > /dev/null 2>&1 )
   check "ppc-class/clsx.prg compila limpo sob -w3 -es2 (codigo comprovado)" $?
   local D; D=$(gen4 ppc-class clsx.prg -I"$HB_INC")
   # .ppt: o PASTE do nome da funcao gerada (Conta_Deposita) via (concatenate)
   grep -q '(concatenate) >Conta_Deposita<' "$D/clsx.ppt"
   check ".ppt: METHOD cola o nome da funcao gerada (concatenate Conta_Deposita)" $?
   # .ppt: a diretiva que GERA outra diretiva (o #xcommand METHOD ... CLASS Conta)
   grep -q '#xcommand METHOD .* Deposita CLASS Conta' "$D/clsx.ppt"
   check ".ppt: METHOD (decl) GERA a diretiva da impl (#xcommand ... CLASS Conta)" $?
   # .ppt: a impl nasce com Self tipado - Self AS CLASS Conta := QSelf()
   grep -q 'local Self AS CLASS Conta := QSelf() AS CLASS Conta' "$D/clsx.ppt"
   check ".ppt: a impl nasce com Self AS CLASS Conta := QSelf() (RD/M-B)" $?
   # ast dump: a regra METHOD gerada carrega genealogia (from) - ast-13
   grep -q '"from"' "$D/clsx.ast.json"
   check "ast-13: a regra METHOD gerada carrega genealogia ('from')" $?
}

# --------------------------------------------------------------------------
# Familia MARKERS (hbpp.h/ppcore.c) - os 15 tipos de <x>. Fixture tests/fixmk
# (a mesma do caso 111): exercita os 6 match-mkinds e os 7 result-mkinds
# escriviveis. strdump e dynval tem RECUSA DOCUMENTADA (nao existem em regra).
# --------------------------------------------------------------------------
corpus_markers() {
   echo "corpus: familia MARKERS - os 15 tipos de <x> do pp"
   ( cd "$HERE/fixmk" && "$HB" mk.prg -n -q0 -w3 -es2 -s -I. > /dev/null 2>&1 )
   check "fixmk/mk.prg compila limpo sob -w3 -es2 (codigo comprovado)" $?
   local D; D=$(gen4 fixmk mk.prg -I"$HERE/fixmk")
   # .ppo: cada mkind se revela na expansao
   grep -q 'QOut( "LIGA" )' "$D/mk.ppo" && grep -q 'QOut( Eval( {|| n + 1} ) )' "$D/mk.ppo"
   check ".ppo: restrict+smart-quote vira string; block EMBRULHA num codeblock" $?
   # logical emite .T. (nao o valor) e nul nao emite nada - os dois DESCARTAM
   grep -q 'QOut( .T. )' "$D/mk.ppo" && grep -q 'QOut( 42 )' "$D/mk.ppo" && \
      grep -q 'QOut( "wild" )' "$D/mk.ppo"
   check ".ppo: logical/nul/wild-nao-usado DESCARTAM o valor que o usuario escreveu" $?
   # ast-14: todo marker de match e numerado -> o recheio vem LIGADO ao marker
   grep -q '"mkind": "wild"' "$D/mk.ast.json" && grep -q '"mkind": "restrict"' "$D/mk.ast.json" && \
      grep -q '"mkind": "logical"' "$D/mk.ast.json" && grep -q '"mkind": "nul"' "$D/mk.ast.json" && \
      grep -q '"mkind": "block"' "$D/mk.ast.json"
   check "ast dump: os mkinds wild/restrict/logical/nul/block todos exportados" $?
}

# --------------------------------------------------------------------------
# Familia <@> (reference) - o guarda anti-recursao de regras circulares
# --------------------------------------------------------------------------
corpus_ref() {
   echo "corpus: familia <@> - o guarda anti-recursao (regra circular)"
   ( cd "$HERE/ppc-ref" && "$HB" refx.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 )
   check "ppc-ref/refx.prg compila limpo (o <@> IMPEDIU o loop infinito)" $?
   local D; D=$(gen4 ppc-ref refx.prg)
   # o guarda e INVISIVEL ao compilador: some da saida expandida
   grep -q 'PUBLIC nA, nB' "$D/refx.ppo" && ! grep -q '<@>' "$D/refx.ppo"
   check ".ppo: a regra circular expandiu, e o <@> sumiu antes do compilador" $?
   # mas o dump o EXPORTA (mkind reference), sem nome e sem posicao
   grep -q '"mkind": "reference"' "$D/refx.ast.json"
   check "ast dump: o guarda vem como mkind 'reference' (sem nome, sem posicao)" $?
}

# --------------------------------------------------------------------------
# Familia REGRA QUE GERA REGRA - a diretiva que cria outra diretiva (ast-13)
# --------------------------------------------------------------------------
corpus_gen() {
   echo "corpus: familia REGRA QUE GERA REGRA - diretiva que cria diretiva"
   ( cd "$HERE/ppc-gen" && "$HB" genx.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 )
   check "ppc-gen/genx.prg compila limpo sob -w3 -es2 (codigo comprovado)" $?
   local D; D=$(gen4 ppc-gen genx.prg)
   # .ppt: a regra NASCE e ja e USADA na mesma compilacao (multi-passe)
   grep -q '#xcommand >#xcommand USA Ponto' "$D/genx.ppt"
   check ".ppt: DEFREGRA EMITE uma diretiva nova (#xcommand USA Ponto)" $?
   grep -q 'genx.prg(9) >USA Ponto<' "$D/genx.ppt" && grep -q 'Marca( "Ponto" )' "$D/genx.ppo"
   check ".ppt/.ppo: a regra recem-nascida ja casa na linha seguinte" $?
   # ast-13: a regra gerada carrega a genealogia (from -> a app que a criou)
   grep -q '"from"' "$D/genx.ast.json"
   check "ast-13: a regra gerada carrega genealogia ('from' -> a app criadora)" $?
}

# --------------------------------------------------------------------------
# Familia ESTRUTURA DA REGRA - sem cabeca, opcionais fora de ordem, multi-passe
# (docs/pp-corpus/rule-structure.md)
# --------------------------------------------------------------------------
corpus_rulestruct() {
   echo "corpus: familia ESTRUTURA DA REGRA - sem cabeca / opcionais fora de ordem / multi-passe"
   ( cd "$HERE/fixp6" && "$HB" p6.prg -n -q0 -w3 -es2 -s -I. > /dev/null 2>&1 )
   check "fixp6/p6.prg compila limpo sob -w3 -es2" $?
   local D; D=$(gen4 fixp6 p6.prg -I"$HERE/fixp6")
   # regra SEM CABECA: o match comeca com um MARKER -> head null (ppcore.c:1161)
   grep -q '"head": null' "$D/p6.ast.json"
   check "ast dump: regra SEM CABECA existe e vem com head null" $?
   # opcionais FORA DE ORDEM: o valor cai no slot certo mesmo invertido
   grep -q 'RETURN { "Elmo", "bronze", 3 }' "$D/p6.ppo"
   check ".ppo: grupos opcionais INVERTIDOS casam e caem no slot certo" $?
   grep -q 'RETURN { "Escudo",, }' "$D/p6.ppo"
   check ".ppo: grupos opcionais AUSENTES viram argumento vazio" $?
   # MULTI-PASSE: a regra VULK e reaplicada sobre o RESULTADO da GLIMER
   grep -q 'FUNCTION vk_Broquel() ;; RETURN { "Broquel", "base", }' "$D/p6.ppo"
   check ".ppo: MULTI-PASSE - o resultado de uma regra e re-consumido por outra" $?
}

# --------------------------------------------------------------------------
# Familia ABREVIACAO dBase - a keyword pela metade, e o fato ruletok (ast-15)
# (docs/pp-corpus/abbreviation.md)
# --------------------------------------------------------------------------
corpus_abbrev() {
   echo "corpus: familia ABREVIACAO dBase - keyword pela metade + ruletok (ast-15)"
   ( cd "$HERE/fixabr" && "$HB" abr.prg -n -q0 -w3 -es2 -s -I. > /dev/null 2>&1 )
   check "fixabr/abr.prg compila limpo (inclui uso ABREVIADO: APAG = APAGAR)" $?
   local D; D=$(gen4 fixabr abr.prg -I"$HERE/fixabr")
   # o pp ACEITA a keyword abreviada (>= 4 letras) nas familias SEM 'x'
   grep -q 'zz_( 3, 0 )' "$D/abr.ppo"
   check ".ppo: #command casa a keyword ABREVIADA (APAG -> APAGAR, ppcore.c:2533)" $?
   # ast-15: o dump diz QUAL literal da regra cada token casou
   grep -q '"ruletok"' "$D/abr.ast.json"
   check "ast dump: ast-15 exporta ruletok (QUAL literal da regra o site casou)" $?
   # o furo que o ast-15 matou: a keyword secundaria GRAV, escrita POR EXTENSO,
   # casa o literal #2 do match[] - e NAO a cabeca (indice 0) abreviada
   python3 "$HERE/ppc-ruletok.py" "$D/abr.ast.json"
   check "ast-15: a keyword secundaria casa o literal #2 - NAO e a cabeca abreviada" $?
}

# --------------------------------------------------------------------------
# Familia PP COMO INSTRUMENTO - os canais do core e o que cada um DESTROI
# (docs/pp-corpus/pp-as-instrument.md)
# --------------------------------------------------------------------------
corpus_instrument() {
   echo "corpus: familia PP COMO INSTRUMENTO - canais do core (.ppo / -u / -gd)"
   local D="$HERE/tmp/ppc-instr"
   rm -rf "$D"; mkdir -p "$D/inc"
   cp "$HERE/ppc-instr/far.ch" "$D/inc/"
   cp "$HERE/ppc-instr/m.prg" "$D/"
   ( cd "$D" && "$HB" m.prg -n -q0 -p -u -s -Iinc > /dev/null 2>&1 )
   # -u ISOLA: aplica so as regras do usuario; o resto da linguagem passa intacto
   grep -q "MODERNO Alfa VALOR nX" "$D/m.ppo" && grep -q '? "oi"' "$D/m.ppo"
   check "-u: o pp aplica so as MINHAS regras (o '?' NAO vira QOut)" $?
   # ...mas o .ppo DESTROI tudo que nao e codigo -> nao pode ser FONTE (recusa do P7)
   [ "$(grep -c '//' "$D/m.ppo")" = "0" ] && ! grep -q '#include' "$D/m.ppo"
   check ".ppo DESTROI comentarios e #include - nao serve como FONTE (recusa do P7)" $?
   # -gd: o CORE diz quais includes usou, com o caminho ONDE ACHOU
   ( cd "$D" && "$HB" m.prg -n -q0 -sm -gd -Iinc > /dev/null 2>&1 )
   grep -q "inc/far.ch" "$D/m.d"
   check "-gd: o compilador reporta o include com o CAMINHO RESOLVIDO (nao o nome cru)" $?
}

corpus_set
corpus_say
corpus_store
corpus_class
corpus_markers
corpus_ref
corpus_gen
corpus_rulestruct
corpus_abbrev
corpus_instrument

echo
echo "ppcorpus: passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
