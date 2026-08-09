MEMVAR xCfg

PROCEDURE Usa()

   OutStd( "antes:", hb_ntos( xCfg ), " " )

   PRIVATE xCfg := 9

   OutStd( "depois:", hb_ntos( xCfg ), " " )

   RETURN
