// fixver (fase A.2) - projeto minimo para o ORACULO EXPOSTO (snapshot/verify).
//
// A fixture nao existe para ser refatorada PELA ferramenta: ela existe para ser
// editada POR FORA (como um agente faria) e a ferramenta dizer o que o COMPILADOR
// entendeu que mudou. Os tres vereditos que o caso 123 trava:
//   cosmetica (comentario/linha em branco/reindent) -> PRESERVED (prova)
//   extracao legitima de funcao                     -> CHANGED   (nao e reprovacao)
//   erro de sintaxe                                 -> BROKEN    (+ --rollback)

PROCEDURE Main()

   LOCAL nTotal := Soma( 2, 3 )

   ? nTotal, Dobro( nTotal )

   RETURN

STATIC FUNCTION Soma( nA, nB )
   RETURN nA + nB

STATIC FUNCTION Dobro( nV )
   RETURN nV * 2
