// forja.prg - exercita as regras de forja.ch (fixture B4g)
#include "forja.ch"

PROCEDURE Main()

   LOCAL oIt
   LOCAL nMeia := MEIA 10

   FORJA oIt TAMANHO DOBRO( LARGURA_PADRAO ) ROTULO "brk" MODO RAPIDO
   TEMPERA 4 GRAU 2
   LOTE 1, 2, 3
   ANOTA fim de teste
   BATIZA Malho COM Upper("m")
   RECOZE MODO FRIO
   PRENSA 1 COM 2 EM 3
   ForjaNota( nMeia )

   RETURN
