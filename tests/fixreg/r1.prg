// fixture B9 fatia 4 - modulo principal: consome os metais registrados em
// runtime pela DSL da forja (nomes computados - a estatica nao alcanca)
#include "forja.ch"

PROCEDURE Main()

   LOCAL nBronze := Forja_Bronze()
   LOCAL nAco := Forja_Aco()

   OutStd( __className( nBronze ) + " " + __className( nAco ) + hb_eol() )

   RETURN

FORJA METAL Bronze TEMPERA "funde", "verga"
