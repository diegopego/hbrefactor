// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; a afirmacao esta' provada
// por assert que passa PELA diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
// COMPLETUDE(2026-07-15): COMPLETE
//   O loop dos 4 oraculos convergiu: os canais -u/-gd sao o INSTRUMENTO da migracao
//   (D-P5), mas o RESULTADO que a ferramenta consome esta' na AST. O far_Migrado
//   gerado chega com a mesma proveniencia de derivacao da familia deriv: #<n>
//   estringifica o NOME ("Alfa", dado) e <v> clona o token (nX, simbolo POSICIONADO,
//   o alvo de rename). O -gd (include resolvido) e' canal proprio do core, nao fato de
//   AST. O check COMPLETUDE(ppc-instr=COMPLETE) em corpus_instrument le' a AST.
//
// Familia PP COMO INSTRUMENTO (docs/pp-corpus/pp-as-instrument.md), camada B.
// O irmao m.prg mostra os CANAIS do core (.ppo/-u/-gd) e o que cada um DESTROI --
// facts de canal, sem valor em runtime. ESTE arquivo prova a outra metade: a
// migracao NAO e' so' texto, ela compila para CODIGO que RODA e VALE.
//
// A regra ANTIGO (far.ch) migra em DOIS passes:
//   ANTIGO Alfa COM nX  =>  MODERNO Alfa VALOR nX  =>  far_Migrado( #<n>, <v> )
// e os dois markers do result fazem coisas OPOSTAS com o mesmo tipo de token:
//   #<n>  CITA o nome  -> far_Migrado recebe a STRING "Alfa" (nao existe variavel Alfa)
//   <v>   COPIA o token -> far_Migrado recebe o VALOR de nX (o compilador le' como local)
// Por isso o assert vale "Alfa1": "Alfa" (citado) + hb_ntos( 1 ) (o valor de nX).
//
// COMO RODAR:  hbmk2 instr.prg <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbtest.ch"
#include "far.ch"

STATIC s_cGravou

PROCEDURE Main()
   LOCAL nX := 1
   ANTIGO Alfa COM nX             // expande (2 passes) para far_Migrado( "Alfa", nX )
   // se eu apagar a linha acima, s_cGravou fica NIL e o assert FALHA: a prova
   // consome o que SO' existe porque a diretiva expandiu (METODO.md § 4b)
   HBTEST s_cGravou IS "Alfa1"
   RETURN

STATIC FUNCTION far_Migrado( cNome, xValor )
   s_cGravou := cNome + hb_ntos( xValor )
   RETURN s_cGravou
