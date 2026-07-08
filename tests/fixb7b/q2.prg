// fixture B7b - modulo da DSL nao-espelho (portao de generalidade do
// alvo 2): o bloco INLINE da Fornalha ganha o mesmo fato do INLINE do
// hbclass - 1o parametro = receptor (fato do VM, classes.c:4554); 2o
// parametro NAO tipa (nao ha fato de dispatch para ele).
#include "forno.ch"

FORNO Fornalha
TACHO mexe DE frn_mexe
BRASA quente COM {| tigela | tigela:mexe( 2 ) }
BRASA morna COM {| tigela, oExtra | oExtra:mexe( tigela ) }
ENDFORNO

STATIC FUNCTION frn_mexe( n )
   RETURN n * 3

PROCEDURE Aquece()

   LOCAL oFor := Fornalha()

   OutStd( hb_ntos( oFor:quente() ) + hb_eol() )

   RETURN
