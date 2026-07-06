// módulo 1 da fixture B4d (fixppm): DEFINIÇÕES via a DSL inventada de
// ppm.ch (G6) - handlers, registros e a colagem de dois nomes
#include "ppm.ch"

REGISTRO Salva
REGISTRO Envia

HANDLER Click

LIGA Motor COM Roda

FUNCTION Freio_Roda()
   RETURN "freio"

FUNCTION Anota( cTag )
   RETURN "[" + cTag + "]"

PARAMFN Dobra( nX )
