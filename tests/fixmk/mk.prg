// METODO-V2(2026-07-15): a prova de TEXTO (camada A) vive no irmao mkrun.prg (HBTEST,
// pp vivo), e a prova do FATO do dump (o mkind de cada marker) na guarda corpus_markers.
// (regua: docs/pp-corpus/METODO.md § 4b)
//
// Familia MARKERS (docs/pp-corpus/markers.md): DSL inventada NAO-espelho que exercita
// TODOS os mkinds escriviveis do pp -- 6 de match e 7 de result. Cada linha do Main abaixo
// e' um mkind de proposito; o que cada um FAZ com o token (copia / cita / descarta /
// embrulha) o irmao mkrun.prg prova pelo pp vivo, e o DUMP rotula em corpus_markers.
// (O strdump, o `#<x>`, tem familia PROPRIA -- ppc-strdump; so' o dynval, interno do pp
// __FILE__/__LINE__, segue com recusa documentada no ast-schema.) Regua do caso 64:
// nenhuma palavra desta DSL aparece em src/hbrefactor.prg.
#include "mk.ch"
PROCEDURE Main()
   LOCAL n := 7
   M_REG n
   M_LST 1, 2, 3
   M_RST LIGA
   M_WLD qualquer coisa aqui
   M_EXT ( n )
   M_NAM Fulano
   R_STD Beltrano
   R_BLK n + 1
   R_LOG n
   R_NUL n 42
   RETURN
