/*
 * ppc-pragma - O #pragma: o COMPILADOR muda no meio do arquivo
 * ============================================================
 * Corpus do pp: o conhecimento mora no .prg que COMPILA, RODA e se AFIRMA.
 * Asserts do core (contrib/hbtest). Origem: harbour/tests/pragma.prg, indicado
 * pelo Diego -- o teste que os autores do pp escreveram para a superficie #pragma.
 *
 * O QUE SE APRENDE:
 *
 *   1. O #pragma nao e' "configuracao do build": ele muda o COMPILADOR NO MEIO DO
 *      ARQUIVO. A partir da linha em que aparece, o MESMO texto-fonte passa a gerar
 *      pcode DIFERENTE. Nao ha' nada no codigo que denuncie isso -- so' a linha do
 *      pragma, la' atras.
 *
 *   2. O NOME MENTE, e este e' o achado. `#pragma Shortcut=On` NAO liga o curto-
 *      circuito: ele liga o SWITCH /Z, e o /Z quer dizer "sem shortcut".
 *      Cadeia, no fonte do core:
 *        ppcore.c:3775  "SHORTCUT" -> hb_pp_setCompilerSwitch( "z", valor )
 *        ppcomp.c:206   case 'z': if( iValue ) supported &= ~HB_COMPFLAG_SHORTCUTS;
 *      Ou seja: Shortcut=On  => /Z+ => o `.AND.` AVALIA os dois lados.
 *               Shortcut=Off => /Z- => o `.AND.` para no primeiro .F. (o normal).
 *      Eu tinha certeza do contrario. So' o assert me corrigiu.
 *
 *   3. Consequencia semantica REAL: com Shortcut=On, `.F. .AND. f()` CHAMA f().
 *      Se f() tem efeito colateral, o programa muda de comportamento -- e o codigo
 *      e' identico letra por letra.
 *
 * CONSEQUENCIA PARA O REFATORADOR (lacuna marcada, fase P19):
 *   O dump NAO exporta pragma nenhum (verificado: a string "pragma" nao aparece no
 *   .ast.json). Logo a ferramenta nao sabe que uma REGIAO do arquivo compila com
 *   outra semantica. Mover codigo entre regioes (o extract-function joga a funcao
 *   nova no FIM do arquivo) pode mudar o pcode do codigo movido -- em silencio.
 */

#include "hbtest.ch"

PROCEDURE Main()

   LOCAL nComShortcutOn := 0
   LOCAL nComShortcutOff := 0

   /* `Shortcut=On` => /Z+ => SEM curto-circuito => o lado direito E' avaliado */
   #pragma Shortcut=On

   IF .F. .AND. Efeito( @nComShortcutOn )
   ENDIF

   /* `Shortcut=Off` => /Z- => COM curto-circuito (o normal) => o lado direito NAO
      e' avaliado, porque o `.F.` ja' decidiu a expressao */
   #pragma Shortcut=Off

   IF .F. .AND. Efeito( @nComShortcutOff )
   ENDIF

   // o nome MENTE: "On" avaliou o lado direito; "Off" nao avaliou
   HBTEST nComShortcutOn  IS 1
   HBTEST nComShortcutOff IS 0

   RETURN

STATIC FUNCTION Efeito( n )
   n := n + 1
   RETURN .T.
