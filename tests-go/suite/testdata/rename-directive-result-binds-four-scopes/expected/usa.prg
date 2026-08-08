#include "log.ch"

PROCEDURE ComLocal()

   LOCAL nNovo := 0

   CMD_LOG "a"
   OutStd( hb_ntos( nNovo ) )

   RETURN

PROCEDURE ChamaTudo()

   ComStaticFn()

   RETURN

STATIC PROCEDURE ComStaticFn()

   STATIC nNovo := 0

   CMD_LOG "b"
   OutStd( hb_ntos( nNovo ) )

   RETURN

PROCEDURE ComParam( nNovo )

   CMD_LOG "c"
   OutStd( hb_ntos( nNovo ) )

   RETURN

PROCEDURE SoHomonimo()

   LOCAL nReg := 5

   OutStd( hb_ntos( nReg ) )

   RETURN
