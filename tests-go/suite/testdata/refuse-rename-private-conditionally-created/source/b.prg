MEMVAR xCfg

PROCEDURE Usa( lFlag )

   IF lFlag
      PRIVATE xCfg := 9
   ENDIF

   OutStd( hb_ntos( xCfg ) )

   RETURN
