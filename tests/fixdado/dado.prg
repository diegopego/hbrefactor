// fixdado (P16 a) - a ocorrencia em DADO: um bloco de stream contem uma
// palavra igual ao nome de uma LOCAL. O compilador NAO ve simbolo ali (a
// linha crua do bloco vira STRING posicionada - ast-17); a ferramenta
// RELATA a ocorrencia (arquivo:linha) e JAMAIS a edita - nem com opt-in
// (regra §1 do CLAUDE.md). Compila limpo sob -w3 -es2.

PROCEDURE Main()

   LOCAL cSaldo := "1.234,00"

   TEXT
   Relatorio mensal
   cSaldo apurado no periodo
   ENDTEXT

   ? cSaldo, Apoio()

   RETURN
