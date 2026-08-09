MEMVAR xCfg

PROCEDURE UsaUm()

   OutStd( hb_ntos( xCfg ) )

   RETURN

PROCEDURE ProcB()

   PRIVATE xCfg := 9

   OutStd( hb_ntos( xCfg ) )

   RETURN
