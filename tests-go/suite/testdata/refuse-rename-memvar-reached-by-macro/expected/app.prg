MEMVAR xCfg

PROCEDURE Main()

   PRIVATE xCfg := 7

   Show()

   RETURN

STATIC PROCEDURE Show()

   LOCAL cF := "Dob" + "ro"

   OutStd( hb_ntos( &cF.() ) )

   RETURN

FUNCTION Dobro()

   RETURN xCfg * 2
