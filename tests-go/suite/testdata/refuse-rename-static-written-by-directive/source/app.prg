#include "cmdlog.ch"

STATIC nLinhas := 0

PROCEDURE Main()

   CMD_LOG "iniciando"

   OutStd( hb_ntos( nLinhas ) )

   RETURN
