// fixpos (P16 b) - modulo SENSIVEL A POSICAO: expande __LINE__. Um verbo
// que desloca linhas muda o VALOR expandido; o valor novo e' o CERTO (o
// codigo mudou mesmo de linha) - o dever da ferramenta e' AVISAR, jamais
// congelar (docs/pp-corpus/dynval.md). Compila limpo sob -w3 -es2.

PROCEDURE Main()

   LOCAL nTotal := 0
   LOCAL bAcum := {| x | nTotal += x }
   LOCAL nPasso := 4
   LOCAL i

   ? "ini:", __LINE__

   FOR i := 1 TO 3
      Eval( bAcum, Triplica( i ) )
   NEXT

   ? "total:", nTotal, nPasso
   ? "log:", __LINE__

   RETURN
