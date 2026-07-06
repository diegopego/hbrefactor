// módulo 2: segunda classe (Soma homônimo; Zera único) e o consumidor
#include "hbclass.ch"

CREATE CLASS Outra
   VAR nX INIT 0
   METHOD Soma( nQtd )
   METHOD Zera()
ENDCLASS

METHOD Soma( nQtd ) CLASS Outra

   ::nX := ::nX + nQtd + 1

   RETURN Self

METHOD Zera() CLASS Outra

   ::nX := 0

   RETURN Self

PROCEDURE Main()

   LOCAL oC := Caixa():New()
   LOCAL oO := Outra():New()
   LOCAL cTag := "Dobro"

   oC:Soma( 5 )
   oC:Info()
   oO:Soma( 2 )
   oO:Zera()
   ? "tag:", cTag
   IF .F.
      oC:Fantasma()
   ENDIF

   RETURN
