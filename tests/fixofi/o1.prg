// fixofi m1 (revisão Q1-Q3/Q7): as donas da DSL própria. Banca tem Talha
// (2 params, única no projeto), Verniz (corpo com o Self-análogo QSelf e
// param homônimo do de Talha) e Lustro (homônima com Tear, em o2.prg).
#include "tenda.ch"

TENDA Banca
LAVRA Talha
LAVRA Verniz
LAVRA Lustro
ENDTENDA

OFICIO Talha DA Banca PEDE nLado, nFundo

   LOCAL nMiolo := nLado * 10 - nFundo

   RETURN nMiolo

OFICIO Verniz DA Banca PEDE nLado, nBrilho

   LOCAL cMarca, nTom

   cMarca := __objGetClsName( QSelf() )
   nTom := nLado * 2 + nBrilho

   RETURN cMarca + "/" + hb_ntos( nTom )

OFICIO Lustro DA Banca PEDE nCera, nPano

   RETURN nCera * 100 + nPano
