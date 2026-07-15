// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; cada afirmacao esta'
// provada por assert que passa PELA diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
//
// Familia SET - SET EXACT (docs/pp-corpus/set-exact.md). Uma linha do std.ch, dois
// mecanismos do pp: marker RESTRICT no match e result SMART-STRINGIFY.
// Diretiva real, std.ch:121:
//   #command SET EXACT <x:ON,OFF,&> => Set( _SET_EXACT, <(x)> )
//
// AS DUAS CAMADAS (METODO.md § 4):
//   (A) o que a diretiva VIRA -> pp vivo: o smart-quote <(x)> CITA a palavra nua
//       (ON -> "ON") e passa a expressao entre parenteses CRUA ((lFlag) -> lFlag);
//       e o _SET_EXACT vira 1 num 2o passe (#define interno).
//   (B) o que a diretiva VALE -> runtime: Set(_SET_EXACT) le' o flag corrente, e
//       ele SEGUE o que a diretiva mandou -- a STRING "ON" liga, o VALOR de lFlag manda.
//
// std.ch e' AUTO-incluida; NAO incluir explicito (duplicaria os #define -> W0002/-es2).
//
// COMO COMPILAR/RODAR:
//   sintaxe:  harbour setx.prg -n -q0 -w3 -es2 -s -I<core>/contrib/hbtest
//   rodar:    hbmk2  setx.prg  <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbtest.ch"

REQUEST __pp_StdRules

PROCEDURE Main()

   LOCAL lFlag := .T.
   LOCAL pp := __pp_Init()    // regras PADRAO: o SET EXACT (std.ch) ja' esta' aqui

   // ----- camada A: o TEXTO (smart-quote + multi-passe) -----
   // Palavra NUA: o <(x)> smart-stringify CITA ON -> "ON". E o _SET_EXACT (um
   // #define interno) vira 1 num segundo passe -> Set( 1, "ON" ).
   HBTEST AllTrim( __pp_Process( pp, "SET EXACT ON" ) )  IS 'Set( 1, "ON" )'
   HBTEST AllTrim( __pp_Process( pp, "SET EXACT OFF" ) ) IS 'Set( 1, "OFF" )'
   // Entre PARENTESES a mesma posicao passa CRUA: (lFlag) -> lFlag, sem aspas. E'
   // o idioma para passar VARIAVEL onde a palavra nua viraria string.
   HBTEST AllTrim( __pp_Process( pp, "SET EXACT (lFlag)" ) ) IS "Set( 1, lFlag )"

   // ----- camada B: o VALOR (o flag corrente segue a diretiva) -----
   // A STRING "ON" que o smart-quote produziu chega ao Set() e LIGA o exact: o
   // runtime le' .T.. Prova que "ON" nao e' decorativo -- e' o argumento que manda.
   SET EXACT ON
   HBTEST Set( _SET_EXACT ) IS .T.
   SET EXACT OFF
   HBTEST Set( _SET_EXACT ) IS .F.
   // Pela via do parentese, quem manda e' o VALOR de lFlag (.T.), nao a palavra.
   SET EXACT (lFlag)
   HBTEST Set( _SET_EXACT ) IS .T.

   RETURN
