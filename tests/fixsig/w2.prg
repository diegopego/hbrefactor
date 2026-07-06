// fixsig módulo 2: classe com método homônimo (Resize nas duas classes) e o
// consumidor - Resize é despacho dinâmico ambíguo (recusa em P1b), Grow único
#include "hbclass.ch"

CREATE CLASS Panel
   VAR cTag INIT ""
   METHOD Resize( nW, nH )
ENDCLASS

METHOD Resize( nW, nH ) CLASS Panel

   ::cTag := "P" + hb_ntos( nW * nH )

   RETURN Self

PROCEDURE Main()

   LOCAL oW := Widget():New()
   LOCAL oP := Panel():New()

   oW:Resize( 10, 20 )
   oW:Grow( 1, 2 )
   oP:Resize( 3, 4 )
   ? oW:cTag, oP:cTag

   RETURN
