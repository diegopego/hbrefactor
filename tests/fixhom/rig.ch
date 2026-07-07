// DSL 1 da B4f-3 (prova de generalidade dos homônimos): espelho
// ESTRUTURAL do hbclass com vocabulário próprio - RIG gera a função-dona,
// COG registra a mensagem por STRING e declara pelo canal da linguagem,
// FORGE implementa pelo composto colado <dona>_<mensagem>. NENHUMA destas
// palavras existe no hbrefactor nem no core (régua do caso 64): um
// programador qualquer poderia ter escrito isto em seu aplicativo.

#xtranslate __RIG_MTH <!c!> <m> => <c>_<m>

#xcommand RIG <cls> => ;
   _HB_CLASS <cls> <cls> ;;
   FUNCTION <cls>() ;;
   LOCAL oR := RigMake( <(cls)> ) ;;
   #undef _RIG_NAME_ ; #define _RIG_NAME_ <cls>

#xcommand COG <msg> GIVES <ret> => ;
   _HB_MEMBER <msg>() AS CLASS <ret> ;;
   oR:Fit( <(msg)>, @__RIG_MTH _RIG_NAME_ <msg> () )

#xcommand ENDRIG => RETURN oR AS CLASS _RIG_NAME_

#xcommand FORGE <msg> OF <cls> RETORNA <x> => ;
   STATIC FUNCTION __RIG_MTH <cls> <msg> () ;;
   RETURN <x>
