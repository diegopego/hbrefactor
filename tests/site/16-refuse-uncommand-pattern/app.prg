#include "app.ch"

// VERIFICA is switched off here, before a single line of code in this module
#xuncommand VERIFICA <x> => Checa( <x>, 2 )

PROCEDURE Main()

   CONFERE 1

   RETURN

FUNCTION Checa( nVal, nModo )

   RETURN nVal + nModo
