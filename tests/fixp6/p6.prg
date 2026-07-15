// METODO-V2(2026-07-15): a prova de VALOR (camada B) vive no irmao p6run.prg (HBTEST),
// e a prova da ESTRUTURA no dump (head null, match[], multi-passe) na guarda
// corpus_rulestruct. (regua: docs/pp-corpus/METODO.md § 4b)
//
// Familia ESTRUTURA DA REGRA (fase P/P6, docs/pp-corpus/rule-structure.md): DSL inventada
// NAO-espelho que exercita regra SEM CABECA (o match comeca num marker), grupos opcionais
// FORA DE ORDEM, multi-passe (uma regra expande na cabeca de outra) e o orfao por FATO.
// Regua do caso 64: nenhuma palavra desta DSL aparece em src/hbrefactor.prg.
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
