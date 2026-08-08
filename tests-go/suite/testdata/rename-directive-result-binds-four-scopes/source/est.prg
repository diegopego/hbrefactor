#include "log.ch"

STATIC nReg := 0

PROCEDURE ComStaticPrg()

   CMD_LOG "d"
   OutStd( hb_ntos( nReg ) )

   RETURN
