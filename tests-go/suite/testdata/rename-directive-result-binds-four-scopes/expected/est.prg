#include "log.ch"

STATIC nNovo := 0

PROCEDURE ComStaticPrg()

   CMD_LOG "d"
   OutStd( hb_ntos( nNovo ) )

   RETURN
