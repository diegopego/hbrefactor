// módulo 2 da fixture B4f: consumo CROSS-MÓDULO (as tabelas declared de r1
// valem no projeto), classe SEM ctor declarado (camada honesta) e o DSL
// inventado de gizmo.ch declarando pelo canal da linguagem
#include "hbclass.ch"
#include "gizmo.ch"

CREATE CLASS Semctor
   VAR nX INIT 0
   METHOD Zap()
ENDCLASS

METHOD Zap() CLASS Semctor
   ::nX++
   RETURN Self

CONTRAPTION Duplicador MAKER MakeDup

APTITUDE Espelho GIVING Duplicador

PROCEDURE Usa()

   LOCAL x := Caixa():New( 9 )
   LOCAL s := Semctor():New()
   LOCAL w := MakeDup()
   LOCAL t := Misterio()

   x:Soma( 6 )
   s:Zap()
   w:Espelho()
   w:Espelho():Espelho()
   t:Zap()

   RETURN
