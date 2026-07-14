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
# escriviveis. (O strdump tem familia propria - corpus_strdump: a recusa dele era
# FALSA. Segue recusado so' o dynval, canal interno do pp.)
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
   # regra SEM CABECA: o match comeca com um MARKER -> head null (ppcore.c:1284)
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
   check ".ppo: #command casa a keyword ABREVIADA (APAG -> APAGAR, ppcore.c:2725)" $?
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
   ( cd "$D" && "$HB" m.prg -n -q0 -p -p+ -u -s -Iinc > /dev/null 2>&1 )
   # -u ISOLA: aplica so as regras do usuario; o resto da linguagem passa intacto
   # (o alvo da migracao e' CODIGO -- far_Migrado --, porque fixture TEM de compilar;
   #  o passo INTERMEDIARIO da migracao vive no .ppt, o oraculo do multi-passe)
   grep -q 'far_Migrado( "Alfa", nX )' "$D/m.ppo" && grep -q '? "oi"' "$D/m.ppo"
   check "-u: o pp aplica so as MINHAS regras (o '?' NAO vira QOut)" $?
   grep -q "MODERNO Alfa VALOR nX" "$D/m.ppt"
   check ".ppt: o passo INTERMEDIARIO da migracao (DSL velha -> DSL nova) e' visivel" $?
   # ...mas o .ppo DESTROI tudo que nao e codigo -> nao pode ser FONTE (recusa do P7)
   [ "$(grep -c '//' "$D/m.ppo")" = "0" ] && ! grep -q '#include' "$D/m.ppo"
   check ".ppo DESTROI comentarios e #include - nao serve como FONTE (recusa do P7)" $?
   # -gd: o CORE diz quais includes usou, com o caminho ONDE ACHOU
   ( cd "$D" && "$HB" m.prg -n -q0 -sm -gd -Iinc > /dev/null 2>&1 )
   grep -q "inc/far.ch" "$D/m.d"
   check "-gd: o compilador reporta o include com o CAMINHO RESOLVIDO (nao o nome cru)" $?
}

# --------------------------------------------------------------------------
# Familia PP VIVO (P11) - __pp_init/__pp_process: o pp do core EM PROCESSO.
# Reabre o veredito do P7 (recusei "pp como escritor" olhando so o .ppo).
# --------------------------------------------------------------------------
corpus_pplive() {
   echo "corpus: familia PP VIVO - __pp_init/__pp_process (o pp em processo, linha a linha)"
   local D="$HERE/tmp/ppc-live"
   rm -rf "$D"; mkdir -p "$D/inc"
   cp "$HERE/ppc-live/live.prg" "$D/"
   cp "$HERE/ppc-instr/far.ch" "$D/inc/"
   cp "$HERE/ppc-instr/m.prg" "$D/"
   # o pp do BUILD: expande o site (canal de arquivo, com -u). A comparacao com o pp
   # VIVO se faz no .ppt: o pp vivo tem SO' a regra ANTIGO registrada, entao ele para
   # em `MODERNO Alfa VALOR nX` -- que e' exatamente o passo que o .ppt do build mostra
   ( cd "$D" && "$HB" m.prg -n -q0 -p -p+ -u -s -Iinc > /dev/null 2>&1 )
   # o pp VIVO: mesma regra, mesmo site, em processo
   ( cd "$D" && "$HB_BIN/hbmk2" live.prg -o"$D/live" -q0 -w3 -es2 -gtcgi > /dev/null 2>&1 )
   ( cd "$D" && ./live > live.out 2>&1 )

   # (1) EQUIVALENCIA: o pp vivo produz o MESMO texto que o pp do build
   grep -q "SPAN=\[MODERNO Alfa VALOR nX\]" "$D/live.out"
   check "pp VIVO expande o site igual ao pp do BUILD (.ppo): 'MODERNO Alfa VALOR nX'" $?
   grep -q "MODERNO Alfa VALOR nX" "$D/m.ppt"
   check "  ...e o pp do BUILD concorda, no .ppt (a equivalencia e com o MESMO fato)" $?

   # (2) O LIMITE HONESTO: o pp COME o comentario da linha que voce alimenta.
   # A destruicao NAO e privilegio do canal de arquivo - e do que se ALIMENTA.
   # Dai a regra do escritor: alimente o SPAN da statement (posicoes vem do
   # dump) e grave so o span; o comentario vive FORA do span e nunca passa
   # pelo pp. E o que separa "pp como escritor" (viavel) do .ppo (recusado).
   grep -q "LINHA=\[MODERNO Alfa VALOR nX\]" "$D/live.out" && ! grep -q "manter!" "$D/live.out"
   check "o pp COME o comentario da LINHA alimentada -> alimente o SPAN, nunca a linha" $?
}

