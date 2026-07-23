// fixpos (P16 b) - modulo SENSIVEL A POSICAO: expande __LINE__. Um verbo
// que desloca linhas muda o VALOR expandido; o valor novo e' o CERTO (o
// codigo mudou mesmo de linha) - o dever da ferramenta e' AVISAR, jamais
// congelar (docs/pp-corpus/dynval.md). Compila limpo sob -w3 -es2.
//
// O __FILE__ la' embaixo esta' aqui de proposito: as DUAS builtins sao mkind
// `dynval` e as duas chegam com o mesmo `from op:"dynval"` - o que as separa
// e' o EIXO, e o eixo e' o unico acrescimo do ast-18 nesta frente (o `from`
// ja' vinha do ast-17). Sem um sitio de eixo `file` no fonte, o filtro
// `axis == "line"` seria um no-op e a suite passaria sem provar o campo.

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
   ? "arq:", __FILE__

   RETURN
