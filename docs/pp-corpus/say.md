# Família `@ … SAY` (std.ch)

Índice: [README.md](README.md). Ensina: grupos OPCIONAIS (`opt-open`/`opt-close`)
no match E no result, e seleção de forma. Guarda: `corpus_say`; fixture
`tests/ppc-say/sayx.prg`.

Diretiva real ([include/std.ch:249](../../../harbour-core/harbour/include/std.ch)):

```harbour
#command @ <row>, <col> SAY <exp> [PICTURE <pic>] [COLOR <clr>] => ;
         DevPos( <row>, <col> ) ; DevOutPict( <exp>, <pic> [, <clr>] )
#command @ <row>, <col> SAY <exp> [COLOR <clr>] => ;
         DevPos( <row>, <col> ) ; DevOut( <exp> [, <clr>] )
```

O `@ … SAY` clássico. Duas regras, cinco markers, grupos OPCIONAIS `[…]` no que
casa E no que emite.

## A fixture (`tests/ppc-say/sayx.prg`) — compila limpo sob `-w3 -es2`

```harbour
PROCEDURE Main()
   LOCAL nX := 42, cName := "Ana"
   @ 1, 1 SAY "Ola"
   @ 2, 1 SAY nX PICTURE "999"
   @ 3, 1 SAY nX PICTURE "999" COLOR "R/W"
   @ 4, 1 SAY cName COLOR "W/B"
   RETURN
```

## `.ppo` / `.ppt` (cada forma expande diferente conforme o que você escreveu)

```
@ 1, 1 SAY "Ola"                       ->  DevPos( 1, 1 ) ; DevOut( "Ola" )
@ 2, 1 SAY nX PICTURE "999"            ->  DevPos( 2, 1 ) ; DevOutPict( nX, "999" )
@ 3, 1 SAY nX PICTURE "999" COLOR "R/W" -> DevPos( 3, 1 ) ; DevOutPict( nX, "999", "R/W" )
@ 4, 1 SAY cName COLOR "W/B"           ->  DevPos( 4, 1 ) ; DevOut( cName, "W/B" )
```

## Os roles do dump (ast-5) — grupos opcionais viram `opt-open`/`opt-close`

```
match:  @  row  ,  col  SAY  exp  [ opt-open PICTURE pic opt-close ] [ opt-open COLOR clr opt-close ]
result: DevPos ( row , col ) ; DevOutPict ( exp , pic [ opt-open , clr opt-close ] )
```

## Explicação

**Técnica.** `[ … ]` é um GRUPO OPCIONAL (roles `opt-open`/`opt-close`). A 1ª
regra tem dois no match (`[PICTURE]`, `[COLOR]`) e um no result (`[, <clr>]`) que
só emite se `<clr>` casou. Seleção de forma: `PICTURE` casa a 1ª regra
(→ `DevOutPict`); sem `PICTURE`, a 2ª (→ `DevOut`); `COLOR` sem `PICTURE` (linha 4)
cai na 2ª, que também tem seu `[COLOR]`.

**Para o programador Harbour.** Aquele `@ 1,1 SAY x PICTURE "999" COLOR "R/W"`
vira `DevPos()` (posiciona) + `DevOut()`/`DevOutPict()` (escreve). `PICTURE` e
`COLOR` são OPCIONAIS — põe um, outro, os dois ou nenhum, e o pp monta a chamada
certa. Não existe "comando @ SAY" no compilador; existe uma regra em std.ch — e
suas próprias diretivas com `[…]` funcionam igual.

## Lente de refatoração

As posições `row`/`col`/`exp`/`pic`/`clr` são recheios de marker; `@`/`SAY`/
`PICTURE`/`COLOR` são palavras da regra builtin. O ensino é o FATO de GRUPO
OPCIONAL: é o mesmo que o hbrefactor consome para entender uma DSL SUA com partes
opcionais — o dump reconstrói o grupo por pilha, editável na posição certa (P8).

## Lacunas (o que os oráculos NÃO mostram)

- **[Consumo futuro] Qual grupo opcional casou, por aplicação.** O `.ppo` prova o
  resultado e o `ppApplications` traz os tokens CONSUMIDOS com o nº do marker — de
  onde "o `[PICTURE]` casou, o `[COLOR]` não" é DERIVÁVEL (presença do recheio
  `pic`/`clr`). Não é info faltante; é consumo que a ferramenta ainda não expõe
  como fato de 1ª classe (candidato a P5/P6). Verificado que é derivável do dump
  atual → NÃO é lacuna de core.