# --------------------------------------------------------------------------
# Familia STRDUMP - o `#<x>`, o mkind que o corpus dava como INEXISTENTE em
# regra (docs/pp-corpus/strdump.md). Prova nos DOIS lados: a DSL inventada
# (nao-espelho) e a diretiva REAL do core (hbclass.ch:576, ASSOCIATE).
# --------------------------------------------------------------------------
corpus_strdump() {
   echo "corpus: familia STRDUMP - o #<x> (o mkind dado como inexistente em regra)"
   local CORE="${HB_BIN%/bin/*}" R="$HERE/tmp/.ppcorpus/ppc-strdump-run"
   # (0) a metade EXECUTAVEL: o .prg RODA e se AFIRMA (hbtest + pp vivo) - virada
   #     de metodo 2026-07-14: comentario sem assert e' opiniao
   rm -rf "$R"; mkdir -p "$R"; cp "$HERE/ppc-strdump/sdrun.prg" "$R"/
   ( cd "$R" && "$HB_BIN/hbmk2" sdrun.prg "$CORE/contrib/hbtest/hbtest.hbc" \
        -osdrun -q0 -w3 -es2 -gtcgi > /dev/null 2>&1 )
   check "ppc-strdump/sdrun.prg compila (hbtest + pp vivo)" $?
   ( cd "$R" && ./sdrun > run.txt 2>&1 )
   [ "$(grep -c 'MAIN(' "$R/run.txt")" -ge 5 ] && ! grep -q '^ *!' "$R/run.txt"
   check "sdrun.prg RODA: os asserts passam (0 falhas) - o #<x> estringifica o NOME" $?
   ( cd "$HERE/ppc-strdump" && "$HB" sd.prg -n -q0 -w3 -es2 -s -I. -I"$CORE/contrib/hbtest" > /dev/null 2>&1 )
   check "ppc-strdump/sd.prg compila limpo sob -w3 -es2 (codigo comprovado)" $?
   # o sd.prg tambem RODA: os asserts provam que a linha da colisao e' DADO (a funcao
   # recebe a string "nLastro", nao o valor 7 da variavel homonima)
   cp "$HERE/ppc-strdump/sd.ch" "$R"/ 2>/dev/null
   cp "$HERE/ppc-strdump/sd.prg" "$R"/
   ( cd "$R" && "$HB_BIN/hbmk2" sd.prg "$CORE/contrib/hbtest/hbtest.hbc" \
        -osd -q0 -w3 -es2 -gtcgi > /dev/null 2>&1 && ./sd > runsd.txt 2>&1 )
   [ "$(grep -c 'MAIN(' "$R/runsd.txt")" -ge 3 ] && ! grep -q '^ *!' "$R/runsd.txt"
   check "sd.prg RODA: o assert prova que 'LAVRA nLastro' entrega a STRING, nao o valor" $?
   local D; D=$(gen4 ppc-strdump sd.prg -I"$HERE/ppc-strdump" -I"$CORE/contrib/hbtest")
   # .ppo: o #<x> estringifica o NOME escrito - sobre simbolo E sobre texto cru
   grep -q 'nLastro := sd_Afere( "nLastro" )' "$D/sd.ppo" && \
      grep -q 'sd_Lavra( "fundo de reserva" )' "$D/sd.ppo"
   check ".ppo: #<x> vira STRING do que foi escrito (sobre simbolo e sobre texto cru)" $?
   # ast-5: o strdump EXISTE no result[] de regra (a recusa documentada era FALSA)
   grep -q '"mkind": "strdump"' "$D/sd.ast.json"
   check "ast-5: strdump EXISTE no result[] de regra (nao e' so' maquinaria de stream)" $?
   # ast-12: o recheio que alimenta o stringify vem marcado como GERADOR
   python3 "$HERE/ppc-strdump-sep.py" "$D/sd.ast.json" "$HERE/ppc-strdump/sd.prg"
   check "o que SEPARA nao e' o generates (true nos DOIS) e sim a OP: clone x stringify" $?
   # e o .ppo confirma o efeito: a colisao de nome vira STRING, nao variavel
   grep -q 'sd_Lavra( "nLastro" )' "$D/sd.ppo"
   check ".ppo: 'LAVRA nLastro' vira a STRING \"nLastro\" - a palavra nunca vira simbolo" $?
   # ...e o .ppt mostra QUAL regra consumiu cada um (o oraculo do CAMINHO, que o
   # comentario da fixture cola: se o traco mudar, a doc quebra junto)
   grep -q '#xcommand >nLastro := sd_Afere( "nLastro" )<' "$D/sd.ppt" && \
      grep -q '#xcommand >sd_Lavra( "nLastro" )<' "$D/sd.ppt"
   check ".ppt: o traco mostra as DUAS regras consumindo o MESMO texto de forma oposta" $?
   # a prova que NAO depende da minha DSL: a diretiva REAL do core
   local C; C=$(gen4 ppc-class clsx.prg -I"$HB_INC")
   python3 "$HERE/ppc-strdump.py" "$C/clsx.ast.json" "hbclass.ch" ASSOCIATE > /dev/null
   check "strdump em diretiva REAL do core: hbclass.ch:576 (ASSOCIATE ... #<type>)" $?
}

