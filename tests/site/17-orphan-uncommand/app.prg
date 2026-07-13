#include "app.ch"

// This removal switches off NOTHING: the shape <x>, <y> was never registered.
// Harbour accepts it in silence - the directive sits there, dead, looking alive.
#xuncommand CONFERE <x>, <y> => Checa( <x>, <y> )

PROCEDURE Main()

   CONFERE 1

   RETURN

FUNCTION Checa( nVal, nModo )

   RETURN nVal + nModo
