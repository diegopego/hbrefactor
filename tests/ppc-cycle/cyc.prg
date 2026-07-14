// METODO-V2(2026-07-14): revisado pelo metodo novo -- comentario INTERPRETA o
// oraculo (nao o transcreve), e o que ele afirma esta' provado por assert ou
// pelo dump. Prova: o pp esgota o comando antes de avancar; o teto e' configuravel.
// (regua: docs/pp-corpus/METODO.md § 4b)
// Fixture da familia CICLO DO PP (docs/pp-corpus/pass-cycle.md).
//
// COMO COMPILAR:
//   sintaxe:  harbour cyc.prg -n -q0 -w3 -es2 -s -I$HB_CORE/contrib/hbtest
//   rodar:    hbmk2  cyc.prg $HB_CORE/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi
//
// O ASSUNTO: o pp nao faz "uma passada" pelo arquivo. Ele pega um comando e o
// reprocessa ATE' NINGUEM MAIS CASAR -- so' entao avanca para o proximo.
//
// No fonte do core (ppcore.c:6587) o laco e' explicito:
//
//     pState->iCycle = 0;                              // zera A CADA comando
//     while( ! ISEOC( pTokenList ) && iCycle <= iMaxCycles ) {
//        if( hb_pp_processDefine( ... ) )    continue;  // casou? volta ao INICIO
//        if( hb_pp_processTranslate( ... ) ) continue;
//        if( hb_pp_processCommand( ... ) )   continue;
//        break;                                         // ninguem casou: acabou
//     }
//
// Tres coisas caem daqui, e as tres tem consequencia:
//
//   1. A ORDEM e' fixa: #define, depois #translate, depois #command. E, a cada
//      substituicao, o pp VOLTA AO INICIO da cadeia -- um #command pode emitir algo
//      que um #define vai comer no passe seguinte.
//
//   2. O contador ZERA por comando. O limite nao e' do arquivo: e' de cada linha.
//
//   3. O limite existe e e' generoso -- HB_PP_MAX_CYCLES = 4096 (hbpp.h:412) -- e e'
//      CONFIGURAVEL por `#pragma RECURSELEVEL=<n>`. Estourou, o pp acusa
//      CIRCULARIDADE (E0022) e deixa o token por expandir. A guarda corpus_cycle
//      prova isso compilando uma copia desta cadeia com RECURSELEVEL=2: ela FALHA.

#include "hbtest.ch"

// uma cadeia de quatro regras: cada uma emite a proxima
#xcommand E1 => E2
#xcommand E2 => E3
#xcommand E3 => E4
#xcommand E4 => cy_Marca( "fim" )

STATIC s_cUltimo

PROCEDURE Main()

   // Escrevo E1. O compilador recebe cy_Marca( "fim" ).
   // No .ppt a linha aparece QUATRO vezes seguidas -- E1>E2, E2>E3, E3>E4, E4>cy_Marca --
   // e so' depois disso o traco passa para a linha seguinte. O pp esgotou o comando.
   E1
   HBTEST s_cUltimo IS "fim"

   // Este assert vale mais do que parece: se o pp fizesse UMA passada por linha, o
   // compilador teria recebido `E2` -- um simbolo que nao existe -- e nada disto
   // compilaria. O programa so' roda porque a cadeia foi esgotada.
   HBTEST cy_Ultimo() IS "fim"

   RETURN

STATIC FUNCTION cy_Marca( c )
   s_cUltimo := c
   RETURN NIL

STATIC FUNCTION cy_Ultimo()
   RETURN s_cUltimo
