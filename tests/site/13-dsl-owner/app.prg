#include "app.ch"

PROCEDURE Main()

   ROTULO Vendas   // a label your DSL turns into a string
   ? Vendas()      // the real function - same spelling, a different owner

   RETURN

GERA Vendas        // the word becomes part of a generated function name

FUNCTION Vendas()

   RETURN 42

FUNCTION RegRotulo( cNome )

   RETURN cNome
