#include "cmdlog.ch"

STATIC nTotal := 0

PROCEDURE Main()

   CMD_LOG "iniciando"

   OutStd( hb_ntos( nTotal ) )

   RETURN
