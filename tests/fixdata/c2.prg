#include "hbclass.ch"

CREATE CLASS Poupanca
   VAR nSaldo INIT 0
   METHOD New()
ENDCLASS

METHOD New() CLASS Poupanca
   RETURN Self
