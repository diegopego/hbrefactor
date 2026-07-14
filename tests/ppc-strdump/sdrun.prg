// METODO-V2(2026-07-14): revisado pelo metodo novo -- comentario INTERPRETA o
// oraculo (nao o transcreve), e o que ele afirma esta' provado por assert ou
// pelo dump. Prova: o #<x> estringifica o NOME escrito (pp vivo + runtime).
// (regua: docs/pp-corpus/METODO.md § 4b)
/*
 * ppc-strdump / sdrun.prg -- o `#<x>` (strdump), com asserts.
 *
 * COMO COMPILAR:
 *   sintaxe:  harbour sdrun.prg -n -q0 -w3 -es2 -s -I$HB_CORE/contrib/hbtest
 *   rodar:    hbmk2  sdrun.prg $HB_CORE/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi
 *
 * Duas camadas, as duas assertadas:
 *   (A) o TEXTO que a diretiva vira -- pelo pp VIVO (__pp_Process transforma e
 *       devolve o texto, sem executar; idioma de harbour/tests/ppapi.prg)
 *   (B) o VALOR que ela vale -- pelo hbtest (HBTEST <expr> IS <esperado>)
 *
 * As regras sob teste:
 *   #xcommand SELO <v> AFERIDO => <v> := sd_Afere( #<v> )   // <v> copia, #<v> cita
 *   #xcommand LAVRA <*txt*>    => sd_Lavra( #<txt> )        // so' cita
 */

#include "hbtest.ch"

REQUEST __pp_StdRules

#xcommand SELO <v> AFERIDO => <v> := sd_Afere( #<v> )
#xcommand LAVRA <*txt*>    => sd_Lavra( #<txt> )

PROCEDURE Main()

   LOCAL pp
   LOCAL nLastro

   /* ---------- (A) o TEXTO que a diretiva vira ---------- */

   pp := __pp_Init()
   __pp_AddRule( pp, "#xcommand SELO <v> AFERIDO => <v> := sd_Afere( #<v> )" )
   __pp_AddRule( pp, "#xcommand LAVRA <*txt*> => sd_Lavra( #<txt> )" )

   // o `nLastro` escrito uma vez sai duas: copiado (`<v>`) e entre aspas (`#<v>`)
   HBTEST __pp_Process( pp, "SELO nLastro AFERIDO" ) ;
      IS 'nLastro := sd_Afere( "nLastro" )'

   // o wild inteiro vira UMA string, com o span cru
   HBTEST __pp_Process( pp, "LAVRA fundo de reserva" ) ;
      IS 'sd_Lavra( "fundo de reserva" )'

   // o mesmo texto `nLastro`, na regra que so' cita, sai entre aspas
   HBTEST __pp_Process( pp, "LAVRA nLastro" ) IS 'sd_Lavra( "nLastro" )'

   /* ---------- (B) o VALOR que ela vale ---------- */

   // .ppo:  SELO nLastro AFERIDO  ->  nLastro := sd_Afere( "nLastro" )
   // sd_Afere devolve Len( cNome ); 7 = Len( "nLastro" ), o NOME escrito.
   // (a variavel esta' NIL aqui: se o `#<v>` passasse o VALOR, Len( NIL ) daria erro)
   SELO nLastro AFERIDO
   HBTEST nLastro IS 7

   // sd_Lavra devolve o que recebeu: o span cru, tal como escrito
   HBTEST sd_Lavra( "fundo de reserva" ) IS "fundo de reserva"

   RETURN

STATIC FUNCTION sd_Afere( cNome )
   RETURN Len( cNome )

STATIC FUNCTION sd_Lavra( cTexto )
   RETURN cTexto
