// Q4 (revisao-generalidade): DSL adversarial NAO-espelho - a linha de
// declaracao carrega um identificador que NAO e pai (TEMPERA <forja> =
// forjador, passado por @ref como callback). Nenhuma palavra desta DSL
// existe no hbrefactor nem no core (regua do caso 64).
#xtranslate __ARM_MTH <!c!> <m> => <c>_<m>

#xcommand ARMA <cls> TEMPERA <forja> => ;
   _HB_CLASS <cls> <cls> ;;
   FUNCTION <cls>() ;;
   LOCAL oA := ArmaMake( <(cls)>, @<forja>() ) ;;
   #undef _ARM_NAME_ ; #define _ARM_NAME_ <cls>

#xcommand GUME <msg> GIVES <ret> => ;
   _HB_MEMBER <msg>() AS CLASS <ret> ;;
   oA:Fit( <(msg)>, @__ARM_MTH _ARM_NAME_ <msg> () )

#xcommand ENDARMA => RETURN oA AS CLASS _ARM_NAME_

#xcommand AFIA <msg> OF <cls> RETORNA <x> => ;
   STATIC FUNCTION __ARM_MTH <cls> <msg> () ;;
   RETURN <x>
