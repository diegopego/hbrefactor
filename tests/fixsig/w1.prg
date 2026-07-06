// fixsig (B4e): classe com método de 2+ params - a assinatura (protótipo no
// CREATE CLASS e o METHOD ... CLASS) tem que mover junto com os usos do corpo
#include "hbclass.ch"

CREATE CLASS Widget
   VAR cTag INIT ""
   METHOD Resize( nW, nH )
   METHOD Grow( nDx, nDy )
ENDCLASS

METHOD Resize( nW, nH ) CLASS Widget

   ::cTag := "R" + hb_ntos( nW ) + "x" + hb_ntos( nH )

   RETURN Self

METHOD Grow( nDx, nDy ) CLASS Widget

   ::cTag := "G" + hb_ntos( nDx + nDy )

   RETURN Self
