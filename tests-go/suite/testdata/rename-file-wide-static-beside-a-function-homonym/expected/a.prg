STATIC nGeral := 0

PROCEDURE Main()

   nGeral += 1
   Outra()
   OutStd( hb_ntos( nGeral ) )

   RETURN

STATIC PROCEDURE Outra()

   STATIC nTotal := 100

   nTotal += 5
   OutStd( hb_ntos( nTotal ) )

   RETURN
