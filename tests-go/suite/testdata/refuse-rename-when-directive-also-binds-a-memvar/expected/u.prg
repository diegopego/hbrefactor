#include "log.ch"

PROCEDURE ComLocal()

   LOCAL nReg := 0

   CMD_LOG "a"
   OutStd( hb_ntos( nReg ) )

   RETURN

