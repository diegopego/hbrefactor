// COMPLETUDE(2026-07-15): COMPLETE
//   O loop dos 4 oraculos convergiu: a AST exporta o guarda <@> como mkind 'reference'.
//   Ele vem SEM nome e SEM posicao por CORRECAO -- e' maquinaria anti-recursao, nao ha'
//   simbolo do usuario para renomear. O que a ferramenta precisa saber (que a regra
//   carrega o guarda no result[]) esta' na AST. O check COMPLETUDE(ppc-ref=COMPLETE)
//   em corpus_ref le' a AST e afirma isso.
// METODO-V2(2026-07-14): comentario INTERPRETA o oraculo; cada afirmacao esta'
// provada por assert que passa PELA diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
//
// Familia <@> - o GUARDA ANTI-RECURSAO (docs/pp-corpus/reference-guard.md).
// Idioma real do core: contrib/hbfoxpro/hbfoxpro.ch:63 estende o PUBLIC do
// Harbour REEMITINDO a propria palavra PUBLIC. Isso seria um loop infinito -- a
// saida comeca por PUBLIC, que casa a mesma regra outra vez. O <@> e' o que
// impede a reemissao de re-casar a regra.
//
// AS DUAS CAMADAS (METODO.md § 4), e a UTILIDADE de cada uma:
//   (A) o que a diretiva VIRA -> o pp VIVO (__pp_Process): o TEXTO que a regra
//       emite, e a prova de que a regra circular TERMINA. Sem o <@>, a MESMA
//       regra ergue E0022 -- e' a camada A que prova que o guarda e' necessario.
//   (B) o que a diretiva VALE -> o valor em runtime (hbtest): o PUBLIC de escopo
//       de arquivo casou em tempo de COMPILACAO, terminou, e o __DIM colou o := 7.
//
// COMO COMPILAR/RODAR:
//   sintaxe:  harbour refx.prg -n -q0 -w3 -es2 -s -I<core>/contrib/hbtest
//   rodar:    hbmk2  refx.prg  <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbtest.ch"

REQUEST __pp_StdRules

// A regra circular, no escopo do ARQUIVO (exercita a camada B na compilacao).
// O __DIM aqui aplica ":= 7" para o efeito da regra ser OBSERVAVEL em runtime; no
// hbfoxpro o __FP_DIM (identidade para escalar, hbfoxpro.ch:60) dimensiona arrays.
#xtranslate __DIM( <exp> ) => <exp> := 7
#command PUBLIC <var1> [, <varN> ] => ;
         <@> PUBLIC __DIM( <var1> ) [, __DIM( <varN> ) ]

MEMVAR nA, nB

PROCEDURE Main()

   LOCAL pp := __pp_Init( , "" )       // estado virgem: so' as MINHAS regras, sem a linguagem

   // ----- camada B: o VALOR (a regra casou na compilacao e TERMINOU) -----
   // `PUBLIC nA, nB` casou a regra guardada acima: ela reemitiu PUBLIC atras do
   // <@> e o __DIM colou o ":= 7". Apagar o #command PUBLIC devolve o PUBLIC de
   // estoque e nA valeria .F.; apagar o #xtranslate __DIM nem compila. O 7 so'
   // existe porque as DUAS diretivas expandiram -- e porque o <@> deixou a
   // expansao TERMINAR (senao o compilador nunca teria chegado a esta linha).
   PUBLIC nA, nB
   HBTEST nA IS 7
   HBTEST nB IS 7

   // ----- camada A: o TEXTO (o pp vivo mostra o que a regra VIRA, e que TERMINA) -----
   // Registro as MESMAS regras no estado vivo -- o pp de runtime nao conhece as do
   // arquivo (pp-api.md). __pp_Process reescreve o texto SEM executar. A saida e'
   // `PUBLIC nA := 7, nB := 7`: a regra convergiu, e o <@> nao aparece nela. O
   // guarda e' significativo para o PP e invisivel para quem le a saida (o token
   // reference e' liberado do fluxo de saida em ppcore.c:7019).
   __pp_AddRule( pp, "#xtranslate __DIM( <exp> ) => <exp> := 7" )
   __pp_AddRule( pp, "#command PUBLIC <var1> [, <varN> ] => <@> PUBLIC __DIM( <var1> ) [, __DIM( <varN> ) ]" )
   HBTEST AllTrim( __pp_Process( pp, "PUBLIC nA, nB" ) ) IS "PUBLIC nA := 7, nB := 7"

   // A MESMA regra SEM o <@>: a saida comeca por PUBLIC e torna a casar a propria
   // regra. O pp detecta e ergue E0022 "Circularity detected" (subCode 22 -- a
   // mesma trava do #pragma RECURSELEVEL, familia pass-cycle). E' a prova de que o
   // guarda nao e' enfeite: sem ele, a regra nunca converge.
   HBTEST ref_Circulou( __pp_Init( , "" ) ) IS .T.

   RETURN

// Roda a regra SEM guarda num estado isolado e devolve .T. se o pp ergueu a
// circularidade. O BEGIN SEQUENCE captura o loop -- ele nao e' esperado, e' preso.
STATIC FUNCTION ref_Circulou( pp )
   LOCAL lErgueu := .F., oErr
   __pp_AddRule( pp, "#xtranslate __DIM( <exp> ) => <exp> := 7" )
   __pp_AddRule( pp, "#command PUBLIC <var1> [, <varN> ] => PUBLIC __DIM( <var1> ) [, __DIM( <varN> ) ]" )
   BEGIN SEQUENCE WITH {| e | Break( e ) }
      __pp_Process( pp, "PUBLIC nA, nB" )
   RECOVER USING oErr
      lErgueu := ( oErr:subCode == 22 )   // 22 = E0022, "Circularity detected"
   END SEQUENCE
   RETURN lErgueu
