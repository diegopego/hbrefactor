#include "cmdlog.ch"

PROCEDURE Main()

   LOCAL nTotal := 0

   CMD_LOG "iniciando"

   OutStd( hb_ntos( nTotal ) )
   Outra()

   RETURN

STATIC PROCEDURE Outra()

   LOCAL nLinhas := 9

   OutStd( hb_ntos( nLinhas ) )

   RETURN
