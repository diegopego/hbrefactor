#include "cmdlog.ch"

PROCEDURE Main()

   LOCAL nTotalLinhas := 0

   CMD_LOG "iniciando"

   OutStd( hb_ntos( nTotalLinhas ) )

   RETURN
