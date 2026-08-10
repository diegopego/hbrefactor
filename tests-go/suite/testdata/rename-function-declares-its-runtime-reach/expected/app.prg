PROCEDURE Main()

   LOCAL cF := "Dob" + "ro"

   OutStd( hb_ntos( Duplica( 4 ) ) )
   OutStd( hb_ntos( &cF.( 5 ) ) )

   RETURN

FUNCTION Duplica( nX )

   RETURN nX * 2
