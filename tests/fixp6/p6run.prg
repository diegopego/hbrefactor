// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; cada afirmacao esta' provada
// por assert que passa PELA diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
// COMPLETUDE(2026-07-15): COMPLETE
//   O loop dos 4 oraculos convergiu: a AST carrega a estrutura da regra -- a regra SEM
//   CABECA vem com head null, e o multi-passe fica em ppApplications (como no ppc-cycle).
//   O check COMPLETUDE(fixp6=COMPLETE) em corpus_rulestruct le' a AST e afirma isso.
//   (O selo mora aqui, no runner INERTE -- nao no p6.prg compartilhado com o contrato --
//    para nao deslocar os anchors do run.sh; o guarda le os dois .prg da familia.)
//
// Familia ESTRUTURA DA REGRA (fase P/P6), camada B. O irmao p6.prg e a guarda
// corpus_rulestruct provam a estrutura no DUMP (head null, match[], multi-passe); ESTE
// arquivo prova que as quatro formas compilam para CODIGO que RODA e VALE.
//
// COMO RODAR:  hbmk2 p6run.prg <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbtest.ch"
#include "p6.ch"

STATIC s_aRega

PROCEDURE Main()
   LOCAL nQtd := 21
   LOCAL nTot
   LOCAL aEsc

   // (1) regra SEM CABECA: o match comeca no marker <x>, nao numa palavra. O pp casa
   //     em QUALQUER statement que termine em ZORBADO; nTot recebe o dobro.
   nTot := nQtd ZORBADO
   HBTEST nTot IS 42

   // (2) grupos opcionais FORA DE ORDEM: a regra declara [ AGUA ] [ SOL ], o uso escreve
   //     SOL antes de AGUA -- o pp casa os dois e SLOTA cada um no lugar certo do result.
   REGA Flor SOL 3 AGUA "cheio"          // => rg_( "Flor", "cheio", 3 )
   HBTEST s_aRega[ 2 ] IS "cheio"        // AGUA -> cQ (2o arg), apesar de vir DEPOIS
   HBTEST s_aRega[ 3 ] IS 3              // SOL  -> nH (3o arg), apesar de vir ANTES

   // (3) grupo opcional AUSENTE vira NIL: VULK Escudo (sem KRAN nem PLIX) gera a funcao
   //     com os slots vazios.
   aEsc := vk_Escudo()
   HBTEST aEsc[ 1 ] IS "Escudo"
   HBTEST ValType( aEsc[ 2 ] ) IS "U"

   // (4) MULTI-PASSE: GLIMER Broquel expande para VULK Broquel KRAN "base", que so' num
   //     2o passe gera vk_Broquel(). O KRAN "base" veio da 1a expansao, nao do fonte.
   HBTEST vk_Broquel()[ 2 ] IS "base"

   RETURN

VULK Escudo
GLIMER Broquel

FUNCTION rg_( c, q, h )
   s_aRega := { c, q, h }
   RETURN s_aRega
