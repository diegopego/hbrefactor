// módulo 1 da fixture de classes (B4): a DSL complexa do hbclass.ch
#include "hbclass.ch"

CREATE CLASS UWMenu
   VAR nW INIT 0
   VAR nH INIT 0
   METHOD Paint()
   METHOD Resize( nW, nH )
ENDCLASS

METHOD Paint() CLASS UWMenu

   ? "paint", ::nW

   RETURN Self

METHOD Resize( nW, nH ) CLASS UWMenu

   ::nW := nW
   ::nH := nH

   RETURN Self
