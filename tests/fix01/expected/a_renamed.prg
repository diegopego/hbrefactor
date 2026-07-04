#include "shared.ch"

PROCEDURE Main()

   LOCAL nSoma := 0
   LOCAL bAcum := {| x | nSoma += x }
   LOCAL i

   FOR i := 1 TO 3
      Eval( bAcum, Dupla( i ) )
   NEXT

   ? "Total:", nSoma   // nTotal no comentario nao deve mudar
   ? "Subtracao:", Sub2( 10, 3 )

   RETURN

FUNCTION LimiteMax()

   LOCAL nMax := K_LIMITE

   RETURN nMax

FUNCTION Sombra()

   LOCAL xVal := 1
   LOCAL bBloco := {| xVal | xVal + 1 }

   RETURN Eval( bBloco, xVal )

FUNCTION Rotulada()

   LOCAL nVisto := 2

   MOSTRA nVisto

   RETURN nVisto
