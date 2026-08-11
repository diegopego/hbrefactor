#include "hbclass.ch"

PROCEDURE Main()

   LOCAL oConta := Conta():New()

   oConta:nSaldo := 100

   ? oConta:nSaldo

   RETURN

CREATE CLASS Conta
   VAR nSaldo INIT 0
ENDCLASS

CREATE CLASS Poupanca
   VAR nSaldo INIT 0
ENDCLASS
