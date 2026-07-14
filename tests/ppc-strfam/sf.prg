// METODO-V2(2026-07-14): revisado pelo metodo novo -- comentario INTERPRETA o
// oraculo (nao o transcreve), e o que ele afirma esta' provado por assert ou
// pelo dump. Prova: os 4 estringificadores e o MACRO (pp vivo + runtime).
// (regua: docs/pp-corpus/METODO.md § 4b)
/*
 * COMO COMPILAR:
 *   sintaxe:  harbour <este.prg> -n -q0 -w3 -es2 -s -I$HB_CORE/contrib/hbtest
 *   rodar:    hbmk2  <este.prg> $HB_CORE/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi
 *
 * Usa `#include "hbtest.ch"` (e NAO `#require`) de proposito: assim o harbour CRU
 * tambem compila o arquivo -- o `#require` so' o hbmk2 resolve, e um .prg que nao
 * compila no compilador e' um .prg que todo mundo (IDE inclusive) trata como
 * quebrado. O .vscode/settings.json aponta a extensao para o harbour do FORK e
 * inclui o contrib/hbtest, entao o editor tambem fica verde.
 *
 * A REGUA E' A GUARDA: `make ppcorpus` compila TODOS os .prg do corpus, RODA os que
 * tem assert, e exige ZERO falhas.
 */

/*
 * ppc-strfam - OS QUATRO ESTRINGIFICADORES DO PP, e o MACRO
 * ==========================================================
 * Corpus do pp: o conhecimento mora AQUI, no .prg que COMPILA, RODA e se AFIRMA --
 * nao no markdown, que apodrece calado (virada de metodo, Diego, 2026-07-14).
 *
 * DUAS CAMADAS DE PROVA, e o Diego tem razao em exigir as duas:
 *
 *   (A) o que a diretiva VIRA  -> o pp VIVO do core (`__pp_Init`/`__pp_AddRule`/
 *       `__pp_Process`, o idioma do harbour/tests/ppapi.prg): ele TRANSFORMA e
 *       DEVOLVE O TEXTO, sem executar nada.
 *   (B) o que a diretiva VALE  -> o `HBTEST <expr> IS <esperado>` do contrib/hbtest:
 *       ele EXECUTA e compara o valor.
 *
 * As duas sao necessarias porque ELAS DISCORDAM -- e foi a discordancia que me
 * desmentiu (ver o item 4). Provar so' uma das duas e' acreditar em meia verdade.
 *
 * ORIGEM: o teste que os autores do pp escreveram para o pp -- harbour/tests/pp.prg
 * ("Tests for stringify match markers"). Ele tortura os quatro result-markers contra
 * MACRO, string e expressao: cantos que eu nao teria inventado (exemplo meu so'
 * contem o que eu ja' entendi).
 *
 * O QUE SE APRENDE (cada frase e' um assert abaixo):
 *
 *   1. Os quatro concordam sobre PALAVRA NUA. So' divergem em dois lugares: diante
 *      de uma STRING e diante de um MACRO.
 *
 *   2. Sobre MACRO PURO (`&x`), o <"z"> (strstd) e o <(z)> (strsmart) NAO
 *      estringificam: o pp DESFAZ o macro e emite o SIMBOLO, como codigo
 *      (ppcore.c:5254-5256 -- emite `value + 1`, pulando o `&`, como KEYWORD, e
 *      registra a derivacao como 'c'lone). E' a semantica Clipper: `USE &cArq` tem
 *      de virar a VARIAVEL, nao a string "&cArq".
 *      => o nome dentro do macro e' SIMBOLO DE VERDADE. NAO e' "a parede do macro":
 *         nao ha' macro em runtime, o pp o desfez ao compilar.
 *
 *   3. O #<z> (strdump; o core o chama de DUMB) e' o unico LITERAL: preserva o texto
 *      escrito, `&` e tudo. A camada (A) prova: `sf_( "&cAlvo" )`.
 *
 *   4. ...E A CAMADA (B) ME DESMENTE: esse literal e' MACRO VIVO EM RUNTIME. Uma
 *      string que contem `&nome` e' reavaliada a cada execucao -- se o memvar existe,
 *      ela VALE O VALOR DELE. Entao o dumb preserva o texto no FONTE e o texto se
 *      re-expande na EXECUCAO. Eu tinha escrito no markdown que "o dumb preserva o
 *      texto", e estava certo na camada (A) e ERRADO no que o programa ve.
 *      (Cuidado com o Len(): o otimizador dobra o literal em tempo de compilacao, o
 *      macro nem roda, e Len( "&cAlvo" ) da' 6 -- o que ENGANA quem so' olha isso.)
 *
 * CONSEQUENCIA PARA O REFATORADOR: renomear um memvar muda o comportamento de
 * QUALQUER string que mencione `&nome`. String e' DADO -- a ferramenta nao edita
 * (CLAUDE.md §1) --, mas TEM de relatar. E' por isso que o `usages` diz "possible
 * reference in string": aquele relato nao e' zelo, e' a unica defesa que existe.
 *
 * O macro so' alcanca simbolo NAO-declarado (memvar): `&x` sobre um LOCAL da E0042
 * "Macro of declared symbol" -- por isso o tests/pp.prg do core usa MEMVAR/PRIVATE,
 * e nos tambem. (Descoberto quebrando a cara.)
 */

