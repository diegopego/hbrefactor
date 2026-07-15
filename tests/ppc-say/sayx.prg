// COMPLETUDE(2026-07-15): COMPLETE
//   O loop dos 4 oraculos convergiu: a AST carrega os grupos OPCIONAIS como roles
//   opt-open/opt-close, e os simbolos que o usuario escreve (nX, cName) chegam
//   posicionados. A selecao de forma (DevOut x DevOutPict) e' derivavel do que casou.
//   O check COMPLETUDE(ppc-say=COMPLETE) em corpus_say le' a AST e afirma essa cobertura.
// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; cada afirmacao esta'
// provada por assert que passa PELA diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
//
// Familia @ ... SAY (docs/pp-corpus/say.md) - o SAY posicionado do Clipper.
// Diretiva real, std.ch:249 (DUAS regras, uma com PICTURE, outra sem):
//   #command @ <row>, <col> SAY <exp> [PICTURE <pic>] [COLOR <clr>] =>
//            DevPos( <row>, <col> ) ; DevOutPict( <exp>, <pic> [, <clr>] )
//   #command @ <row>, <col> SAY <exp> [COLOR <clr>] =>
//            DevPos( <row>, <col> ) ; DevOut( <exp> [, <clr>] )
//
// POR QUE SO' A CAMADA A (o TEXTO): o @ SAY nao devolve VALOR -- ele escreve no
// DISPOSITIVO (DevPos/DevOut/DevOutPict). Sob o GT de teste (gtcgi) nao ha' buffer
// de tela legivel (SaveScreen volta vazio), entao nao ha' camada B honesta: o
// "valor" do @ SAY e' saida, nao retorno. O que a familia ENSINA -- SELECAO DE
// FORMA e GRUPOS OPCIONAIS -- e' fato de EXPANSAO, e a camada A o prova RODANDO
// (__pp_Process). (METODO.md § 4: as duas camadas "onde couber"; aqui nao cabe.)
//
// COMO COMPILAR/RODAR:
//   sintaxe:  harbour sayx.prg -n -q0 -w3 -es2 -s -I<core>/contrib/hbtest
//   rodar:    hbmk2  sayx.prg  <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbtest.ch"

REQUEST __pp_StdRules

PROCEDURE Main()

   LOCAL pp := __pp_Init()    // regras PADRAO: o @ SAY (std.ch) ja' esta' aqui

   // Nenhum opcional casou -> a 2a regra (sem PICTURE) vence -> DevOut, um arg so'.
   HBTEST AllTrim( __pp_Process( pp, '@ 1, 1 SAY "Ola"' ) ) ;
      IS 'DevPos( 1, 1 ) ; DevOut( "Ola" )'
   // PICTURE casou -> a 1a regra vence -> DevOutPict. E' o PICTURE que SELECIONA a
   // forma: a presenca de um grupo opcional escolhe qual das duas regras aplica.
   HBTEST AllTrim( __pp_Process( pp, '@ 2, 1 SAY nX PICTURE "999"' ) ) ;
      IS 'DevPos( 2, 1 ) ; DevOutPict( nX, "999" )'
   // PICTURE e COLOR casaram -> DevOutPict com o 3o arg. O grupo opcional do RESULT
   // ([, <clr>]) so' emite a cor porque COLOR casou no match.
   HBTEST AllTrim( __pp_Process( pp, '@ 3, 1 SAY nX PICTURE "999" COLOR "R/W"' ) ) ;
      IS 'DevPos( 3, 1 ) ; DevOutPict( nX, "999", "R/W" )'
   // COLOR sem PICTURE -> a 1a regra NAO casa (falta o PICTURE que ela nao exige,
   // mas a ordem/forma leva a 2a) -> DevOut com a cor. Prova que sao DUAS regras
   // distintas, e o pp escolhe pela combinacao de opcionais presente.
   HBTEST AllTrim( __pp_Process( pp, '@ 4, 1 SAY cName COLOR "W/B"' ) ) ;
      IS 'DevPos( 4, 1 ) ; DevOut( cName, "W/B" )'

   RETURN
