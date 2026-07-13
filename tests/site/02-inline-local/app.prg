PROCEDURE Main()

   ? Frete( 250 )

   RETURN

FUNCTION Frete( nPeso )

   LOCAL nTaxa := 1.75

   IF nPeso > 100
      RETURN nPeso * nTaxa * 2
   ENDIF

   RETURN nPeso * nTaxa
