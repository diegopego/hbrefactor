// DSL de generalidade da RD (rota da diretiva): um comando INVENTADO,
// NAO-espelho do hbclass, registra comportamento como CODEBLOCK cujo 1o
// parametro e o RECEPTOR, tipado SO pelo canal _HB_INLINESELF do core (o
// param e GERADO pela diretiva - nao tem token de fonte, como o Self do
// INLINE do hbclass). O send dentro do bloco tem de sair confirmed SEM
// ajuste na ferramenta (regua do caso 64: FORGE/BELLOW/STOKE/EMBER/ROUSES
// /YIELDS nao existem no hbrefactor nem no core). O receptor se chama oIt
// (NAO "Self") de proposito: o canal nao depende do nome.

#xtranslate __GIZ_MTH <!c!> <m> => <c>_<m>

#xcommand FORGE <cls> => ;
   _HB_CLASS <cls> <cls> ;;
   FUNCTION <cls>() ;;
   LOCAL oG := GizMake( <(cls)> ) ;;
   #undef _GIZ_NAME_ ; #define _GIZ_NAME_ <cls>

#xcommand BELLOW <msg> => ;
   _HB_MEMBER <msg>() ;;
   oG:Wire( <(msg)>, @__GIZ_MTH _GIZ_NAME_ <msg> () )

#xcommand STOKE <ev> ROUSES <msg> => ;
   oG:Fan( <(ev)>, {|oIt _HB_INLINESELF _GIZ_NAME_| oIt:<msg>() } )

#xcommand ENDFORGE => RETURN oG

#xcommand EMBER <msg> OF <cls> YIELDS <x> => ;
   STATIC FUNCTION __GIZ_MTH <cls> <msg> () ;;
   RETURN <x>
