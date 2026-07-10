// fixture B9 fatia 4 - segundo modulo: INIT de registro (startup no
// retrato), helper com parametro obrigatorio (quebra protegida = "failed"
// honesto) e registrador so alcancavel por --run (chama o helper, nao a
// primitiva - o v1 da selecao e por chamada DIRETA a __CLS*)
#include "forja.ch"

FORJA METAL Aco TEMPERA "funde", "lamina", "solda"

INIT PROCEDURE PreparaBase()

   LOCAL nCls := __clsNew( "FORNO_BASE", 0 )

   __clsAddMsg( nCls, "ACENDE", {| o | o }, HB_OO_MSG_INLINE )

   RETURN

FUNCTION MontaMetal( cNome )

   LOCAL nCls := __clsNew( "METAL_" + Upper( cNome ), 0 )

   __clsAddMsg( nCls, "FUNDE", {| o | o }, HB_OO_MSG_INLINE )

   RETURN nCls

FUNCTION RegistraEspecial()
   RETURN MontaMetal( "Especial" )
