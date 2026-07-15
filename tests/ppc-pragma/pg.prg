/*
 * METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; cada afirmacao esta'
 * provada por assert que passa PELO #pragma, ou pelo oraculo citado ao lado.
 * (regua: docs/pp-corpus/METODO.md § 4b)
 *
 * ppc-pragma - O #pragma: o COMPILADOR muda no meio do arquivo
 * ============================================================
 * Origem: harbour/tests/pragma.prg, indicado pelo Diego -- o teste que os autores
 * do pp escreveram para a superficie #pragma. Guarda: corpus_pragma. Fase da lacuna
 * (dump nao ve pragma): docs/roadmap.md § P19.
 *
 * O SUJEITO CERTO (METODO.md § 4b/5): o pp SUBSTITUI TEXTO; quem muda de
 * comportamento com o pragma e' o COMPILADOR. Prova pelos oraculos, que DISCORDAM:
 *
 *   1. .ppo (o que o compilador recebe como TEXTO): os DOIS `IF` chegam IDENTICOS,
 *      letra por letra, modulo o nome do local (`@nComShortcutOn` x `...Off`). O
 *      pragma NAO deixa rastro no texto -- porque o pp nao o "aplica", so' o anota.
 *   2. .ppt (o traco): e' o UNICO oraculo que enxerga o pragma -- uma linha de
 *      trace por sitio (`#pragma Shortcut set to 'On'` / `'Off'`). O SENTIDO: a
 *      mudanca vive no ESTADO do compilador, nao na substituicao.
 *   3. runtime (o que o PROGRAMA faz): a camada B abaixo. Mesmo texto, comportamento
 *      OPOSTO -- e so' o assert, executado, revela qual.
 *
 * O NOME MENTE, e este e' o achado: `#pragma Shortcut=On` NAO liga o curto-circuito.
 * Ele liga o switch /Z, e /Z quer dizer "SEM shortcut". Cadeia no fonte do core:
 *   src/pp/ppcore.c:3779   "SHORTCUT" -> hb_pp_setCompilerSwitch( pState, "z", ... )
 *   src/compiler/ppcomp.c:211  z+ (On) faz supported &= ~HB_COMPFLAG_SHORTCUTS
 * Ou seja: Shortcut=On => /Z+ => o `.AND.` AVALIA os dois lados; Shortcut=Off => /Z-
 * => o `.AND.` para no primeiro `.F.` (o normal). So' o assert me corrigiu.
 *
 * CONSEQUENCIA PARA O REFATORADOR (lacuna P19):
 *   O dump NAO exporta pragma nenhum (verificado: `grep pragma pg.ast.json` = 0; os
 *   hits de "Shortcut" sao so' os nomes de local). Logo a ferramenta nao sabe que uma
 *   REGIAO do arquivo compila com outra semantica. Mover codigo entre regioes (o
 *   extract-function joga a funcao nova no FIM do arquivo) pode mudar o pcode do
 *   codigo movido -- em silencio.
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
