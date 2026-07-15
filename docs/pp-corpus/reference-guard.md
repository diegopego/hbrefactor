<!-- guarda: corpus_ref -->
# Família `<@>` — o guarda anti-recursão (o marker mais obscuro do pp)

Índice: [README.md](README.md). Ensina: **como uma regra pode emitir a PRÓPRIA
palavra que ela casa sem entrar em loop infinito**. Guarda: `corpus_ref`; fixture
`tests/ppc-ref/refx.prg`.

> Nota de método: eu quase enterrei este marker dizendo que "não tem uso nenhum" —
> com base num `grep` que **falhou** (erro de glob). O Diego insistiu que era
> importante e mandou procurar em `.ch`, `.prg` e `.txt`. Estava certo. **Comando
> que falha não é evidência de ausência.**

## O problema que ele resolve: a REGRA CIRCULAR

Imagine querer estender o `PUBLIC` do Harbour para aceitar uma sintaxe extra. O
jeito natural é uma regra que casa `PUBLIC` e **reemite `PUBLIC`** com o argumento
transformado:

```harbour
#command PUBLIC <var1> [, <varN> ] => PUBLIC __DIM( <var1> ) [, __DIM( <varN> ) ]
```

Isso é um **loop infinito**: a saída começa com `PUBLIC`, que casa a mesma regra,
que emite `PUBLIC` de novo… para sempre. O pp precisaria de um jeito de dizer
*"esta saída já passou por aqui, não re-aplique"*.

## A solução: `<@>`

```harbour
#command PUBLIC <var1> [, <varN> ] => ;
         <@> PUBLIC __DIM( <var1> ) [, __DIM( <varN> ) ]
```

O `<@>` no início do resultado emite um **token especial** que:
1. **carrega o padrão de match da regra** (ppcore.c:5528 — `( *pTokenPtr )->pMTokens =
   pRule->pMatch;`), e é isso que permite ao pp saber "esta saída veio desta regra,
   não a re-aplique";
2. é **descartado antes do compilador** (ppcore.c:7019 — o token de tipo
   `HB_PP_RMARKER_REFERENCE` é liberado do fluxo de saída) — invisível no código final.

Palavras do autor, no ChangeLog do core (2010-08-19, Przemysław Czerpak):

> *"added new result marker `<@>` which creates token **significant for PP but
> invisible for compiler**. This extension allows to **resolve problem with circular
> rules** in very easy way"*

## Uso REAL no Harbour

`contrib/hbfoxpro/hbfoxpro.ch:63` — o dialeto FoxPro estende `PUBLIC`/`PRIVATE`
exatamente assim:

```harbour
#command PUBLIC <var1> [, <varN> ] => ;
         <@> PUBLIC __FP_DIM( <var1> ) [, __FP_DIM( <varN> ) ]
```

É raro (2 usos em todo o core) — mas é o que torna possível **estender um comando
existente do Harbour sem quebrá-lo**.

## A fixture — a prova é EXECUTÁVEL (METODO-V2)

Duas camadas, em dois arquivos:

- **`tests/ppc-ref/refx.prg`** (`hbtest` + pp vivo) — prova o que o guarda **VIRA** e
  **VALE**, com asserts que rodam:
  - camada A (o TEXTO): `AllTrim( __pp_Process( pp, "PUBLIC nA, nB" ) )` devolve
    `"PUBLIC nA := 7, nB := 7"` — a regra circular **converge**; e a MESMA regra
    **sem** o `<@>` ergue `E0022 "Circularity detected"` (é este assert que prova que
    o guarda é necessário, não enfeite);
  - camada B (o VALOR): o `PUBLIC nA, nB` de escopo de arquivo casou a regra guardada
    em tempo de compilação → `nA == 7`. Apagar qualquer uma das duas diretivas quebra
    o assert (a régua do METODO: assert tem de passar PELA diretiva).
- **`tests/ppc-ref/refxdump.prg`** (raw-dumpável, sem `hbtest`) — os fatos que só o
  dump mostra: o `.ppo` sem o guarda, o `.ppt` com a reemissão de `PUBLIC` atrás do
  `<@>`, e o marker `mkind: "reference"`.

## O `.ppo` — o guarda some antes do compilador

```
PUBLIC nA, nB
```

Nenhum sinal do `<@>`. Ele fez seu trabalho (impedir o re-casamento) e desapareceu.
Sem ele, o compilador nunca chegaria a ver esta linha — o pp ficaria em loop.

## O fato do dump (ast-5)

```
result da regra PUBLIC:
   marker  mkind='reference'  text='~'  col=null     <- o guarda
   literal 'PUBLIC'  literal '__DIM'  marker 'var1'  ...
```

Repare: **sem nome e sem posição** (`text: "~"`, `col: null`). Não é um marker que
você nomeia — é um sinal.

## Lente de refatoração

**A ferramenta o preserva por construção** — e isso não é sorte, é arquitetura: ela
edita regra **por posição de byte**, e o guarda **não tem posição**. É intocável.

Prova executável: renomear a palavra `__DIM` dentro da regra guardada
(`rename-dsl`) editou as duas ocorrências no result **e** a cabeça da regra
`__DIM`; o `<@>` ficou intacto, o projeto seguiu compilando sem loop, e a
verificação fechou **`.ppo` e `.hrb` byte-idênticos**. Se algo tivesse perturbado o
guarda, a rede `.ppo` teria pego.

## Lacunas (o que os oráculos NÃO mostram)

> Classificação por FATO. Regra em [README.md](README.md).

- **[Consumo futuro — VERIFICADO] Nada a renomear, mas nada a avisar também.** O
  `<@>` não tem nome nem posição → não há operação de rename possível sobre ele
  (nem faria sentido). A ferramenta não o menciona ao editar uma regra guardada.
  Se um dia a fase P8 (edição ESTRUTURAL da regra) permitir mover/reordenar peças
  do result, aí sim o `<@>` vira restrição de 1ª classe ("não pode sair da
  frente") — hoje, sem edição estrutural, não há como perdê-lo. Fato presente no
  dump (`mkind: "reference"`), consumidor só quando P8 existir.
