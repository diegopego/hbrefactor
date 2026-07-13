// Fixture do salto estrutural: EXIT dentro de SWITCH termina o SWITCH (e o
// fim do case), NAO um laco - logo extrair um bloco que contem o SWITCH
// INTEIRO e seguro. O compilador exporta o bloco 'switch' em blocks[]; a
// ferramenta so olhava for/while e dava RECUSA FALSA.
// LOOP, ao contrario, continua o laco EXTERNO: dentro de um SWITCH ele
// atravessa a borda e a recusa e VERDADEIRA.

PROCEDURE Main()

   ? Tipo( "a.css" )
   ? Conta( { "css", "htm" } )
   RETURN

// EXIT coberto pelo proprio SWITCH: extrair 'nI ... ENDSWITCH' deve PASSAR
// (cTipo e escrito aqui e lido depois -> vira o RETURN)
FUNCTION Tipo( cNome )

   LOCAL cTipo
   LOCAL nI

   nI := RAt( ".", cNome )
   SWITCH Lower( SubStr( cNome, nI + 1 ) )
   CASE "css"
      cTipo := "text/css"
      EXIT
   CASE "htm"
      cTipo := "text/html"
      EXIT
   OTHERWISE
      cTipo := "application/octet-stream"
   ENDSWITCH

   RETURN cTipo

// LOOP dentro de SWITCH: o salto e do FOR EACH, que fica FORA da selecao -
// extrair so o SWITCH tem de RECUSAR
FUNCTION Conta( aExt )

   LOCAL nTot
   LOCAL cE

   nTot := 0
   FOR EACH cE IN aExt
      SWITCH cE
      CASE "css"
         nTot += 1
         LOOP
      ENDSWITCH
      nTot += 10
   NEXT

   RETURN nTot
