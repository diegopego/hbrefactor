// módulo 1 da fixture de métodos (B4c): classe com VAR, INLINE e métodos
#include "hbclass.ch"

CREATE CLASS Caixa
   VAR nTot INIT 0
   METHOD Soma( nQtd )
   METHOD Dobro() INLINE ::nTot * 2
   METHOD Info()
ENDCLASS

METHOD Soma( nQtd ) CLASS Caixa

   ::nTot := ::nTot + nQtd

   RETURN Self

METHOD Info() CLASS Caixa

   ? "tot:", ::nTot, ::Dobro()

   RETURN Self
