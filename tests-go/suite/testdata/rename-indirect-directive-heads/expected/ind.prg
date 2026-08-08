#define EOC ;;

#xcommand CREATECMD => #xcommand CMDNOVO => QOut("1") EOC QOut("2")
#xcommand NIVEL1 => #xcommand NIVEL2 => #xcommand FUNDO => QOut("fundo")

PROCEDURE Main()

   CREATECMD
   CMDNOVO
   NIVEL1
   NIVEL2
   FUNDO

   RETURN
