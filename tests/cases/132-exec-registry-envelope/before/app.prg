PROCEDURE Main()

   LOCAL nTotal := 0

   nTotal := Ex( nTotal )

   QOut( nTotal )

   RETURN

FUNCTION Dobro( nX )

   RETURN nX * 2

STATIC FUNCTION Ex( nTotal )

   nTotal += Dobro( 2 )

   RETURN nTotal
