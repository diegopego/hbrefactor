#include "log.ch"

MEMVAR nReg

PROCEDURE ComPrivada()

   PRIVATE nReg := 0

   CMD_LOG "e"
   OutStd( hb_ntos( nReg ) )

   RETURN
