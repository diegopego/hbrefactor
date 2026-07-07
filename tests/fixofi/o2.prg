// fixofi m2: a dona homônima (Tear também tem Lustro) e o consumidor -
// sends com argumentos, alvos do reorder/rename/call-graph.
#include "tenda.ch"

TENDA Tear
LAVRA Lustro
ENDTENDA

OFICIO Lustro DA Tear PEDE nFio, nTrama

   RETURN nFio - nTrama

PROCEDURE Main()

   LOCAL b := Banca()
   LOCAL t := Tear()

   ? b:Talha( 2, 5 )
   ? b:Verniz( 3, 4 )
   ? b:Lustro( 7, 1 )
   ? t:Lustro( 9, 6 )

   RETURN
