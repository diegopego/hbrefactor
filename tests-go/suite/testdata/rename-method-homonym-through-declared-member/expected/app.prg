// Two classes answer the same message and hold a VAR under the same name.
// A third class keeps one instance of each; the CONTENT type of those two
// members is declared AFTER the ENDCLASS, so a send through the member
// chain is placed by the compiler instead of guessed.
#include "hbclass.ch"

CREATE CLASS Trilho
   VAR cRotulo
   METHOD New() CONSTRUCTOR
   METHOD Exibe()
ENDCLASS

METHOD New() CLASS Trilho
   ::cRotulo := "trilho"
   RETURN Self

METHOD Exibe() CLASS Trilho
   OutStd( ::cRotulo )
   RETURN Self

CREATE CLASS Vagao
   VAR cRotulo
   METHOD New() CONSTRUCTOR
   METHOD Mostra()
ENDCLASS

METHOD New() CLASS Vagao
   ::cRotulo := "vagao"
   RETURN Self

METHOD Mostra() CLASS Vagao
   OutStd( ::cRotulo )
   RETURN Self

CREATE CLASS Composicao
   VAR oPrincipal
   VAR oReserva
   METHOD New() CONSTRUCTOR
ENDCLASS

_HB_MEMBER oPrincipal() AS CLASS Trilho
_HB_MEMBER oReserva() AS CLASS Vagao

METHOD New() CLASS Composicao
   ::oPrincipal := Trilho():New()
   ::oReserva   := Vagao():New()
   RETURN Self

PROCEDURE Main()

   LOCAL oCli := Composicao():New()

   oCli:oPrincipal:Exibe()
   oCli:oReserva:Mostra()

   RETURN
