// fixture P (caso 108): valor de marker COLIDINDO com função real homônima
#include "hom.ch"

PROCEDURE Main()
   LABEL Vendas
   ? Vendas()
   RETURN

MAKE Vendas

FUNCTION Vendas()
   RETURN 42

FUNCTION RegLabel( c )
   RETURN c
