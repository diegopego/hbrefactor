#include "app.ch"

PROCEDURE Main()

   LACRA 1

   RETURN

// from here on the directive is switched OFF
#xuncommand LACRA <x> => Selar( <x>, 1 )

FUNCTION Selar( nVal, nSelo )

   RETURN nVal + nSelo
