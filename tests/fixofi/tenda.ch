// DSL da revisão de generalidade (Q1-Q3/Q7): NÃO-espelho do hbclass.
// Diferenças deliberadas de forma: a colagem põe a MENSAGEM primeiro e a
// dona por ÚLTIMO com separador multi-byte (Talha_na_Banca), a assinatura
// com parâmetros existe UMA única vez (na implementação - não há par
// protótipo/implementação a casar) e o registro é runtime PURO
// (__clsNew/__clsAddMsg - dispatch real do VM), sem canal declared.
// Nenhuma palavra desta DSL existe no hbrefactor nem em include do core
// (régua do caso 64).

#include "hboo.ch"

#xtranslate __OFI_NOME <m> <!d!> => <m>_na_<d>

#xcommand TENDA <dona> => ;
   FUNCTION <dona>() ;;
   LOCAL hTe := __clsNew( <(dona)>, 0 ) ;;
   #undef _TENDA_ ; #define _TENDA_ <dona>

#xcommand LAVRA <msg> => ;
   __clsAddMsg( hTe, <(msg)>, @__OFI_NOME <msg> _TENDA_ (), HB_OO_MSG_METHOD )

#xcommand ENDTENDA => RETURN __clsInst( hTe )

#xcommand OFICIO <msg> DA <dona> PEDE <p1>, <p2> => ;
   STATIC FUNCTION __OFI_NOME <msg> <dona> ( <p1>, <p2> )
