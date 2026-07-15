// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; a prova de VALOR (camada B)
// vive no irmao abrrun.prg (HBTEST), e a prova do FATO do dump (ast-15) na guarda
// corpus_abbrev. (regua: docs/pp-corpus/METODO.md § 4b)
//
// Familia ABREVIACAO dBase (P-AUDIT/ast-15, docs/pp-corpus/abbreviation.md). A regra usa
// #command (SEM 'x') -> casa keyword abreviada a partir de 4 letras. A keyword SECUNDARIA
// GRAV, escrita POR EXTENSO, e' prefixo de 4 letras da CABECA GRAVAR: um consumidor que
// ADIVINHE por texto nao separa "GRAV literal #2 da regra" de "GRAVAR abreviado". O pp SABE
// qual literal casou (ele casou!); o ast-15 exporta o fato ("ruletok"), e a ferramenta para
// de dar recusa FALSA no rename da cabeca (o furo do caso 115).
#include "abr.ch"

PROCEDURE Main()
   GRAVAR 1 GRAV 2      // uso 100% NAO-abreviado: GRAV e keyword da regra
   APAG 3               // uso REALMENTE abreviado de APAGAR (dBase, >= 4)
   RETURN

FUNCTION zz_( a, b )
   RETURN a + b
