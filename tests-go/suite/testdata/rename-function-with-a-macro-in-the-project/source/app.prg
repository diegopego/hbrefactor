PROCEDURE Main()

   LOCAL cF := "Dob" + "ro"

   OutStd( hb_ntos( Dobro( 4 ) ) )
   OutStd( hb_ntos( &cF.( 5 ) ) )

   RETURN

FUNCTION Dobro( nX )

   RETURN nX * 2
