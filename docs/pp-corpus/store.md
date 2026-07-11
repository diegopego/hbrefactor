# Família STORE (std.ch)

Índice: [README.md](README.md). Ensina: grupo opcional que REPETE
(multi-atribuição). Guarda: `corpus_store`; fixture `tests/ppc-store/storex.prg`.

Diretiva real ([include/std.ch:78](../../../harbour-core/harbour/include/std.ch)):

```harbour
#command STORE <v> TO <v1> [,<vN>]     => <v1> := [ <vN> :=] <v>
```

A multi-atribuição do Clipper. Um grupo opcional só — mas que **repete**.

## A fixture (`tests/ppc-store/storex.prg`) — compila limpo sob `-w3 -es2`

```harbour
PROCEDURE Main()
   LOCAL a, b, c
   STORE 0 TO a
   ? a
   STORE 9 TO a, b, c
   ? a, b, c
   RETURN
```

## `.ppo` / `.ppt` (o grupo opcional casa UMA VEZ POR variável extra)

```
STORE 0 TO a          ->  a := 0
STORE 9 TO a, b, c    ->  a := b := c := 9
```

## Os roles do dump (ast-5) — `vN` é `regular`, não `list`

```
match:  STORE  v  TO  v1  [ opt-open , vN(marker regular) opt-close ]
result: v1  :=  [ opt-open vN(marker regular) := opt-close ]  v
```

## Explicação

**Técnica.** Não é um "marker de lista" (`<x,...>`, mkind `list`) — `<vN>` é
`regular` DENTRO de um grupo opcional `[,<vN>]`. A lista vem do pp casar o grupo
**repetidamente**: `, b` e `, c` são duas repetições, e o result `[ <vN> :=]`
emite uma cópia por repetição. Contraste com o `@ … SAY`: lá o opcional casava 0
ou 1 vez (presença); aqui casa N vezes (repetição). O dump mostra os dois iguais
(`opt-open`/`opt-close`); o `.ppo` é quem revela a repetição.

**Para o programador Harbour.** `STORE 0 TO a, b, c` vira `a := b := c := 0` —
atribuição em cadeia. O `[,<vN>]` aceita quantas variáveis quiser, cada uma vira
um `:=`. É o mesmo grupo opcional do `@ … SAY`, só que se repete — e é assim que
quase toda sintaxe de "lista" do Clipper (STORE, REPLACE `f WITH x, g WITH y`) é
feita.

## Lente de refatoração

Um grupo opcional REPETÍVEL é o fato que o hbrefactor precisa para não se perder
numa DSL sua com cláusulas repetidas (`ADD campo, campo, campo`). O dump o entrega
achatado (reconstruível por pilha) e o `.ppo` prova o resultado.

## Lacunas (o que os oráculos NÃO mostram)

- **[Consumo futuro] Cardinalidade do grupo no dump ESTÁTICO.** A regra
  (`ppRules`) traz `opt-open`/`opt-close` sem dizer se repete; mas cada APLICAÇÃO
  (`ppApplications`) traz os tokens consumidos — `a, b, c` aparecem lá, então a
  cardinalidade REAL é derivável por aplicação. A regra estática não a prevê, o
  dump da aplicação sim → não é info faltante. Vira `ast-N` só se P6/P8 pedir a
  cardinalidade como fato de 1ª classe (consumidor ainda inexistente).
- **[Consumo futuro] List marker verdadeiro (`<x,...>`, mkind `list`)** — outro
  mecanismo (ex.: `DO … WITH <p,...>`), já exportável pelo ast-5; família futura
  para contrastar com o grupo-que-repete.
