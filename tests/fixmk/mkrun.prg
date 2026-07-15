// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; cada afirmacao esta' provada
// por assert que passa PELA diretiva (pp vivo). (regua: docs/pp-corpus/METODO.md § 4b)
//
// Familia MARKERS (docs/pp-corpus/markers.md), camada A. O irmao mk.prg e a guarda
// corpus_markers provam os mkinds no DUMP (o rotulo de cada marker). ESTE arquivo prova
// o que cada mkind FAZ com o mesmo token, pelo pp VIVO -- e as respostas sao OPOSTAS:
//   regular <x>   COPIA o token  -> QOut( n )            (o nome chega como CODIGO)
//   name    <!x!> CITA o nome    -> QOut( "Fulano" )     (vira DADO, string)
//   wild    <*x*> DESCARTA        -> QOut( "wild" )       (engole o conteudo, some)
//   block   <{x}> EMBRULHA        -> QOut( Eval( {|| n + 1} ) )  (vira codeblock)
// Quem decidiu o destino foi a REGRA (o mkind), nao o texto -- e' por isso que o nome
// escrito nao basta para saber o que ele e'.
//
// NAO incluir mk.ch: registrar a regra no COMPILADOR expandiria a string de entrada
// ANTES de chegar ao __pp_Process (a armadilha do METODO.md § 4). O pp vivo a recebe crua.
//
// COMO RODAR:  hbmk2 mkrun.prg <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbtest.ch"

PROCEDURE Main()

   LOCAL pp := __pp_Init( , "", .F. )   // pp virgem: so' as regras que EU registrar

   __pp_Process( pp, '#xcommand M_REG <x>    => QOut( <x> )' )
   __pp_Process( pp, '#xcommand M_NAM <!x!>  => QOut( <"x"> )' )
   __pp_Process( pp, '#xcommand M_WLD <*x*>  => QOut( "wild" )' )
   __pp_Process( pp, '#xcommand R_BLK <x>    => QOut( Eval( <{x}> ) )' )

   HBTEST AllTrim( __pp_Process( pp, 'M_REG n' ) )      IS "QOut( n )"
   HBTEST AllTrim( __pp_Process( pp, 'M_NAM Fulano' ) ) IS 'QOut( "Fulano" )'
   HBTEST AllTrim( __pp_Process( pp, 'M_WLD a b c' ) )  IS 'QOut( "wild" )'
   HBTEST AllTrim( __pp_Process( pp, 'R_BLK n + 1' ) )  IS "QOut( Eval( {|| n + 1} ) )"

   RETURN
