PROCEDURE Main()

   LOCAL n

   n := Dobro( Dobro( 2 ) ) + Dobro( 3 )

   ? n

   RETURN

FUNCTION Dobro( nX )

   RETURN nX * 2
