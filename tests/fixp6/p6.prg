// fixture da fase P/P6: estrutura da regra - regra sem cabeca, grupos
// opcionais FORA DE ORDEM, multi-passe, e a guarda de orfao por FATO
#include "p6.ch"

PROCEDURE Main()
   LOCAL nQtd := 21
   LOCAL nTot
   LOCAL cVaso := "cheio"
   LOCAL nHoras := 3

   nTot := nQtd ZORBADO
   ? nTot
   REGA Flor SOL nHoras AGUA cVaso
   ? vk_Escudo()
   RETURN

VULK Lamina KRAN "aco" PLIX 7
VULK Elmo PLIX 3 KRAN "bronze"
VULK Escudo
GLIMER Broquel

FUNCTION rg_( c, q, h )
   RETURN { c, q, h }
