PROCEDURE Main()

   LOCAL nTotal

   nTotal := Soma( 2, 3 )

   // nTotal fecha o caixa do dia
   ? "nTotal = ", nTotal

   RETURN

FUNCTION Soma( nA, nB )

   LOCAL nTotal                 // outra funcao, outro nTotal

   nTotal := nA + nB

   RETURN nTotal
