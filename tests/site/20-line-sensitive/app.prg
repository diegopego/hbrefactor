PROCEDURE Main()

   LOCAL nTotal := 0
   LOCAL i

   FOR i := 1 TO 3
      nTotal += i * 10
   NEXT

   ? "apurado na linha " + Str( __LINE__ )
   ? "total: " + Str( nTotal )
   ? "modulo " + __FILE__

   RETURN
