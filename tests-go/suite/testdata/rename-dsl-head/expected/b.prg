// módulo 2 da fixture DSL (B4)
#include "menu.ch"

FUNCTION AbreCoisa( nQtd )

   MENU_ITEM "Sub" ACTION QOut( nQtd ) AT 7, 12

   RETURN Min( nQtd, LIMITE_TETO )

FUNCTION MenuAdd( nRow, nCol, cLabel, bAct )

   ? nRow, nCol, cLabel
   IF bAct != NIL
      Eval( bAct )
   ENDIF

   RETURN NIL
