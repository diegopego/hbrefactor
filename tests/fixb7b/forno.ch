// DSL do portao de generalidade do B7b (alvo 2): NAO-espelho do hbclass.
// Registro runtime PURO (__clsNew/__clsAddMsg - dispatch real do VM), sem
// canal declared; o membro INLINE recebe o corpo como BLOCO escrito pelo
// usuario, cujo 1o parametro NAO se chama Self. O fato que tipa esse
// parametro e o do VM (classes.c:4554: o receptor entra como 1o argumento
// do bloco) sobre o registro como-escrito - nada keyed a hbclass. Nenhuma
// palavra desta DSL existe no hbrefactor nem em include do core (regua do
// caso 64).
#include "hboo.ch"

#xcommand FORNO <dona> => ;
   FUNCTION <dona>() ;;
   LOCAL hFo := __clsNew( <(dona)>, 0 )

#xcommand TACHO <msg> DE <fn> => ;
   __clsAddMsg( hFo, <(msg)>, @<fn>(), HB_OO_MSG_METHOD )

#xcommand BRASA <msg> COM <bloco> => ;
   __clsAddMsg( hFo, <(msg)>, <bloco>, HB_OO_MSG_INLINE )

#xcommand ENDFORNO => RETURN __clsInst( hFo )
