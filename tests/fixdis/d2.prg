// módulo 2 da fixture B4f-2 - caso 67, herança simples: UWChild herda
// Paint de UWMain (o dispatch ALCANÇA o pai); UWOver o sobrescreve (o
// dispatch NÃO alcança o pai). Cada classe concreta declara o próprio
// ctor (idioma da B4f: ctor herdado não declara o retorno da filha)
#include "hbclass.ch"

CREATE CLASS UWChild FROM UWMain
   METHOD New() CONSTRUCTOR
ENDCLASS

METHOD New() CLASS UWChild
   RETURN Self

CREATE CLASS UWOver FROM UWMain
   METHOD New() CONSTRUCTOR
   METHOD Paint()
ENDCLASS

METHOD New() CLASS UWOver
   RETURN Self

METHOD Paint() CLASS UWOver
   ::nCnt++
   RETURN Self

PROCEDURE Usa67()

   LOCAL oC := UWChild():New()
   LOCAL oO := UWOver():New()
   LOCAL oD AS CLASS UWChild

   oC:Paint()
   oO:Paint()
   oD := UWChild():New()
   oD:Paint()

   RETURN
