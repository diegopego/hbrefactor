<!-- guarda: corpus_store -->
# Família STORE (std.ch)

Índice: [README.md](README.md). Ensina: grupo opcional que REPETE
(multi-atribuição). Guarda: `corpus_store`; fixture `tests/ppc-store/storex.prg`.

Diretiva real ([include/std.ch:78](../../../harbour-core/harbour/include/std.ch)):

```harbour
#command STORE <v> TO <v1> [,<vN>]     => <v1> := [ <vN> :=] <v>
```

A multi-atribuição do Clipper. Um grupo opcional só — mas que **repete**.

## A fixture — a prova é EXECUTÁVEL (METODO-V2)

Duas camadas, em dois arquivos:

- **`tests/ppc-store/storex.prg`** (`hbtest` + pp vivo) —
  - camada A (o TEXTO): `__pp_Process` mostra `STORE 0 TO a` → `a := 0` e
    `STORE 9 TO a, b, c` → `a := b := c := 9`. Como `STORE` é comando de linguagem
    (`std.ch`), o estado **padrão** do pp já o conhece — nenhum `__pp_AddRule`
    (contraste com a família `<@>`, cuja regra era do arquivo);
  - camada B (o VALOR): `STORE 9 TO a, b, c` atribui o **mesmo** 9 às três
    variáveis — a cadeia, não três comandos.
- **`tests/ppc-store/storexdump.prg`** (raw-dumpável) — os fatos do dump: o `.ppo`
  com a cadeia, e o `[,<vN>]` como grupo opcional (`opt-open`/`opt-close`), `<vN>`
  **regular** dentro dele (não `mkind: "list"`).

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

> Classificação por FATO (não por raciocínio — cada item abaixo foi VERIFICADO
> rodando o dump; ver a evidência colada). Regra em [README.md](README.md).

- **[Consumo futuro — VERIFICADO] Cardinalidade do grupo.** A regra (`ppRules`)
  traz `opt-open`/`opt-close` sem dizer se repete; mas cada APLICAÇÃO
  (`ppApplications`) traz os tokens CONSUMIDOS, e ali a repetição aparece: no
  `STORE 9 TO a, b, c` o marker 2 (`vN`) surge **duas vezes**, cada uma com sua
  posição. Evidência:
  ```
  app da linha 8 (STORE 9 TO a, b, c) — tokens consumidos:
     marker=0 'STORE'   marker=3 '9'   marker=0 'TO'
     marker=1 'a' col=14
     marker=0 ','   marker=2 'b' col=17
     marker=0 ','   marker=2 'c' col=20
  ```
  A cardinalidade REAL é derivável por aplicação, e cada repetição é editável por
  posição → **não é info faltante**, é consumo que a ferramenta ainda não expõe
  (P6/P8). Nada a estender no core.
- **[Consumo futuro — VERIFICADO] List marker verdadeiro (`<x,...>`).** É um
  mecanismo DIFERENTE do grupo-que-repete, e o dump JÁ o exporta: uma regra
  `#xcommand PRINTALL <itens,...>` sai com `mkind='list'` no match, e os itens
  chegam individualmente posicionados nos tokens consumidos (`1` col=12, `2`
  col=15, `3` col=18). Fato presente, consumidor pendente (P4/P5) — família
  futura para contrastar com o grupo-que-repete.