# --------------------------------------------------------------------------
# Familia TEXT/ENDTEXT (std.ch:221) - a maquinaria de STREAM do pp: cada linha
# crua vira uma STRING (o pp FABRICA um marker strdump, ppcore.c:5821).
# O assunto e' a colisao DADO x SIMBOLO, e o canal ast-17 que a torna
# RELATAVEL. (docs/pp-corpus/text-stream.md)
# --------------------------------------------------------------------------
corpus_text() {
   echo "corpus: familia TEXT/ENDTEXT - a maquinaria de stream (dado x simbolo)"
   local CORE="${HB_BIN%/bin/*}" R="$HERE/tmp/.ppcorpus/ppc-text-run"
   rm -rf "$R"; mkdir -p "$R"; cp "$HERE/ppc-text/txt.prg" "$R"/
   ( cd "$R" && "$HB_BIN/hbmk2" txt.prg "$CORE/contrib/hbtest/hbtest.hbc" \
        -otxt -q0 -w3 -es2 -gtcgi > /dev/null 2>&1 )
   check "ppc-text/txt.prg compila (hbtest)" $?
   ( cd "$R" && ./txt > run.txt 2>&1 )
   [ "$(grep -c 'MAIN(' "$R/run.txt")" -ge 4 ] && ! grep -q '^ *!' "$R/run.txt"
   check "txt.prg RODA: o bloco entrega TEXTO cru (a palavra homonima nao virou valor)" $?

   local D; D=$(gen4 ppc-text txt.prg -I"$CORE/contrib/hbtest")
   # .ppo: a linha crua vira argumento de chamada -- e as chamadas que o PP fabricou
   # foram re-escaneadas pelas regras (a nossa regra QOut() as capturou)
   grep -q 'tx_Cap( "   Relatorio mensal" )' "$D/txt.ppo" && \
      grep -q 'tx_Cap( "   cSaldo apurado no periodo" )' "$D/txt.ppo"
   check ".ppo: cada linha do bloco vira UMA chamada, com a linha CRUA (margem inclusa)" $?
   # ast-17: a string do bloco carrega a linha de onde veio (antes: line 0/col null)
   python3 "$HERE/ppc-text-pos.py" "$D/txt.ast.json" "$HERE/ppc-text/txt.prg"
   check "ast-17: a linha do bloco chega POSICIONADA (da' para RELATAR, nunca editar)" $?
}

