// METODO-V2(2026-07-14): comentario INTERPRETA o oraculo; cada afirmacao esta'
// provada por assert que passa pela diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
//
// Fixture da familia O QUE O PP *NAO* FAZ (docs/pp-corpus/no-eval.md).
//
// COMO COMPILAR:
//   sintaxe:  harbour ev.prg -n -q0 -w3 -es2 -s -I$HB_CORE/contrib/hbtest
//   rodar:    hbmk2  ev.prg $HB_CORE/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi
//
// O ASSUNTO -- e ele existe porque e' um erro que se comete o tempo todo ao raciocinar
// sobre preprocessador: achar que ele AVALIA o codigo, ou que "acumula estado" a cada
// passada pela linha. Ele nao faz nem uma coisa nem outra.
//
//   o pp SUBSTITUI TEXTO. Ele nao soma, nao compara, nao conhece valor de variavel,
//   nao executa nada. O que ele entrega ao compilador e' texto -- e e' o COMPILADOR
//   que depois decide o que aquilo significa.
//
//   A UNICA excecao e' a condicao de diretiva (`#if`), onde o pp tem um calculador
//   proprio de constantes (hb_pp_calcOperation, ppcore.c) -- e e' so' ali.
//
//   E o "estado" dele nao e' acumulado por passada: e' a TABELA DE REGRAS, que muda
//   quando ele encontra uma linha de diretiva. Por isso a POSICAO importa.

#include "hbtest.ch"

REQUEST __pp_StdRules

#define N  2 + 3

#if 2 + 3 == 5
   #define O_IF_CALCULOU .T.
#else
   #define O_IF_CALCULOU .F.
#endif

STATIC s_n

PROCEDURE Main()

   LOCAL pp

   /* ---------- 1. o pp NAO avalia: ele cola TEXTO ---------- */

   // A armadilha classica, e ela e' o coracao desta familia.
   // `#define N 2 + 3` NAO define "o numero cinco": define os TRES TOKENS `2 + 3`.
   // Ao escrever `N * 2`, o compilador recebe `2 + 3 * 2` -- e ai' vale a precedencia
   // dele: multiplica primeiro. Da' OITO.
   // Se o pp avaliasse (5 * 2), daria dez. Ele nao avalia.
   // (repare na saida do teste: o rotulo do hbtest e' o `#<x>` da expressao, e ele
   //  imprime `2 + 3 * 2` -- ou seja, o proprio relatorio mostra o texto ja' colado)
   HBTEST N * 2 IS 8

   // Com o parenteses, o texto colado fica `( 2 + 3 ) * 2` -- e agora sim, dez.
   // Nada mudou no pp: mudou o TEXTO que ele produziu.
   HBTEST ( N ) * 2 IS 10

   /* ---------- 2. ...mas a CONDICAO de diretiva ele calcula ---------- */

   // O `#if 2 + 3 == 5` la' em cima foi AVALIADO -- pelo calculador interno do pp, que
   // so' existe para condicao de diretiva. Se ele fosse texto colado, nao haveria como
   // escolher um ramo.
   // Entao a frase correta nao e' "o pp nao avalia nada": e' "o pp nao avalia o SEU
   // CODIGO -- ele avalia a condicao das PROPRIAS diretivas".
   HBTEST O_IF_CALCULOU IS .T.

   /* ---------- 3. o "estado" e' a TABELA DE REGRAS, e ela e' posicional ---------- */

   // Um estado virgem: nenhuma regra.
   pp := __pp_Init( , "" )

   // Antes de a regra existir, o texto passa INTACTO. Nao ha' "uma passada que aprende":
   // a tabela simplesmente nao tem nada para casar.
   HBTEST __pp_Process( pp, "CONST" ) IS "CONST"

   // A diretiva e' o que MUDA a tabela...
   __pp_AddRule( pp, "#define CONST 42" )

   // ...e a partir dai' o mesmo texto casa. Note o que isso significa no seu arquivo:
   // um `#define` so' vale para as linhas DEPOIS dele. A posicao da diretiva e' semantica.
   HBTEST __pp_Process( pp, "CONST" ) IS "42"

   // E o pp continua sem avaliar: o valor colado e' texto ate' o fim.
   __pp_AddRule( pp, "#define SOMA 2 + 3" )
   HBTEST __pp_Process( pp, "s_n := SOMA * 2" ) IS "s_n := 2 + 3 * 2"

   /* ---------- 4. #xcommand e #xtranslate: idem -- so' TEXTO ---------- */

   // Nao e' privilegio do #define. Um #xcommand recebe `2 + 3` como TRES tokens e os
   // repassa; ninguem soma nada em lugar nenhum.
   __pp_AddRule( pp, "#xcommand CALC <a> <b> => s_n := <a> + <b>" )
   HBTEST __pp_Process( pp, "CALC 2 3" ) IS "s_n := 2 + 3"

   // ...e o #xtranslate tambem. (A diferenca entre eles e' ONDE casam -- comando so'
   // no comeco da linha, translate em qualquer lugar --, nunca o que fazem: colar.)
   __pp_AddRule( pp, "#xtranslate DOBRO( <x> ) => ( <x> ) * 2" )
   HBTEST __pp_Process( pp, "s_n := DOBRO( 2 + 3 )" ) IS "s_n := ( 2 + 3 ) * 2"

   /* ---------- 5. A PERGUNTA: numa cadeia, ha' estado que se salve? ---------- */

   // Uma cadeia de tres regras. Cada passe reescreve o TEXTO; nada mais atravessa.
   // O passe intermediario nao guarda valor, nao guarda contador, nao guarda nada:
   // ele so' entrega uma linha nova para o passe seguinte reprocessar.
   __pp_AddRule( pp, "#xcommand P1 <x> => P2 <x>" )
   __pp_AddRule( pp, "#xcommand P2 <x> => P3 <x>" )
   __pp_AddRule( pp, "#xcommand P3 <x> => s_n := <x>" )
   HBTEST __pp_Process( pp, "P1 7" ) IS "s_n := 7"

   // EXISTE, sim, UM estado que se salva -- e e' o unico: a TABELA DE REGRAS.
   // Uma regra pode EMITIR uma diretiva, e essa diretiva MUDA a tabela. O efeito
   // sobrevive a' linha: e' a unica coisa que uma transformacao "grava".
   __pp_AddRule( pp, "#xcommand GRAVA <n> => #define GRAVADO <n>" )

   // antes de a diretiva ser emitida, `GRAVADO` nao existe: passa intacto
   HBTEST __pp_Process( pp, "GRAVADO" ) IS "GRAVADO"

   // a linha `GRAVA 9` nao produz codigo nenhum -- ela produz uma REGRA
   HBTEST __pp_Process( pp, "GRAVA 9" ) IS ""

   // ...e a partir daqui a tabela mudou: o mesmo texto passa a casar
   HBTEST __pp_Process( pp, "GRAVADO" ) IS "9"

   // Resumo do que atravessa uma cadeia de transformacoes:
   //   valores          -> NAO (o pp nao avalia)
   //   acumuladores     -> NAO (nao ha' onde guardar)
   //   a tabela de regras -> SIM, e so' ela

   RETURN
