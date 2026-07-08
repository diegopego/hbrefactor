// forja.ch - B4g: a regra por dentro (match[]/result[] do ast-5).
// Nasceu como probe do portão (2026-07-07) e foi promovida a fixture:
// cobre todos os tipos de marker do match, os de string do result,
// diretiva continuada, opcionais consecutivos reordenados e restrição.

#define LARGURA_PADRAO 42
#define DOBRO( x ) ( ( x ) * 2 )

// P3: continuada em 3 linhas fisicas; P4: opcional no match e no result;
// restricao <modo: ...> cujo valor VAZA (stringify) - rename da alternativa
// muda a expansao e recusa; keyword secundaria TAMANHO; <"">/<()>
#xcommand FORJA <oIt> TAMANHO <nTam> ;
      [ ROTULO <cRot> ] ;
      MODO <modo: RAPIDO, LENTO> => ;
   <oIt> := ForjaNova( <nTam>, <"modo"> ) [ ; ForjaRotulo( <oIt>, <(cRot)> ) ]

// opcionais consecutivos: o primeiro sem keyword - o pp REORDENA no
// registro (ppcore.c hb_pp_matchPatternNew) e match[] reflete a ordem
// ARMAZENADA (fato 12 da spec-b4g)
#xcommand TEMPERA [<n>] [GRAU <g>] => ForjaTempera( <n>, <g> )

// marker de lista
#xcommand LOTE <itens,...> => ForjaLote( { <itens> } )

// wild no match + strdump # no result
#xcommand ANOTA <*resto*> => ForjaNota( #<resto> )

// name marker <!x!> + extexp <(x)> no match
#xcommand BATIZA <!nome!> COM <(vExp)> => ForjaBatiza( <"nome">, <vExp> )

// restricao que NAO vaza (marker so de despacho, fora do result):
// rename da alternativa preserva a expansao byte a byte
#xcommand RECOZE MODO <m: FRIO, QUENTE> => ForjaLiga( 1 )

// familia translate (substitui no meio da statement)
#xtranslate MEIA <x> => ( <x> / 2 )

// opcional ANINHADO no match (criterio 2 da spec-b4g): o walker recursa
#xcommand PRENSA <p> [ COM <f> [ EM <t> ] ] => ForjaPrensa( <p>, <f>, <t> )
