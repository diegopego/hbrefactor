// Fixture da COMPLETUDE M-B (fecha a RD): os blocos acessadores de DATA do
// hbclass.ch - as formas VAR ... IS / IN / TO do dialeto Class(y) - geram
// codeblocks {|Self| Self:<msg>...} cujo receptor Self e' GERADO pela
// diretiva (nao tem token de fonte, como o Self do INLINE). Antes o send
// Self:<msg> DENTRO desses getters/setters saia 'possible'; agora o canal
// _HB_INLINESELF (que a RD ja' cravava nos INLINE/OPERATOR/MESSAGE) tambem
// os marca -> confirmed, SEM mudar a ferramenta.
#include "hbclass.ch"

CREATE CLASS Gizmo

   VAR nRaw  INIT 0                          // DATA real
   VAR oPart INIT NIL                        // DATA real (guarda um objeto)

   VAR nEcho AS Numeric IS nRaw              // getter gerado: {|Self| Self:nRaw}
   VAR nVia  AS Numeric IS nCount TO oPart   // getter gerado: {|Self| Self:oPart:nCount}

   METHOD New()

END CLASS

METHOD New() CLASS Gizmo
   RETURN Self

PROCEDURE Main()

   LOCAL oG AS CLASS Gizmo

   oG := Gizmo():New()
   ? oG:nRaw, oG:nEcho, oG:nVia

   RETURN
