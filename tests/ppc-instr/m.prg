// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; a prova de VALOR (camada B)
// vive no irmao instr.prg (HBTEST), e a prova de CANAL vive na guarda corpus_instrument.
// (regua: docs/pp-corpus/METODO.md § 4b)
//
// Familia PP COMO INSTRUMENTO (docs/pp-corpus/pp-as-instrument.md) -- este arquivo e' a
// COBAIA dos CANAIS do core, e cada comentario abaixo e' de proposito:
//   -u   ISOLA: aplica so' as MINHAS regras (far.ch). O '?' (um #command do std.ch)
//        passa INTACTO -- prova que -u nao arrasta a linguagem junto.
//   .ppo DESTROI o que nao e' codigo: os comentarios abaixo e o #include somem. Por
//        isso o .ppo NAO serve como FONTE de refatoracao (a recusa do P7) -- ele e'
//        resultado, nao original.
//   .ppt guarda o passo INTERMEDIARIO (MODERNO Alfa VALOR nX) que o .ppo ja' comeu:
//        e' o unico oraculo do multi-passe.
// O alvo da migracao (far_Migrado) e' CODIGO de verdade porque fixture TEM de compilar.
// um comentario que o programador quer MANTER
#include "far.ch"

PROCEDURE Main()
   LOCAL nX := 1        // comentario de fim de linha
   ANTIGO Alfa COM nX   // o site a migrar
   ? "oi"               // '?' e #command do std.ch - o -u NAO deve toca-lo
   RETURN

STATIC FUNCTION far_Migrado( cNome, xValor )
   RETURN cNome + hb_ntos( xValor )
