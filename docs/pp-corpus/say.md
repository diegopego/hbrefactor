<!-- guarda: corpus_say -->
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

> Classificação por FATO (não por raciocínio — VERIFICADO rodando o dump; ver a
> evidência). Regra em [README.md](README.md).

- **[Consumo futuro — VERIFICADO] Qual grupo opcional casou, por aplicação.** O
  `ppApplications` traz os tokens CONSUMIDOS, e a **keyword do grupo opcional
  aparece lá quando (e só quando) o grupo casou**. Evidência (as 4 linhas da
  fixture, `(marker, texto)`):
  ```
  linha 6  @ 1,1 SAY "Ola"              -> [(0,'@'),(1,'1'),(0,','),(2,'1'),(0,'SAY'),(3,'Ola')]
  linha 7  ... PICTURE "999"            -> ... (0,'SAY'),(3,'nX'),(0,'PICTURE'),(4,'999')
  linha 8  ... PICTURE "999" COLOR "R/W"-> ... (0,'PICTURE'),(4,'999'),(0,'COLOR'),(5,'R/W')
  linha 9  ... COLOR "W/B"              -> ... (0,'SAY'),(3,'cName'),(0,'COLOR'),(4,'W/B')
  ```
  Dá para ler exatamente qual casou: linha 6 nenhum, linha 7 só `PICTURE`, linha 8
  os dois, linha 9 só `COLOR`. **Não é info faltante** → nada a estender no core; é
  consumo que a ferramenta ainda não expõe como fato de 1ª classe (P5/P6).
