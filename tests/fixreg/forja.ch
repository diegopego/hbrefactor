// fixture B9 fatia 4 - DSL inventada NAO-espelho (regua dos casos 64/72-74):
// FORJA METAL registra a classe em RUNTIME com nome COMPUTADO -
// "METAL_<nome>" nunca aparece escrito em fonte nenhum; so a EXECUCAO do
// registro revela a classe (exec-registry, spec-b9-fatia4).
#include "hboo.ch"

#xcommand FORJA METAL <nome> TEMPERA <met,...> => ;
      FUNCTION Forja_<nome>() ;;
         LOCAL nCls := __clsNew( "METAL_" + Upper( <(nome)> ), 0 ) ;;
         AEval( { <(met)> }, {| cMet | __clsAddMsg( nCls, Upper( cMet ), {| o | o }, HB_OO_MSG_INLINE ) } ) ;;
         RETURN nCls
