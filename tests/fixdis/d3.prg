// módulo 3 da fixture B4f-2 - caso 68, herança múltipla: a ordem da
// cláusula FROM decide (próprio > pais na ordem, em profundidade - fatos
// 1+7). HMBoth FROM HMAlpha, HMBeta: Paint despachado sobre HMBoth
// resolve em HMAlpha. A EXISTÊNCIA de HMBoth no projeto impede o
// excluded-de-promessa de um receptor declarado AS CLASS HMBeta (o valor
// em runtime pode ser um HMBoth, que dispararia HMAlpha:Paint)
#include "hbclass.ch"

CREATE CLASS HMAlpha
   VAR nCnt INIT 0
   METHOD New() CONSTRUCTOR
   METHOD Paint()
ENDCLASS

METHOD New() CLASS HMAlpha
   RETURN Self

METHOD Paint() CLASS HMAlpha
   ::nCnt++
   RETURN Self

CREATE CLASS HMBeta
   VAR nCnt INIT 0
   METHOD New() CONSTRUCTOR
   METHOD Paint()
ENDCLASS

METHOD New() CLASS HMBeta
   RETURN Self

METHOD Paint() CLASS HMBeta
   ::nCnt++
   RETURN Self

CREATE CLASS HMBoth FROM HMAlpha, HMBeta
   METHOD New() CONSTRUCTOR
ENDCLASS

METHOD New() CLASS HMBoth
   RETURN Self

PROCEDURE Usa68()

   LOCAL oB := HMBoth():New()
   LOCAL oPb AS CLASS HMBeta

   oB:Paint()
   oPb := HMBeta():New()
   oPb:Paint()

   RETURN
