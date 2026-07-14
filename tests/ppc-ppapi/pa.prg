// METODO-V2(2026-07-14): comentario INTERPRETA o oraculo; cada afirmacao esta'
// provada por assert que passa pela API. (regua: docs/pp-corpus/METODO.md § 4b)
//
// Fixture da familia PP VIVO / API (docs/pp-corpus/pp-api.md).
// Origem: harbour/tests/ppapi.prg e src/pp/pplib.c (indicados pelo Diego).
//
// COMO COMPILAR:
//   sintaxe:  harbour pa.prg -n -q0 -w3 -es2 -s -I$HB_CORE/contrib/hbtest
//   rodar:    hbmk2  pa.prg $HB_CORE/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi
//
// A API (pplib.c):
//   __pp_Init( [cPath], [cStdCh], [lArchDefs] ) -> um estado NOVO e INDEPENDENTE
//       cStdCh AUSENTE -> carrega as regras PADRAO da linguagem (pplib.c:180)
//       cStdCh = ""    -> nenhuma regra: um pp virgem
//       cStdCh = arq   -> le' as regras daquele arquivo
//   __pp_AddRule( pp, "#xcommand ..." )  -> registra regra NAQUELE estado
//   __pp_Process( pp, cTexto )           -> transforma o texto e o DEVOLVE
//   __pp_Reset( pp )                     -> derruba as regras que VOCE adicionou
//   __pp_Path( pp, cPath )               -> caminho de include
//
// NAO EXISTE "close". O estado e' um ponteiro sob GC (pplib.c:104, hb_pp_free no
// destrutor): ele morre quando a ultima referencia some. Por isso "init/close varias
// vezes" nao e' o modelo -- o modelo e' "quantos estados eu quiser, vivos ao mesmo
// tempo, cada um com as suas regras".

#include "hbtest.ch"

REQUEST __pp_StdRules

// regra do ARQUIVO: existe em tempo de COMPILACAO
#xcommand ECOA <x> => pa_Eco( <x> )

PROCEDURE Main()

   LOCAL pp, iso, outro

   /* ---------- o estado PADRAO x o estado VIRGEM ---------- */

   pp := __pp_Init()              // sem argumentos: regras padrao da linguagem
   iso := __pp_Init( , "" )       // cStdCh vazio: nenhuma regra

   // com as regras padrao, o `?` e' um #command do std.ch e expande
   HBTEST __pp_Process( pp, '? "oi"' ) IS 'QOut( "oi" )'

   // no estado virgem nao ha' regra nenhuma: o `?` fica como texto. Serve para
   // observar EXCLUSIVAMENTE as suas regras, sem a linguagem no meio.
   HBTEST __pp_Process( iso, '? "oi"' ) IS '? "oi"'

   /* ---------- os estados sao MUNDOS SEPARADOS ---------- */

   __pp_AddRule( pp, "#xcommand XX => yy()" )
   outro := __pp_Init()           // criado com o `pp` VIVO: aninhar e' so' ter dois

   // a regra vive no estado onde foi registrada...
   HBTEST __pp_Process( pp, "XX" ) IS "yy()"
   // ...e o outro estado nunca ouviu falar dela
   HBTEST __pp_Process( outro, "XX" ) IS "XX"

   // a MESMA cabeca pode ter regras DIFERENTES em estados diferentes, sem interferir
   __pp_AddRule( outro, "#xcommand XX => zz()" )
   HBTEST __pp_Process( pp, "XX" )    IS "yy()"
   HBTEST __pp_Process( outro, "XX" ) IS "zz()"

   /* ---------- __pp_Reset: derruba as SUAS regras, mantem a linguagem ---------- */

   __pp_Reset( pp )
   HBTEST __pp_Process( pp, "XX" ) IS "XX"                  // a sua regra sumiu...
   HBTEST __pp_Process( pp, '? "oi"' ) IS 'QOut( "oi" )'    // ...as padrao ficaram

   /* ---------- o pp de RUNTIME nao ve o pp da COMPILACAO ---------- */

   // Este arquivo declara `#xcommand ECOA`. Ela existe em tempo de compilacao -- a
   // linha abaixo prova, porque compilou e roda:
   HBTEST pa_Ecoou( 7 ) IS 7

   // ...mas o pp de runtime NAO a conhece: o texto volta intacto. Sao dois mundos --
   // o pp do compilador morreu com a compilacao, e o `__pp_Init` nasce sem saber nada
   // do seu arquivo.
   // CONSEQUENCIA PRATICA (e e' por isso que esta familia existe): toda fixture que
   // usa o pp vivo para provar uma expansao TEM de registrar a regra de novo com
   // __pp_AddRule. Sem isso ela nao esta' testando a diretiva -- esta' testando texto.
   HBTEST __pp_Process( __pp_Init(), "ECOA 1" ) IS "ECOA 1"

   RETURN

STATIC FUNCTION pa_Ecoou( n )
   LOCAL x
   ECOA n         // a regra do ARQUIVO: expandiu em tempo de compilacao
   x := pa_Eco( n )
   RETURN x

STATIC FUNCTION pa_Eco( x )
   RETURN x