# --------------------------------------------------------------------------
# Familia DEFINE DINAMICO - o mkind `dynval` (ppcore.c:7253): __FILE__ e
# __LINE__, as UNICAS duas regras dele, e ambas BUILTIN do pp. O assunto e' a
# sensibilidade a POSICAO. (docs/pp-corpus/dynval.md)
# --------------------------------------------------------------------------
corpus_dyn() {
   echo "corpus: familia DEFINE DINAMICO - __FILE__/__LINE__ (sensibilidade a POSICAO)"
   ( cd "$HERE/ppc-dyn" && "$HB" dyn.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 )
   check "ppc-dyn/dyn.prg compila limpo sob -w3 -es2 (codigo comprovado)" $?
   local D; D=$(gen4 ppc-dyn dyn.prg)
   # .ppo: o __LINE__ vira a LINHA CORRENTE, computada do fonte (nunca na mao)
   local L; L=$(python3 -c "
import sys
src = open('$HERE/ppc-dyn/dyn.prg').read().split(chr(10))
print([i + 1 for i, l in enumerate(src) if 'log:' in l][0])")
   grep -q "QOut( \"log:\", $L )" "$D/dyn.ppo"
   check ".ppo: __LINE__ expande para a LINHA CORRENTE ($L) - o valor SEGUE a posicao" $?
   grep -q 'cOnde   := "dyn.prg"' "$D/dyn.ppo"
   check ".ppo: __FILE__ expande para o nome do arquivo" $?
   # o dump EXPORTA as duas regras builtin, e SO' elas tem mkind dynval
   python3 - "$D/dyn.ast.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
dyn = sorted(r.get("head") for r in d["ppRules"]
             if any(m.get("mkind") == "dynval" for m in (r.get("result") or [])))
sys.exit(0 if dyn == ["__FILE__", "__LINE__"] else 1)
PYEOF
   check "ast-5: dynval existe em DUAS regras, as builtin __FILE__/__LINE__ - e SO'" $?
   # e cada expansao vem REGISTRADA com a linha: e' o fato que permite AVISAR
   # que o modulo e' sensivel a posicao (nenhuma regra do usuario e' dynval:
   # a recusa 'nao escrivivel' sobrevive a medicao - 0 em 4.582 regras reais)
   python3 - "$D/dyn.ast.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
apps = [a["line"] for a in d["ppApplications"]
        if d["ppRules"][a["rule"]].get("head") == "__LINE__"]
sys.exit(0 if len(apps) == 2 else 1)
PYEOF
   check "ppApplications: cada expansao de __LINE__ vem com a LINHA (da' para AVISAR)" $?
}

# --------------------------------------------------------------------------
# GUARDA DAS CITACOES DO CORE (tests/corerefs.txt) - o corpus cita `arquivo:linha`
# do fonte do Harbour o tempo todo, e TODA edicao minha no core faz essas linhas
# andarem, EM SILENCIO. Aqui elas berram. (2026-07-13: o ast-17 apodreceu 6
# citacoes no mesmo dia, e uma antiga ja' apontava para codigo sem relacao.)
# --------------------------------------------------------------------------
corpus_refs() {
   echo "corpus: as CITACOES do core (docs apontam arquivo:linha - elas ainda batem?)"
   local CORE="${HB_BIN%/bin/*}" bad=0 ref txt f l
   while IFS=$'\t' read -r ref txt; do
      case "$ref" in ''|'#'*) continue ;; esac
      f="${ref%:*}"; l="${ref##*:}"
      if ! sed -n "${l}p" "$CORE/$f" 2>/dev/null | grep -qF "$txt"; then
         bad=$((bad+1))
         note "     PODRE: $f:$l nao contem '$txt'"
         note "     ->  a linha VERDADEIRA hoje: $(grep -nF "$txt" "$CORE/$f" | head -1 | cut -d: -f1)"
      fi
   done < "$HERE/corerefs.txt"
   [ "$bad" -eq 0 ]
   check "toda citacao arquivo:linha do core ainda aponta para o codigo que a doc diz" $?
}

