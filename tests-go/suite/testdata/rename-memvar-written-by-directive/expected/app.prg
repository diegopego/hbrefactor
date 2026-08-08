#include "cmdlog.ch"

MEMVAR nTotal

PROCEDURE Main()

   PRIVATE nTotal := 0

   CMD_LOG "iniciando"

   OutStd( hb_ntos( nTotal ) )

   RETURN
