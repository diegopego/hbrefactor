// Fixture da familia DEFINE DINAMICO (docs/pp-corpus/dynval.md). Compila limpo
// sob -w3 -es2. Diretiva REAL: as regras BUILTIN do pp (__FILE__ e __LINE__ --
// as unicas duas do mkind `dynval`, ppcore.c:7253-7254).
//
// O assunto e' a SENSIBILIDADE A POSICAO: o `__LINE__` expande para a linha
// CORRENTE, entao qualquer edicao que DESLOQUE linhas muda o valor que o
// programa ve. Nao e' corrupcao (o statement de fato mudou de linha) -- mas e'
// mudanca de pcode, e nenhum verbo que desloque linhas pode alegar identidade
// de pcode num modulo assim.

PROCEDURE Main()

   LOCAL nQuando := __LINE__
   LOCAL cOnde   := __FILE__

   ? nQuando, cOnde

   Registra()

   RETURN

STATIC PROCEDURE Registra()

   ? "log:", __LINE__

   RETURN
