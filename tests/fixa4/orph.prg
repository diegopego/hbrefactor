#include "orph.ch"

// Esta remocao nao desliga NADA: a forma <x>, <y> nunca foi registrada.
// O Harbour aceita calado - e a diretiva fica ali, morta, parecendo viva.
#xuncommand FUNDEIA <x>, <y> => aq_( <x>, <y> )

PROCEDURE Main()

   FUNDEIA 1

   RETURN

FUNCTION aq_( a, b )
   RETURN a + b
