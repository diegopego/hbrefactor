#define EOC ;;

#xcommand CREATECMD => #xcommand NEWCMD => QOut("1") EOC QOut("2")
#xcommand NIVEL1 => #xcommand NIVEL2 => #xcommand NIVEL3 => QOut("fundo")

PROCEDURE Main()

   CREATECMD
   NEWCMD
   NIVEL1
   NIVEL2
   NIVEL3

   RETURN
