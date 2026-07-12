// fixture do P-AUDIT: recusa FALSA por adivinhacao de texto (ast-15)
#include "abr.ch"

PROCEDURE Main()
   GRAVAR 1 GRAV 2      // uso 100% NAO-abreviado: GRAV e keyword da regra
   APAG 3               // uso REALMENTE abreviado de APAGAR (dBase, >= 4)
   RETURN

FUNCTION zz_( a, b )
   RETURN a + b
