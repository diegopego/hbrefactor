PROCEDURE Main()

   LOCAL nTotal

   nTotal := 0 + Eval( {| x | nTotal += x }, 1 ) + nTotal

   ? nTotal

   RETURN
