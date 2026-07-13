#include "hbclass.ch"

PROCEDURE Main()

   LOCAL oPag := Pagamento():New()
   LOCAL oReg := Registro():New()

   oPag:Enviar()
   oReg:Gravar()

   RETURN

CREATE CLASS Pagamento
   METHOD New() CONSTRUCTOR
   METHOD Enviar()
ENDCLASS

METHOD New() CLASS Pagamento
   RETURN Self

METHOD Enviar() CLASS Pagamento
   RETURN "pago"

CREATE CLASS Registro
   METHOD New() CONSTRUCTOR
   METHOD Gravar()
ENDCLASS

METHOD New() CLASS Registro
   RETURN Self

METHOD Gravar() CLASS Registro
   RETURN "gravado"