# --------------------------------------------------------------------------
# Familia OS QUATRO ESTRINGIFICADORES - <z> x <"z"> x <(z)> x #<z>, e o MACRO
# (docs/pp-corpus/stringify-family.md). Assunto vindo do teste do PROPRIO pp
# (harbour/tests/pp.prg), indicado pelo Diego.
# --------------------------------------------------------------------------
corpus_strfam() {
   echo "corpus: OS QUATRO ESTRINGIFICADORES - e o que cada um faz com um MACRO"
   local CORE="${HB_BIN%/bin/*}" D="$HERE/tmp/.ppcorpus/ppc-strfam"
   rm -rf "$D"; mkdir -p "$D"; cp "$HERE/ppc-strfam"/*.prg "$D"/

   # (1) o CORPUS de verdade: o .prg RODA e se AFIRMA (hbtest do core, 20 asserts;
   #     camada A = o pp VIVO diz o que a diretiva VIRA; camada B = o valor que ela VALE)
   ( cd "$D" && "$HB_BIN/hbmk2" sf.prg "$CORE/contrib/hbtest/hbtest.hbc" \
        -osf -q0 -w3 -es2 -gtcgi > /dev/null 2>&1 )
   check "ppc-strfam/sf.prg compila (hbtest + pp vivo)" $?
   ( cd "$D" && ./sf > run.txt 2>&1 )
   [ "$(grep -c 'MAIN(' "$D/run.txt")" -ge 20 ] && ! grep -q '^ *!' "$D/run.txt"
   check "sf.prg RODA: os 20 asserts do hbtest passam (0 falhas) - a prova e' EXECUTADA" $?

   # (2) o que nao se ve em runtime: os oraculos, na fixture irma (sem #require)
   ( cd "$D" && "$HB" sfdump.prg -n -q0 -w3 -es2 -s > /dev/null 2>&1 )
   check "ppc-strfam/sfdump.prg compila limpo sob -w3 -es2" $?
   ( cd "$D" && "$HB" sfdump.prg -n -q0 -p > /dev/null 2>&1 )
   ( cd "$D" && "$HB" sfdump.prg -n -q0 -xsfdump.ast.json > /dev/null 2>&1 )
   ( cd "$D" && "$HB" sfdump.prg -n -q0 -p+ > /dev/null 2>&1 )
   grep -q 'sf_( cAlvo )' "$D/sfdump.ppo"
   check ".ppo: o strstd sobre MACRO desfaz o & e emite o SIMBOLO (nao a string)" $?
   # o .ppt e' o oraculo do PASSO A PASSO (Diego: "tem que analisar os oraculos,
   # incluindo o ppt") - aqui ele mostra a REGRA que casou e o texto que ela emitiu
   grep -q '#xtranslate >sf_( cAlvo )<' "$D/sfdump.ppt"
   check ".ppt: o traco mostra a regra casando e emitindo o simbolo (nao a string)" $?
   python3 - "$D/sfdump.ast.json" <<'PYEOF2'
import json, sys
d = json.load(open(sys.argv[1]))
ok = any(t.get("text", "").upper() == "CALVO" and
         any(f["op"] == "clone" for f in (t.get("from") or []))
         for t in d["tokens"])
sys.exit(0 if ok else 1)
PYEOF2
   check "ast-3: o simbolo que saiu de dentro do macro chega como CLONE (e' simbolo)" $?
   python3 - "$D/sfdump.ast.json" <<'PYEOF3'
import json, sys
d = json.load(open(sys.argv[1]))
fill = [t for a in d["ppApplications"] for t in a["tokens"]
        if str(t.get("text", "")).startswith("&")]
emitted = [t for t in d["tokens"]
           if t.get("text", "").upper() == "CALVO" and t.get("from")
           and t.get("col") is None]
sys.exit(0 if fill and fill[0].get("col") is not None and emitted else 1)
PYEOF3
   check "P18 (LACUNA VIVA): o recheio '&x' TEM posicao; o simbolo emitido NAO" $?
}

# --------------------------------------------------------------------------
# GUARDA UNIVERSAL: TODO .prg do corpus COMPILA. Sem excecao, sem "esqueci de
# rodar esse". Cada fixture e' compilada com o toolchain CERTO:
#   - tem `#require "hbtest"`  -> hbmk2 + contrib/hbtest/hbtest.hbc  (o harbour cru
#     NAO resolve #require: e' esperado, e esta' escrito no cabecalho do arquivo)
#   - nao tem                  -> harbour -w3 -es2 -s (regua do caso 0)
# (ordem do Diego, 2026-07-14: "tem e' que garantir que vai compilar todos os
# exemplos" -- um .prg do corpus que nao compila e' conhecimento podre.)
# --------------------------------------------------------------------------
corpus_compile_all() {
   echo "corpus: TODO .prg do corpus COMPILA (guarda universal)"
   local CORE="${HB_BIN%/bin/*}" D="$HERE/tmp/.ppcorpus/compile-all" bad=0 f dir
   rm -rf "$D"; mkdir -p "$D"
   for f in "$HERE"/ppc-*/*.prg; do
      dir="$(dirname "$f")"
      if grep -q '#include "hbtest.ch"' "$f"; then
         ( cd "$D" && "$HB_BIN/hbmk2" "$f" "$CORE/contrib/hbtest/hbtest.hbc" \
              -o"$D/$(basename "${f%.prg}")" -q0 -w3 -es2 -gtcgi > /dev/null 2>&1 ) \
            || { bad=$((bad+1)); note "     NAO COMPILA (hbmk2+hbtest): ${f#"$HERE"/}"; }
         ( cd "$dir" && "$HB" "$(basename "$f")" -n -q0 -w3 -es2 -s \
              -I. -I"$HB_INC" -I"$CORE/contrib/hbtest" > /dev/null 2>&1 ) \
            || { bad=$((bad+1)); note "     NAO COMPILA no harbour CRU (o IDE vai marcar vermelho): ${f#"$HERE"/}"; }
      else
         ( cd "$dir" && "$HB" "$(basename "$f")" -n -q0 -w3 -es2 -s \
              -I. -I"$HB_INC" -I"$CORE/contrib/hbtest" > /dev/null 2>&1 ) \
            || { bad=$((bad+1)); note "     NAO COMPILA (harbour -w3 -es2): ${f#"$HERE"/}"; }
      fi
   done
   [ "$bad" -eq 0 ]
   check "todos os .prg de tests/ppc-*/ compilam com o toolchain do branch" $?
}

