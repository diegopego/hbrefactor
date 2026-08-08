#include "cmdlog.ch"

PROCEDURE Main()

   STATIC nLinhas := 0

   CMD_LOG "iniciando"
   OutStd( hb_ntos( nLinhas ) )
   Outra()

   RETURN

STATIC PROCEDURE Outra()

   STATIC nLinhas := 0

   CMD_LOG "seguindo"
   OutStd( hb_ntos( nLinhas ) )

   RETURN
