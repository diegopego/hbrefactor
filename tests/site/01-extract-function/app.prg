PROCEDURE Main()

   ? Fatura( { 10, 20, 30 }, 10 )

   RETURN

FUNCTION Fatura( aItens, nDesconto )

   LOCAL nTotal
   LOCAL nItem
   LOCAL cLinha

   nTotal := 0
   FOR EACH nItem IN aItens
      nTotal += nItem
   NEXT
   nTotal -= nTotal * nDesconto / 100

   cLinha := "Total: " + hb_ntos( nTotal )

   RETURN cLinha
