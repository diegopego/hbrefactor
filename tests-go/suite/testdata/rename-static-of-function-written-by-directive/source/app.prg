#include "cmdlog.ch"

PROCEDURE Main()

   STATIC nLinhas := 0

   CMD_LOG "iniciando"

   OutStd( hb_ntos( nLinhas ) )
   Outra()

   RETURN

STATIC PROCEDURE Outra()

   LOCAL nLinhas := 9

   OutStd( hb_ntos( nLinhas ) )

   RETURN
