MEMVAR xCfg

PROCEDURE Main()

   PRIVATE xCfg := 7

   Show()

   RETURN

STATIC PROCEDURE Show()

   OutStd( hb_ntos( __mvGet( "xC" + "fg" ) ) )

   RETURN
