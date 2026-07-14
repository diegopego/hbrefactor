// Fixture da familia STRDUMP (docs/pp-corpus/strdump.md). Compila limpo sob
// -w3 -es2 (regua do caso 0). DSL inventada, NAO-espelho das do core.
//
// O que esta fixture prova NAO e' "aqui e' simbolo, ali e' texto" -- isso seria
// uma leitura MINHA do conteudo que eu escolhi escrever. O que ela prova e' o
// FATO que separa os dois, porque o `generates` SOZINHO nao separa: o recheio de
// SELO e o de LAVRA chegam ao dump IGUAIS (marker 1, generates: true), mesmo
// quando o texto e' o mesmo. Quem separa e' a OP da derivacao (tokens[].from):
//
//   SELO nLastro   -> ops: clone + stringify  -- o token TAMBEM chega ao
//                     compilador (`nLastro := ...`): e' o LOCAL, e mais a string
//   LAVRA nLastro  -> ops: stringify APENAS   -- a palavra NUNCA vira simbolo;
//                     e' texto que so' PARECE o nome do local (colisao)
//
// Sem o par de casos abaixo (`LAVRA fundo de reserva` e `LAVRA nLastro`) a
// separacao ficaria afirmada e nao provada.

#include "sd.ch"

PROCEDURE Main()

   LOCAL nLastro

   // (a) clone + stringify: o `<v>` emite a variavel E o `#<v>` emite o nome dela
   SELO nLastro AFERIDO

   // (b) stringify APENAS: texto cru, nenhum simbolo envolvido
   LAVRA fundo de reserva

   // (c) stringify APENAS -- mas o texto COLIDE com o nome do local acima.
   //     O fato e' o mesmo do (b): sem clone, isto nao e' o local. Renomear
   //     `nLastro` NAO pode tocar esta linha (seria editar por coincidencia
   //     de nome -- exatamente o que a ferramenta existe para nao fazer)
   LAVRA nLastro

   ? nLastro

   RETURN

STATIC FUNCTION sd_Afere( cNome )
   RETURN Len( cNome )

STATIC FUNCTION sd_Lavra( cTexto )
   ? cTexto
   RETURN NIL
