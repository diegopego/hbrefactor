// fixture B7: tipos interprocedurais - fabrica sem DECLARE, uniao de call
// sites, conjunto >1 (IIF nao-constante) e venenos com send observavel
// (@ref, escrita destacada em bloco, Self reescrito).
#include "hbclass.ch"

CREATE CLASS Peca
   VAR nGiros INIT 0
   METHOD Gira()
END CLASS

METHOD Gira() CLASS Peca
   ::nGiros := ::nGiros + 1
   RETURN ::nGiros

CREATE CLASS Disco
   VAR nVoltas INIT 0
   METHOD Gira()
   METHOD Solta( oOutro )
END CLASS

METHOD Gira() CLASS Disco
   ::nVoltas := ::nVoltas + 2
   RETURN ::nVoltas

METHOD Solta( oOutro ) CLASS Disco
   // veneno: Self reescrito ANTES do send - ::Gira() nao pode classificar
   // (o acesso a VAR antes do veneno conta o uso de SELF; send nao conta)
   ::nVoltas := ::nVoltas + 1
   Self := oOutro
   ::Gira()
   RETURN NIL

FUNCTION NovaPeca()
   // fabrica SEM DECLARE: o retorno tipa pelo rotulo de RETURN (ast-6)
   RETURN Peca():New()

PROCEDURE UsaQualquer( oCoisa )
   // uniao dos call sites do projeto: {PECA, DISCO} -> conjunto >1
   oCoisa:Gira()
   RETURN

STATIC PROCEDURE Mexe( oRef )
   oRef := NIL
   RETURN

PROCEDURE Main()
   LOCAL p := NovaPeca()
   LOCAL o := iif( UmaCondicao(), Peca():New(), Disco():New() )
   LOCAL q := Peca():New()
   LOCAL r := Peca():New()
   LOCAL b

   p:Gira()
   o:Gira()
   UsaQualquer( Peca():New() )
   UsaQualquer( Disco():New() )
   Mexe( @q )
   q:Gira()
   b := {|| r := Disco():New() }
   Eval( b )
   r:Gira()
   Disco():New():Solta( Peca():New() )
   OutStd( hb_ntos( p:nGiros ) + hb_eol() )
   RETURN

FUNCTION UmaCondicao()
   // condicao de runtime: impede o fold do IIF (o conjunto fica {PECA,DISCO})
   RETURN hb_MilliSeconds() % 2 == 0
