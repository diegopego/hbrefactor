#include "hbclass.ch"

CREATE CLASS Caixa
   VAR nTot INIT 7
   METHOD Exibe()
ENDCLASS

METHOD Exibe() CLASS Caixa

   OutStd( hb_ntos( ::nTot ) )

   RETURN Self

PROCEDURE Main()

   LOCAL oC := Caixa():New()
   LOCAL cM := "Mos" + "tra"

   OutStd( "Mostra" + ": " )

   __objSendMsg( oC, cM )

   RETURN
