// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; cada afirmacao esta'
// provada por assert que passa PELA diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
// COMPLETUDE(2026-07-15): HOLE=P16
//   O loop dos 4 oraculos rodou ate' o fim: a AST NAO representa a provenancia do
//   dynval na camada de statement (literal sem 'from' de volta ao __LINE__) -> a
//   fase P16 fecha o buraco (populando 'from', como a familia derivation). O check
//   COMPLETUDE(ppc-dyn=HOLE:P16) em corpus_dyn e' o rastro executavel deste veredito.
//
// Familia DEFINE DINAMICO (docs/pp-corpus/dynval.md). As UNICAS duas regras de
// mkind `dynval` do pp sao BUILTIN -- o usuario nao as escreve:
//   ppcore.c:7253-7254 -> hb_pp_addDefine( __FILE__ ), hb_pp_addDefine( __LINE__ )
// O resultado da regra e' um ponteiro sentinela (nao texto); o pp o resolve na
// expansao para a POSICAO corrente do codigo.
//
// AS DUAS CAMADAS (METODO.md § 4) -- e aqui elas DISCORDAM, e a discordancia E'
// o achado da familia:
//   (A) o que a diretiva VIRA no pp VIVO -> __LINE__ COLAPSA para 1 e __FILE__
//       para "" : o pp de runtime nao tem arquivo nem posicao de linha, logo o
//       sentinela nao tem o que resolver. A camada A nao REPRODUZ a B -- ela a
//       DELIMITA por baixo (o valor sem posicao).
//   (B) o que ela VALE no BUILD -> __LINE__ SEGUE a linha corrente do fonte
//       (delta 1 entre linhas vizinhas) e __FILE__ e' o nome do arquivo.
// A distancia entre A e B e' exatamente a SENSIBILIDADE A POSICAO: mover codigo
// muda o valor de B, e nenhum verbo que desloque linhas pode alegar identidade
// de pcode num modulo assim.
//
// COMO COMPILAR/RODAR:
//   sintaxe:  harbour dynx.prg -n -q0 -w3 -es2 -s -I<core>/contrib/hbtest
//   rodar:    hbmk2  dynx.prg  <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbtest.ch"

PROCEDURE Main()

   LOCAL pp := __pp_Init()    // pp VIVO virgem: __FILE__/__LINE__ ja' sao builtin
   LOCAL n1, n2

   // ----- camada A: o pp VIVO nao tem arquivo -> o dynval COLAPSA -----
   // Sem file nem linha corrente para resolver o sentinela, __LINE__ vira 1 e
   // __FILE__ vira a string vazia. (apagar __LINE__/__FILE__ do texto quebra o
   // assert -- e' a diretiva builtin que produz o 1 e o "".)
   HBTEST AllTrim( __pp_Process( pp, "x := __LINE__" ) ) IS "x := 1"
   HBTEST AllTrim( __pp_Process( pp, "y := __FILE__" ) ) IS 'y := ""'

   // ----- camada B: no BUILD, o valor SEGUE a posicao -----
   // Duas expansoes em linhas VIZINHAS diferem de 1: o __LINE__ e' a linha
   // corrente do fonte, nao um numero escrito. Trocar por um literal quebra o
   // assert no dia em que alguem inserir/remover uma linha acima -- que e'
   // exatamente o acoplamento que a familia existe para nomear.
   n1 := __LINE__
   n2 := __LINE__
   HBTEST n2 - n1 IS 1
   // __FILE__ e' o nome do arquivo corrente (basename), resolvido no compilador.
   HBTEST __FILE__ IS "dynx.prg"

   RETURN
