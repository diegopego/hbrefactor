#include "hbclass.ch"

PROCEDURE Main()

   LOCAL oConta := Conta():New()

   oConta:nLimite := 500

   ? oConta:nLimite

   RETURN

CREATE CLASS Conta
   VAR nSaldo  INIT 0
   VAR nLimite INIT 0
   METHOD New() CONSTRUCTOR
   METHOD Sobra()
ENDCLASS

METHOD New() CLASS Conta
   RETURN Self

METHOD Sobra() CLASS Conta
   ::nLimite := ::nLimite - ::nSaldo
   RETURN ::nLimite
