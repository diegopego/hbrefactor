#include "hbclass.ch"

PROCEDURE Main()

   LOCAL oConta := Conta():New()

   oConta:nSaldo := 100

   ? oConta:nSaldo

   RETURN

CREATE CLASS Conta
   VAR nSaldo INIT 0
   METHOD New() CONSTRUCTOR
ENDCLASS

METHOD New() CLASS Conta
   RETURN Self

CREATE CLASS Poupanca
   VAR nSaldo INIT 0
   METHOD New() CONSTRUCTOR
ENDCLASS

METHOD New() CLASS Poupanca
   RETURN Self
