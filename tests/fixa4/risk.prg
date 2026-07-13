#include "risk.ch"

// VELACHO morre AQUI, antes de existir uma linha de codigo neste modulo
#xuncommand VELACHO <x> => aq_( <x>, 2 )

PROCEDURE Main()

   ? aq_( 1, 1 )
   FUNDEIA 1

   RETURN

FUNCTION aq_( a, b )
   RETURN a + b
