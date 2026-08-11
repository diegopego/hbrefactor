// despacho de mensagem e' OOP normal, nao inadequacao: a ferramenta lida com
// send desde sempre, e 41% dos modulos do core tem um
#include "hbclass.ch"

CREATE CLASS Caixa
   VAR nTot INIT 0
   METHOD Soma( nQtd )
ENDCLASS

METHOD Soma( nQtd ) CLASS Caixa

   ::nTot += nQtd

   RETURN Self

PROCEDURE UsaClasse()

   LOCAL oC := Caixa():New()

   oC:Soma( 5 )
   OutStd( hb_ntos( oC:nTot ) )

   RETURN
