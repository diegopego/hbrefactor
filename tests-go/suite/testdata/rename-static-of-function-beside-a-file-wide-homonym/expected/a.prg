STATIC nTotal := 0

PROCEDURE Main()

   nTotal += 1
   Outra()
   OutStd( hb_ntos( nTotal ) )

   RETURN

STATIC PROCEDURE Outra()

   STATIC nParcial := 100

   nParcial += 5
   OutStd( hb_ntos( nParcial ) )

   RETURN
