#include "cmdlog.ch"

MEMVAR nLinhas

PROCEDURE Main()

   PRIVATE nLinhas := 0

   CMD_LOG "iniciando"

   OutStd( hb_ntos( nLinhas ) )

   RETURN
