#include "hbclass.ch"

CREATE CLASS Conta
   METHOD New() CONSTRUCTOR
   METHOD Saldo()
ENDCLASS

METHOD New() CLASS Conta
   RETURN Self

METHOD Saldo() CLASS Conta
   RETURN 100

PROCEDURE Main()

   LOCAL oConta := Conta():New()

   ? oConta:Saldo()

   RETURN