# --------------------------------------------------------------------------
# Familia CICLO DO PP - o pp esgota o comando antes de avancar (ppcore.c:6587)
# (docs/pp-corpus/pass-cycle.md)
# --------------------------------------------------------------------------
corpus_cycle() {
   echo "corpus: CICLO DO PP - a linha e' reprocessada ate' ninguem casar (e o teto)"
   local CORE="${HB_BIN%/bin/*}" R="$HERE/tmp/.ppcorpus/ppc-cycle-run"
   rm -rf "$R"; mkdir -p "$R"; cp "$HERE/ppc-cycle/cyc.prg" "$R"/
   ( cd "$R" && "$HB_BIN/hbmk2" cyc.prg "$CORE/contrib/hbtest/hbtest.hbc" \
        -ocyc -q0 -w3 -es2 -gtcgi > /dev/null 2>&1 )
   check "ppc-cycle/cyc.prg compila (a cadeia de 4 regras se resolve)" $?
   ( cd "$R" && ./cyc > run.txt 2>&1 )
   [ "$(grep -c 'MAIN(' "$R/run.txt")" -ge 2 ] && ! grep -q '^ *!' "$R/run.txt"
   check "cyc.prg RODA: E1 chegou ao compilador ja' como cy_Marca (cadeia esgotada)" $?

   # .ppt: a MESMA linha aparece quatro vezes, e so' depois vem a proxima
   local D; D=$(gen4 ppc-cycle cyc.prg -I"$CORE/contrib/hbtest")
   python3 "$HERE/ppc-cycle-ppt.py" "$D/cyc.ppt" "$HERE/ppc-cycle/cyc.prg"
   check ".ppt: os 4 passes acontecem NA MESMA linha, antes de o pp avancar" $?

   # o TETO: a mesma cadeia com #pragma RECURSELEVEL=2 NAO compila -- o pp acusa
   # circularidade (E0022) e deixa o token por expandir. O arquivo do teto e' gerado
   # aqui (o repo so' guarda .prg que COMPILAM - guarda corpus_compile_all)
   sed 's|^#include "hbtest.ch"|#include "hbtest.ch"\n#pragma RECURSELEVEL=2|' \
      "$HERE/ppc-cycle/cyc.prg" > "$R/teto.prg"
   ( cd "$R" && "$HB" teto.prg -n -q0 -s -I"$CORE/contrib/hbtest" > teto.err 2>&1 )
   grep -q "E0022" "$R/teto.err"
   check "#pragma RECURSELEVEL=2: a mesma cadeia ESTOURA o teto (E0022 circularidade)" $?
}

