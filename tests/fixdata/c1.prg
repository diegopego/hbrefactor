// fixdata (rename-DATA, spec-rename-data): Conta e Poupanca compartilham o
// DATA member nSaldo (homonimo -> rename recusa por unicidade); nLimite e
// UNICO de Conta (rename sucede, inclusive nos usos externos por local nao
// tipado - a mensagem e global, guardada pela unicidade).
#include "hbclass.ch"

PROCEDURE Main()
   LOCAL oC := Conta():New()
   oC:nSaldo := 100
   oC:nLimite := 500
   ? oC:nSaldo, oC:nLimite
   RETURN

CREATE CLASS Conta
   VAR nSaldo INIT 0
   VAR nLimite INIT 0
   METHOD New()
ENDCLASS

METHOD New() CLASS Conta
   RETURN Self
