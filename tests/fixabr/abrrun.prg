// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; a afirmacao esta' provada
// por assert que passa PELA diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
// COMPLETUDE(2026-07-15): COMPLETE
//   O loop dos 4 oraculos convergiu: ast-15 (ruletok) diz QUAL literal da regra cada
//   token casou, entao a ferramenta distingue a cabeca ABREVIADA da keyword secundaria
//   por FATO -- nunca replicando o casamento dBase (>= 4 letras). O check
//   COMPLETUDE(fixabr=COMPLETE) em corpus_abbrev le' a AST e afirma isso.
//   (O selo mora aqui, no runner INERTE -- nao no abr.prg compartilhado com o contrato --
//    para nao deslocar os anchors do run.sh; o guarda le os dois .prg da familia.)
//
// Familia ABREVIACAO dBase (P-AUDIT/ast-15, docs/pp-corpus/abbreviation.md), camada B.
// O irmao abr.prg e a guarda corpus_abbrev provam o FATO do dump (qual literal casou);
// ESTE arquivo prova que os dois usos compilam para CODIGO que RODA e VALE.
//
// A regra usa #command (familia SEM 'x') -> casa keyword abreviada a partir de 4 letras:
//   GRAVAR <x> GRAV <y> => zz_( <x>, <y> )   e   APAGAR <x> => zz_( <x>, 0 )
// Por isso APAG (4 letras) casa APAGAR. Os dois sitios expandem para chamadas de verdade;
// o assert le' o valor que a expansao produziu (se eu apagar a linha da DSL, s_nSoma fica
// NIL e o assert FALHA -- a prova consome o que so' existe porque a diretiva expandiu).
//
// COMO RODAR:  hbmk2 abrrun.prg <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbtest.ch"
#include "abr.ch"

STATIC s_nSoma

PROCEDURE Main()
   GRAVAR 10 GRAV 5        // por extenso => zz_( 10, 5 )
   HBTEST s_nSoma IS 15
   APAG 7                  // abreviado (APAG = APAGAR, dBase) => zz_( 7, 0 )
   HBTEST s_nSoma IS 7
   RETURN

STATIC FUNCTION zz_( a, b )
   s_nSoma := a + b
   RETURN s_nSoma
