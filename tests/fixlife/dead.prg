#include "life.ch"

// a regra morre AQUI - antes de existir uma linha de codigo neste modulo.
// Dali para baixo TRAVA nao captura nada: e um identificador como outro qualquer
#xuncommand TRAVA <x> => Cinta( <x> )

PROCEDURE Morta()

   LOCAL nVal

   nVal := 2
   Cinta( nVal )

   RETURN
