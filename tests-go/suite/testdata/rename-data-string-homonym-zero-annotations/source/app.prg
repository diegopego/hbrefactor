// Two classes hold a member of the same name and answer a message of the same
// name. Not one line of this project is annotated: the receiver of every send
// is proven by a channel the class itself already declares - the CONSTRUCTOR's
// return type for the locals in Main, and Self inside each method body.
#include "hbclass.ch"

CREATE CLASS Lantern
   VAR cInscription INIT "north wall"
   METHOD New() CONSTRUCTOR
   METHOD Engrave()
ENDCLASS

METHOD New() CLASS Lantern
   RETURN Self

METHOD Engrave() CLASS Lantern
   OutStd( Self:cInscription )
   RETURN Self

CREATE CLASS Compass
   VAR cInscription INIT "true north"
   METHOD New() CONSTRUCTOR
   METHOD Engrave()
ENDCLASS

METHOD New() CLASS Compass
   RETURN Self

METHOD Engrave() CLASS Compass
   OutStd( ::cInscription )
   RETURN Self

PROCEDURE Main()

   LOCAL oLantern := Lantern():New()
   LOCAL oCompass := Compass():New()

   oLantern:cInscription := "east wall"
   oCompass:cInscription := "magnetic north"

   OutStd( oLantern:cInscription )

   oLantern:Engrave()
   oCompass:Engrave()

   RETURN
