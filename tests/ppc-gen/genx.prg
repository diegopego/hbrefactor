// METODO-V2(2026-07-15): comentario INTERPRETA o oraculo; cada afirmacao esta'
// provada por assert que passa PELA diretiva. (regua: docs/pp-corpus/METODO.md § 4b)
//
// Familia REGRA QUE GERA REGRA (docs/pp-corpus/generated-rules.md) - uma diretiva
// CRIA outra diretiva em tempo de pp. E' o mecanismo por dentro do hbclass (cada
// METHOD gera a regra que reconhece a impl). Fixture NAO-espelho (regua caso 64).
//
// AS DUAS CAMADAS (METODO.md § 4):
//   (A) o que a diretiva VIRA -> pp vivo, em DOIS passos: processar DEFREGRA GERA a
//       regra USA no estado (a saida e' VAZIA -- DEFREGRA emite uma DIRETIVA, nao
//       codigo; o efeito e' registrar a regra), e o passo seguinte JA casa a regra
//       recem-nascida. E' rule-generates-rule provado no pp vivo.
//   (B) o que a diretiva VALE -> runtime: DEFREGRA/USA rodam na compilacao e a USA
//       expandida atribui o valor.
//
// COMO COMPILAR/RODAR:
//   sintaxe:  harbour genx.prg -n -q0 -w3 -es2 -s -I<core>/contrib/hbtest
//   rodar:    hbmk2  genx.prg  <core>/contrib/hbtest/hbtest.hbc -w3 -es2 -gtcgi

#include "hbtest.ch"

REQUEST __pp_StdRules

// A diretiva GERADORA: DEFREGRA <n> emite um `#xcommand USA <n>` -- uma regra nova.
#xcommand DEFREGRA <n> => #xcommand USA <n> => s_xUltimo := Marca( <"n"> )

PROCEDURE Main()

   LOCAL s_xUltimo
   LOCAL pp := __pp_Init( , "" )    // virgem: so' a MINHA regra geradora

   // ----- camada A: rule-generates-rule NO pp VIVO -----
   __pp_AddRule( pp, '#xcommand DEFREGRA <n> => #xcommand USA <n> => s_xUltimo := Marca( <"n"> )' )
   // Passo 1: processar DEFREGRA nao devolve CODIGO -- ele emite uma DIRETIVA
   // (#xcommand USA Ponto), que o pp REGISTRA e nao imprime. A saida vazia e' o
   // sinal de que houve mudanca de ESTADO (uma regra a mais), nao de texto.
   HBTEST AllTrim( __pp_Process( pp, "DEFREGRA Ponto" ) ) IS ""
   // Passo 2: a regra recem-nascida JA casa -- USA Ponto vira a atribuicao. E' a
   // prova, no pp vivo, de que uma diretiva criou outra e ela entrou em vigor.
   HBTEST AllTrim( __pp_Process( pp, "USA Ponto" ) ) IS 's_xUltimo := Marca( "Ponto" )'

   // ----- camada B: o VALOR (as duas diretivas rodam na compilacao) -----
   DEFREGRA Ponto              // gera a regra USA Ponto
   USA Ponto                   // ...que expande para s_xUltimo := Marca( "Ponto" )
   HBTEST s_xUltimo IS "Ponto"
   // Outro nome: o gerador faz uma regra NOVA por nome (USA Linha != USA Ponto).
   DEFREGRA Linha
   USA Linha
   HBTEST s_xUltimo IS "Linha"

   RETURN

FUNCTION Marca( c )
   RETURN c
