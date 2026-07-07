// módulo 1 da fixture B4f-2 (resolução de dispatch) - caso 66, o caso do
// Diego: duas classes com métodos HOMÔNIMOS (Add/Paint). Com ctor
// declarado o receptor é instância EXATA e o dispatch decide; o par NC*
// (sem ctor) documenta o idioma: sem declaração, ambos os sends ficam
// possible. O receptor DECLARADO (promessa) só exclui no mundo fechado
// do grafo do projeto (UWSecondary não tem descendente no projeto)
#include "hbclass.ch"

CREATE CLASS UWMain
   VAR nCnt INIT 0
   METHOD New() CONSTRUCTOR
   METHOD Add( oW )
   METHOD Paint()
ENDCLASS

METHOD New() CLASS UWMain
   RETURN Self

METHOD Add( oW ) CLASS UWMain
   ? oW
   RETURN Self

METHOD Paint() CLASS UWMain
   ::nCnt++
   RETURN Self

CREATE CLASS UWSecondary
   VAR nCnt INIT 0
   METHOD New() CONSTRUCTOR
   METHOD Add( oW )
   METHOD Paint()
ENDCLASS

METHOD New() CLASS UWSecondary
   RETURN Self

METHOD Add( oW ) CLASS UWSecondary
   ? oW
   RETURN Self

METHOD Paint() CLASS UWSecondary
   ::nCnt++
   RETURN Self

CREATE CLASS NCMain
   VAR nCnt INIT 0
   METHOD Paint()
ENDCLASS

METHOD Paint() CLASS NCMain
   ::nCnt++
   RETURN Self

CREATE CLASS NCSecondary
   VAR nCnt INIT 0
   METHOD Paint()
ENDCLASS

METHOD Paint() CLASS NCSecondary
   ::nCnt++
   RETURN Self

PROCEDURE Usa66()

   LOCAL oM := UWMain():New()
   LOCAL oS := UWSecondary():New()

   oM:Paint()
   oS:Paint()

   RETURN

PROCEDURE Usa66Prom()

   LOCAL oP AS CLASS UWSecondary

   oP := UWSecondary():New()
   oP:Paint()

   RETURN

PROCEDURE Usa66Nc()

   LOCAL oNm := NCMain():New()
   LOCAL oNs := NCSecondary():New()

   oNm:Paint()
   oNs:Paint()

   RETURN