#include "hbtest.ch"   // (o -I do contrib/hbtest vem do hbmk2/hbc e do .vscode/settings.json)

REQUEST __pp_StdRules                 // o pp VIVO, para a camada (A)

// forma de EXPRESSAO (nao comando): o `HBTEST <x> IS <r>` embrulha o <x> num
// codeblock, e comando nao cabe em codeblock
#xtranslate SF_REG( <z> ) => sf_( <z> )
#xtranslate SF_NOR( <z> ) => sf_( <"z"> )
#xtranslate SF_SMA( <z> ) => sf_( <(z)> )
#xtranslate SF_DMP( <z> ) => sf_( #<z> )

MEMVAR cAlvo

PROCEDURE Main()

   LOCAL pp, cCru, cMac

   PRIVATE cAlvo := "oi"

   /* ================= CAMADA (A): o que a diretiva VIRA =================
      O pp vivo transforma o texto e NAO executa nada. As mesmas quatro regras,
      registradas em runtime, e o texto que sai de cada uma. */

   pp := __pp_Init()
   __pp_AddRule( pp, '#xtranslate SF_REG( <z> ) => sf_( <z> )' )
   __pp_AddRule( pp, '#xtranslate SF_NOR( <z> ) => sf_( <"z"> )' )
   __pp_AddRule( pp, '#xtranslate SF_SMA( <z> ) => sf_( <(z)> )' )
   __pp_AddRule( pp, '#xtranslate SF_DMP( <z> ) => sf_( #<z> )' )

   // palavra nua: o regular passa o simbolo; os outros tres citam o NOME
   HBTEST __pp_Process( pp, "SF_REG( cAlvo )" ) IS 'sf_( cAlvo )'
   HBTEST __pp_Process( pp, "SF_NOR( cAlvo )" ) IS 'sf_( "cAlvo" )'
   HBTEST __pp_Process( pp, "SF_SMA( cAlvo )" ) IS 'sf_( "cAlvo" )'
   HBTEST __pp_Process( pp, "SF_DMP( cAlvo )" ) IS 'sf_( "cAlvo" )'

   /* MACRO -- e aqui o proprio TESTE tropecou no fato que ele testa, o que e' a
      prova mais eloquente que existe: escrever a entrada como o literal
      "SF_NOR( &cAlvo )" NAO funciona, porque essa string e' MACRO VIVO e se
      expande para "SF_NOR( oi )" ANTES de chegar ao pp. Para entregar um `&` ao
      pp e' preciso montar a string SEM o literal: */
   cMac := "&" + "cAlvo"                       // <- nao expande (item 4)

   // normal e smart DESFAZEM o `&`: emitem o SIMBOLO, como codigo
   HBTEST __pp_Process( pp, "SF_NOR( " + cMac + " )" ) IS 'sf_( cAlvo )'
   HBTEST __pp_Process( pp, "SF_SMA( " + cMac + " )" ) IS 'sf_( cAlvo )'

   /* ...e o DUMB e' o UNICO que preserva o literal, `&` inclusive.
      NOTE: ate' o valor ESPERADO tem de ser montado -- escrever 'sf_( "&cAlvo" )'
      como literal faria o macro expandir o ESPERADO para 'sf_( "oi" )'. O fato
      contamina tudo que o mencione, inclusive o teste. */
   HBTEST __pp_Process( pp, "SF_DMP( " + cMac + " )" ) IS 'sf_( "' + cMac + '" )'

   /* ================= CAMADA (B): o que a diretiva VALE =================
      Agora as MESMAS diretivas, compiladas de verdade, e o valor em runtime. */

   HBTEST SF_REG( cAlvo )   IS "oi"        // o simbolo -> o valor dele
   HBTEST SF_NOR( cAlvo )   IS "cAlvo"     // o nome virou string
   HBTEST SF_SMA( cAlvo )   IS "cAlvo"
   HBTEST SF_DMP( cAlvo )   IS "cAlvo"

   HBTEST SF_SMA( "cAlvo" ) IS "cAlvo"     // string ja' e' string -> passa crua
   HBTEST SF_NOR( "cAlvo" ) IS '"cAlvo"'   // ...o normal cita de novo

   HBTEST SF_NOR( &cAlvo )  IS "oi"        // macro desfeito -> o VALOR do memvar
   HBTEST SF_SMA( &cAlvo )  IS "oi"

   /* O DUMB: a camada (A) provou que a expansao e' a string LITERAL "&cAlvo".
      Aqui, em runtime, ela vale "oi" -- porque string com `&nome` e' MACRO VIVO.
      As duas coisas sao verdade, em camadas diferentes. */
   HBTEST SF_DMP( &cAlvo )  IS "oi"

   /* a prova direta do macro-em-string (o achado que o assert arrancou de mim) */
   HBTEST Upper( "&cAlvo" ) IS "OI"        // avaliada -> EXPANDE
   HBTEST "&" + "cAlvo"     IS cMac        // concatenada -> nao expande (e o
                                           // esperado tambem precisa ser montado)
   HBTEST Len( "&cAlvo" )   IS 6           // dobrada pelo otimizador -> nem roda

   // ...e sem memvar com aquele nome, o literal fica literal
   cCru := "&naoExiste"
   HBTEST cCru IS "&naoExiste"

   RETURN

STATIC FUNCTION sf_( x )
   RETURN x
