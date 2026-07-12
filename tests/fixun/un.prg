#include "un.ch"

PROCEDURE Main()
   LACRA 1
   RETURN

// a partir daqui a diretiva esta DESLIGADA
#xuncommand LACRA <x> => uu_( <x>, 1 )

FUNCTION uu_( a, b )
   RETURN a + b
