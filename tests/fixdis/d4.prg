// módulo 4 da fixture B4f-2 - caso 69, pai FORA do projeto na cadeia
// (TBrowse, do core): pai de fora ANTES de um hit do projeto torna a
// resolução INDECIDÍVEL (possible honesto, nunca excluded); hit do
// projeto ANTES do pai de fora É decidível (fato 9 - o de fora nem é
// consultado, primeiro hit vence)
#include "hbclass.ch"

CREATE CLASS OPBase
   VAR nCnt INIT 0
   METHOD New() CONSTRUCTOR
   METHOD Paint()
ENDCLASS

METHOD New() CLASS OPBase
   RETURN Self

METHOD Paint() CLASS OPBase
   ::nCnt++
   RETURN Self

CREATE CLASS OPFirst FROM TBrowse, OPBase
   METHOD New() CONSTRUCTOR
ENDCLASS

METHOD New() CLASS OPFirst
   RETURN Self

CREATE CLASS OPLast FROM OPBase, TBrowse
   METHOD New() CONSTRUCTOR
ENDCLASS

METHOD New() CLASS OPLast
   RETURN Self

PROCEDURE Usa69()

   LOCAL oF := OPFirst():New()
   LOCAL oL := OPLast():New()

   oF:Paint()
   oL:Paint()

   RETURN
