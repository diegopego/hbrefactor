// DSL de generalidade da RE.6 (F6.3): parentesco DECLARADO por um comando
// INVENTADO, NÃO-espelho do hbclass. SPROUT gera a função-dona e declara o
// pai SÓ pelo canal _HB_SUPER (o nome do pai NÃO aparece como identificador
// na linha da função - a leitura por-forma do Q4 não o alcança; só o FATO
// _HB_SUPER o carrega). BUD declara a mensagem; LEAF implementa pelo composto
// colado. Nenhuma destas palavras existe no hbrefactor nem no core (régua do
// caso 64): a exclusão por herança tem de valer aqui SEM ajuste na ferramenta.

#xtranslate __KIN_MTH <!c!> <m> => <c>_<m>

#xcommand SPROUT <cls> [OFFOF <base>] => ;
   _HB_CLASS <cls> <cls> [; _HB_SUPER <base>] ;;
   FUNCTION <cls>() ;;
   LOCAL oK := KinMake( <(cls)> [, <(base)>] ) ;;
   #undef _KIN_NAME_ ; #define _KIN_NAME_ <cls>

#xcommand BUD <msg> => ;
   _HB_MEMBER <msg>() ;;
   oK:Wire( <(msg)>, @__KIN_MTH _KIN_NAME_ <msg> () )

#xcommand ENDSPROUT => RETURN oK

#xcommand LEAF <msg> OF <cls> YIELDS <x> => ;
   STATIC FUNCTION __KIN_MTH <cls> <msg> () ;;
   RETURN <x>
