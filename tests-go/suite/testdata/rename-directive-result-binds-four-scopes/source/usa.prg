#include "log.ch"

PROCEDURE ComLocal()

   LOCAL nReg := 0

   CMD_LOG "a"
   OutStd( hb_ntos( nReg ) )

   RETURN

PROCEDURE ChamaTudo()

   ComStaticFn()

   RETURN

STATIC PROCEDURE ComStaticFn()

   STATIC nReg := 0

   CMD_LOG "b"
   OutStd( hb_ntos( nReg ) )

   RETURN

PROCEDURE ComParam( nReg )

   CMD_LOG "c"
   OutStd( hb_ntos( nReg ) )

   RETURN

PROCEDURE SoHomonimo()

   LOCAL nReg := 5

   OutStd( hb_ntos( nReg ) )

   RETURN