# --------------------------------------------------------------------------
# O PLACAR DA REVISAO. O corpus esta' migrando para o METODO V2 (docs/pp-corpus/
# METODO.md): o conhecimento mora no .prg, o comentario INTERPRETA o oraculo, e o
# que ele afirma esta' provado por assert (hbtest) ou pelo dump.
# Fixture revisada carrega o selo `METODO-V2(<data>)` no cabecalho. Esta guarda
# NAO reprova as pendentes -- ela as NOMEIA, para a fila nao sumir de vista
# (ordem do Diego, 2026-07-14: "precisa dar um jeito de marcar os testes que esta'
# revisando... porque todo o resto do corpus precisa de revisao tambem").
# O que ela REPROVA: selo mentiroso -- arquivo selado que nao prova nada (sem
# HBTEST proprio e sem irmao com HBTEST na mesma familia).
# --------------------------------------------------------------------------
corpus_metodo() {
   echo "corpus: PLACAR DA REVISAO (metodo v2: assert + interpretacao do oraculo)"
   local f dir v2=0 pend=0 mentira=0 lista=""
   # conta TUDO que o corpus usa -- inclusive as fixtures de tests/fix*, que sao
   # compartilhadas com o contrato (revisar ali mexe no `make test`: apresentar o
   # drift antes, CLAUDE.md §3)
   for f in "$HERE"/ppc-*/*.prg "$HERE"/fixmk/mk.prg "$HERE"/fixp6/p6.prg "$HERE"/fixabr/abr.prg; do
      dir="$(dirname "$f")"
      if grep -q "METODO-V2" "$f"; then
         v2=$((v2+1))
         # selo so' vale se o arquivo prova: HBTEST nele ou num irmao da familia
         grep -lq "HBTEST" "$dir"/*.prg 2>/dev/null || {
            mentira=$((mentira+1)); note "     SELO SEM PROVA: ${f#"$HERE"/}"; }
      else
         pend=$((pend+1)); lista="$lista ${f#"$HERE"/}"
      fi
   done
   note "  revisadas (v2): $v2    PENDENTES: $pend"
   [ "$pend" -gt 0 ] && note "  fila:$lista"
   [ "$mentira" -eq 0 ]
   check "nenhum selo METODO-V2 sem prova (assert na fixture ou na familia)" $?
}

# --------------------------------------------------------------------------
# MARKDOWN SEM TESTE nao entra. Cada .md de familia declara, na primeira linha,
# qual guarda o prova:  <!-- guarda: corpus_xxx -->
# ...ou por que nao tem (PENDENTE / NENHUMA, com o motivo). Esta guarda reprova
# o .md sem declaracao e o que aponta para guarda inexistente; e NOMEIA os que
# estao sem prova. (Ordem do Diego, 2026-07-14: "tem muito markdown no pp-corpus
# que esta' sem testes".)
# --------------------------------------------------------------------------
corpus_docs() {
   echo "corpus: MARKDOWN x GUARDA (nenhuma familia sem prova, e nenhuma sem declaracao)"
   local m b tag bad=0 semprova=0 lista=""
   for m in "$HERE"/../docs/pp-corpus/*.md; do
      b="$(basename "$m" .md)"
      case "$b" in README|ROADMAP|METODO) continue ;; esac
      tag="$(sed -n '1s|<!-- guarda: \(.*\) -->|\1|p' "$m")"
      if [ -z "$tag" ]; then
         bad=$((bad+1)); note "     SEM DECLARACAO: docs/pp-corpus/$b.md (falta <!-- guarda: ... -->)"
      elif [ "${tag#corpus_}" != "$tag" ]; then
         grep -q "^${tag}()" "$HERE/ppcorpus.sh" || {
            bad=$((bad+1)); note "     GUARDA INEXISTENTE: $b.md aponta '$tag'"; }
      else
         semprova=$((semprova+1)); lista="$lista $b"
      fi
   done
   [ "$semprova" -gt 0 ] && note "  familias SEM PROVA no corpus ($semprova):$lista"
   [ "$bad" -eq 0 ]
   check "todo .md de familia declara a sua guarda, e a guarda existe" $?
}

# --------------------------------------------------------------------------
# O ast-schema.md sob GUARDA. Ele e' o unico markdown de FATO fora do pp-corpus --
# e o que mais mentiu (dizia que `strdump` nao existia em regra; que `__DATE__` era
# dinamico). A tabela de mkinds passa a ser conferida contra os dumps do corpus, nos
# DOIS sentidos: documentado-sem-aparecer e aparecendo-sem-documentacao.
# --------------------------------------------------------------------------
corpus_schema() {
   echo "corpus: o CONTRATO (ast-schema.md) x os dumps -- a tabela de mkinds bate?"
   python3 "$HERE/ppc-schema.py" "$HERE/../docs/ast-schema.md" "$HERE/tmp/.ppcorpus"
   check "todo mkind documentado aparece em dump (ou traz RECUSA); e vice-versa" $?
}

# --------------------------------------------------------------------------
# Familia DERIVACAO - clone x paste x stringify (docs/pp-corpus/derivation.md).
# Era markdown SEM TESTE, e e' a espinha de metade do corpus.
# --------------------------------------------------------------------------
corpus_deriv() {
   echo "corpus: DERIVACAO - as tres OPs (clone/paste/stringify) e o elo com offset"
   local CORE="${HB_BIN%/bin/*}" R="$HERE/tmp/.ppcorpus/ppc-deriv-run"
   rm -rf "$R"; mkdir -p "$R"; cp "$HERE/ppc-deriv/dv.prg" "$R"/
   ( cd "$R" && "$HB_BIN/hbmk2" dv.prg "$CORE/contrib/hbtest/hbtest.hbc" \
        -odv -q0 -w3 -es2 -gtcgi > /dev/null 2>&1 )
   check "ppc-deriv/dv.prg compila (a diretiva FORJA cria a funcao fj_Alfa)" $?
   ( cd "$R" && ./dv > run.txt 2>&1 )
   [ "$(grep -c 'MAIN(' "$R/run.txt")" -ge 4 ] && ! grep -q '^ *!' "$R/run.txt"
   check "dv.prg RODA: as 3 ops provadas nas DUAS camadas (texto do pp vivo + valor)" $?
   local D; D=$(gen4 ppc-deriv dv.prg -I"$CORE/contrib/hbtest")
   python3 "$HERE/ppc-deriv-ops.py" "$D/dv.ast.json" "$HERE/ppc-deriv/dv.prg"
   check "ast-3: clone chega POSICIONADO; paste/stringify vem sem posicao, ligados pelo 'from'" $?
}

# --------------------------------------------------------------------------
# Familia PP VIVO / API - __pp_Init/AddRule/Process/Reset (docs/pp-corpus/pp-api.md)
# --------------------------------------------------------------------------
corpus_ppapi() {
   echo "corpus: a API do pp VIVO - contextos, aninhamento, reset e o mundo separado"
   local CORE="${HB_BIN%/bin/*}" R="$HERE/tmp/.ppcorpus/ppc-ppapi-run"
   rm -rf "$R"; mkdir -p "$R"; cp "$HERE/ppc-ppapi/pa.prg" "$R"/
   ( cd "$R" && "$HB_BIN/hbmk2" pa.prg "$CORE/contrib/hbtest/hbtest.hbc" \
        -opa -q0 -w3 -es2 -gtcgi > /dev/null 2>&1 )
   check "ppc-ppapi/pa.prg compila (hbtest + pp vivo)" $?
   ( cd "$R" && ./pa > run.txt 2>&1 )
   [ "$(grep -c 'MAIN(' "$R/run.txt")" -ge 10 ] && ! grep -q '^ *!' "$R/run.txt"
   check "pa.prg RODA: estados independentes, reset preserva as padrao, e o pp de runtime NAO ve o arquivo" $?
}

# --------------------------------------------------------------------------
# Familia O QUE O PP *NAO* FAZ - ele nao avalia codigo, e nao acumula estado por
# passada (docs/pp-corpus/no-eval.md). Existe porque e' o erro de raciocinio mais
# comum sobre preprocessador -- e um raciocinio errado aqui contamina tudo.
# --------------------------------------------------------------------------
corpus_noeval() {
   echo "corpus: O QUE O PP NAO FAZ - substitui TEXTO; nao avalia (menos a condicao do #if)"
   local CORE="${HB_BIN%/bin/*}" R="$HERE/tmp/.ppcorpus/ppc-eval-run"
   rm -rf "$R"; mkdir -p "$R"; cp "$HERE/ppc-eval/ev.prg" "$R"/
   ( cd "$R" && "$HB_BIN/hbmk2" ev.prg "$CORE/contrib/hbtest/hbtest.hbc" \
        -oev -q0 -w3 -es2 -gtcgi > /dev/null 2>&1 )
   check "ppc-eval/ev.prg compila" $?
   ( cd "$R" && ./ev > run.txt 2>&1 )
   [ "$(grep -c 'MAIN(' "$R/run.txt")" -ge 12 ] && ! grep -q '^ *!' "$R/run.txt"
   check "ev.prg RODA: sem avaliacao (N*2=8); e o UNICO estado que atravessa e' a tabela de regras" $?
   # o .ppo mostra o que o compilador REALMENTE recebeu: `2 + 3 * 2`, nao `5 * 2`
   local D; D=$(gen4 ppc-eval ev.prg -I"$CORE/contrib/hbtest")
   grep -q "2 + 3 \* 2" "$D/ev.ppo"
   check ".ppo: o compilador recebeu '2 + 3 * 2' -- o pp NAO somou nada" $?
}

# --------------------------------------------------------------------------
# Familia ORDEM DAS REGRAS - a ULTIMA declarada vence (LIFO), nao a mais especifica
# (docs/pp-corpus/rule-order.md). Pergunta do Diego; e' o que faz o hbclass funcionar.
# --------------------------------------------------------------------------
corpus_order() {
   echo "corpus: ORDEM DAS REGRAS - quem vence quando duas casam o mesmo texto"
   local CORE="${HB_BIN%/bin/*}" R="$HERE/tmp/.ppcorpus/ppc-order-run"
   rm -rf "$R"; mkdir -p "$R"; cp "$HERE/ppc-order/od.prg" "$R"/
   ( cd "$R" && "$HB_BIN/hbmk2" od.prg "$CORE/contrib/hbtest/hbtest.hbc" \
        -ood -q0 -w3 -es2 -gtcgi > /dev/null 2>&1 )
   check "ppc-order/od.prg compila" $?
   ( cd "$R" && ./od > run.txt 2>&1 )
   [ "$(grep -c 'MAIN(' "$R/run.txt")" -ge 10 ] && ! grep -q '^ *!' "$R/run.txt"
   check "od.prg RODA: vence a ULTIMA declarada (LIFO) - e a regra GERADA bate a generica" $?
}

corpus_refs
corpus_docs
corpus_metodo
corpus_compile_all
corpus_pplive
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
corpus_strdump
corpus_text
corpus_dyn
corpus_strfam
corpus_cycle
corpus_deriv
corpus_ppapi
corpus_noeval
corpus_order
corpus_schema

echo
echo "ppcorpus: passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
