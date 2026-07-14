// METODO-V2(2026-07-14): comentario INTERPRETA o oraculo; cada afirmacao esta'
// provada por assert que passa pela diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
//
// Fixture da familia ORDEM DAS REGRAS (docs/pp-corpus/rule-order.md).
// Pergunta do Diego (2026-07-14): "tem uma ordem de execucao nestes casos e nao me
// lembro se e' do primeiro para o ultimo ou o contrario".
//
// COMO COMPILAR:
//   sintaxe:  harbour od.prg -n -q0 -w3 -es2 -s -I$HB_CORE/contrib/hbtest
//   rodar:    hbmk2  od.prg $HB_CORE/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi
//
// A RESPOSTA, e ela esta' no fonte (ppcore.c, registro de regra):
//
//     pRule->pPrev = pState->pCommands;   // a regra NOVA entra na CABECA da lista
//     pState->pCommands = pRule;
//
// ...e a busca comeca pela cabeca. Logo: A ULTIMA REGRA DECLARADA E' TENTADA
// PRIMEIRO. E' pilha (LIFO), nao especificidade -- a regra mais especifica NAO tem
// prioridade nenhuma: quem ganha e' quem nasceu depois.

#include "hbtest.ch"

REQUEST __pp_StdRules

// a mesma forma multilinha, mas em tempo de COMPILACAO: `;` continua a diretiva,
// `;;` separa os statements que ela emite
#xcommand DOIS <a> <b> => ;
   AAdd( s_aOrdem, <a> ) ;; ;
   AAdd( s_aOrdem, <b> )

STATIC s_aOrdem

PROCEDURE Main()

   LOCAL pp, ordem1, ordem2

   /* ---------- 1. duas regras que casam o MESMO texto: quem vence? ---------- */

   // Estado virgem, para so' as minhas regras existirem. Declaro a `regular` e depois
   // a `wild` -- as duas casam `ECO 5`.
   ordem1 := __pp_Init( , "" )
   __pp_AddRule( ordem1, '#xcommand ECO <x>   => od_( "regular", <x> )' )
   __pp_AddRule( ordem1, '#xcommand ECO <*x*> => od_( "wild", <x> )' )

   // vence a ULTIMA registrada
   HBTEST __pp_Process( ordem1, "ECO 5" ) IS 'od_( "wild", 5 )'

   // Agora o mesmo par, na ordem INVERTIDA. Se o criterio fosse "a mais especifica
   // ganha", o resultado seria o mesmo dos dois lados. Nao e': ele VIRA.
   ordem2 := __pp_Init( , "" )
   __pp_AddRule( ordem2, '#xcommand ECO <*x*> => od_( "wild", <x> )' )
   __pp_AddRule( ordem2, '#xcommand ECO <x>   => od_( "regular", <x> )' )

   HBTEST __pp_Process( ordem2, "ECO 5" ) IS 'od_( "regular", 5 )'

   /* ---------- 2. e' isto que faz o hbclass funcionar ---------- */

   // O hbclass.ch declara uma regra GENERICA de METHOD que AVISA ("method not
   // declared") -- e cada CLASS GERA, em tempo de pp, as regras especificas daquele
   // metodo. Como as geradas nascem DEPOIS, sao tentadas ANTES: o metodo declarado
   // casa a sua regra; o nao-declarado escorrega para a generica e leva o aviso.
   //
   // Em miniatura: a generica primeiro, a fabrica de regras depois.
   pp := __pp_Init( , "" )
   __pp_AddRule( pp, '#xcommand MET <m> => od_( "GENERICA (nao declarado)", #<m> )' )
   __pp_AddRule( pp, '#xcommand DECLARA <m> => #xcommand MET <m> => od_( "especifica", #<m> )' )

   // antes de declarar, `MET Pinta` cai na generica -- a unica que existe
   HBTEST __pp_Process( pp, "MET Pinta" ) IS 'od_( "GENERICA (nao declarado)", "Pinta" )'

   // a linha DECLARA nao gera codigo: gera uma REGRA (a tabela e' o unico estado que
   // atravessa -- ver docs/pp-corpus/no-eval.md)
   HBTEST __pp_Process( pp, "DECLARA Pinta" ) IS ""

   // ...e agora `MET Pinta` casa a regra RECEM-NASCIDA, porque ela esta' na cabeca da
   // lista. O metodo declarado deixou de cair no aviso.
   HBTEST __pp_Process( pp, "MET Pinta" ) IS 'od_( "especifica", "Pinta" )'

   // ...enquanto um metodo que ninguem declarou continua caindo na generica
   HBTEST __pp_Process( pp, "MET Sumiu" ) IS 'od_( "GENERICA (nao declarado)", "Sumiu" )'

   /* ---------- 3. multilinha: `;` continua a diretiva, `;;` separa statements ---------- */

   // Uma diretiva pode ocupar varias linhas com `;` no fim -- continua sendo UMA regra.
   // Ja' o `;;` dentro do RESULTADO e' o separador de STATEMENT: e' assim que UMA
   // diretiva entrega DUAS linhas de codigo.
   __pp_AddRule( pp, "#xcommand PAR <a> <b> => od_( 1, <a> ) ;; od_( 2, <b> )" )

   // Repare no que o pp devolve: o `;;` continua LA'. O pp nao quebra a linha -- ele
   // entrega o texto com o separador dentro, e quem o parte em dois statements e' o
   // COMPILADOR. (Mais uma vez: o pp mexe em texto; o significado e' do compilador.)
   HBTEST __pp_Process( pp, "PAR 7 8" ) IS "od_( 1, 7 ) ;; od_( 2, 8 )"

   // ...e compilado de verdade, o mesmo `;;` vira dois statements: os dois rodam.
   // (a regra abaixo esta' declarada no topo do arquivo, em tempo de compilacao)
   // (o hbtest compara array por REFERENCIA, entao aqui se afere elemento a elemento)
   s_aOrdem := {}
   DOIS 11 22
   HBTEST Len( s_aOrdem ) IS 2
   HBTEST s_aOrdem[ 1 ]   IS 11
   HBTEST s_aOrdem[ 2 ]   IS 22

   RETURN


