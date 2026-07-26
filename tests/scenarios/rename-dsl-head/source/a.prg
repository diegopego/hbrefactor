// módulo 1 da fixture DSL (B4): usos das três famílias de regra
#include "menu.ch"

PROCEDURE Main()

   LOCAL GetList := {}
   LOCAL nTotal := SQUARED( 3 )
   LOCAL nVez := 0
   LOCAL cNome := "abc"

   MENUITEM "Abrir" ACTION AbreCoisa( nTotal ) AT 5, 10
   MENUITEM "Sair" ;
      ACTION QOut( "fim" ) ;
      AT 6, 10
   MENUBOX "Moldura"

   ? SQUARED( 2 ), SQUARED( nTotal )

   REPEAT
      nVez++
   UNTIL nVez >= 3

   @ 1, 2 SAY "oi" GET cNome
   READ

   ? nVez, cNome

   RETURN
