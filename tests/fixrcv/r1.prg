// módulo 1 da fixture B4f (canal de tipos): classe com CONSTRUCTOR
// declarado - a cadeia Caixa():New() é toda declarada pelo hbclass via
// _HB_CLASS (função-classe) e _HB_MEMBER (retorno do ctor)
#include "hbclass.ch"

CREATE CLASS Caixa
   VAR nTot INIT 0
   METHOD New( nIni ) CONSTRUCTOR
   METHOD Soma( nQtd )
   METHOD Dobra()
ENDCLASS

METHOD New( nIni ) CLASS Caixa
   ::nTot := nIni
   RETURN Self

METHOD Soma( nQtd ) CLASS Caixa
   ::nTot += nQtd
   RETURN Self

METHOD Dobra() CLASS Caixa
   ::Soma( ::nTot )
   RETURN Self

FUNCTION Fabrica()
   RETURN Caixa():New( 0 )

DECLARE Fabrica() AS CLASS Caixa

PROCEDURE Cenarios()

   LOCAL g := Caixa():New( 1 )
   LOCAL a := {}
   LOCAL d AS CLASS Caixa
   LOCAL r := Caixa():New( 3 )
   LOCAL m := Caixa():New( 4 )
   LOCAL f := Fabrica()

   g:Soma( 2 )
   a:Soma( 1 )
   d := Caixa():New( 2 )
   d:Soma( 3 )
   Mexe( @r )
   r:Soma( 4 )
   m:Soma( 5 )
   m := g
   m:Soma( 8 )
   f:Soma( 7 )

   RETURN

PROCEDURE Mexe( xRef )

   ? xRef

   RETURN
