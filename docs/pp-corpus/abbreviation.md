# Família ABREVIAÇÃO dBase — a keyword pela metade (e o fato `ruletok`)

Índice: [README.md](README.md). Ensina: **em `#command`/`#translate` (as famílias
SEM `x`), o Harbour aceita a palavra da regra ABREVIADA** — herança do Clipper/dBase.
Isso torna "qual palavra da regra é este pedaço de código?" uma pergunta que **só o
pp** pode responder. Fixture: `tests/fixabr/`; prova: **caso 115**. Canal de core
nascido daqui: **`ast-15`** (`ruletok`).

---

## A regra, tirada do CORE (não de memória)

`ppcore.c:2533`, em `hb_pp_tokenEqual()`:

```c
( pToken->len == pMatch->len ||
  ( mode == HB_PP_CMP_DBASE && pMatch->len > 4 &&
    pToken->len >= 4 && pMatch->len > pToken->len ) )
```

Ou seja, a keyword escrita casa abreviada quando:
- o modo é **`HB_PP_CMP_DBASE`** — o das famílias **sem `x`** (`#command`,
  `#translate`). As famílias com `x` usam `HB_PP_CMP_STD` = **exato**;
- a palavra da REGRA tem **mais de 4** letras;
- o que você escreveu tem **4 ou mais** letras e é **mais curto** que a da regra;
- e é prefixo dela (case-insensitive, `hb_pp_tokenValueCmp`).

```harbour
#command APAGAR <x> => zz_( <x> )

APAG 3        // casa: APAG é abreviação válida de APAGAR
APA  3        // NÃO casa: menos de 4 letras
```

É por isso que `SET EXACT ON` também aceita `SET EXAC ON`, e por que o dialeto
antigo do Clipper é cheio de comandos escritos pela metade.

---

## Por que isso QUEBRA quem adivinha por texto (o furo real)

Considere uma regra cuja keyword **secundária** é prefixo de 4+ letras da **cabeça**:

```harbour
#command GRAVAR <x> GRAV <y> => zz_( <x>, <y> )
...
   GRAVAR 1 GRAV 2      // GRAV aqui é a keyword da regra, escrita POR EXTENSO
```

Olhando só o TEXTO, `GRAV` é ambíguo: pode ser *a keyword `GRAV` inteira* **ou**
*a cabeça `GRAVAR` abreviada*. As duas leituras são gramaticalmente plausíveis.

**O pp SABE a diferença — ele casou.** Mas o dump não contava: cada token consumido
vinha só com `marker: 0` ("é um literal da regra"), **nunca QUAL literal**. Sobrava
adivinhar pelo texto — e a adivinhação erra:

```
$ hbrefactor rename ab.hbp ab.prg:3:4 SALVAR
hbrefactor: uso abreviado 'GRAV' ... - normalize para 'GRAVAR' antes do rename
```

Uma **recusa FALSA**, pedindo para "normalizar" um site que **já estava
normalizado** — e o efeito prático era que **a cabeça daquela DSL ficava
irrenomeável**.

---

## O fato que faltava: `ast-15` / `ruletok`

Onde o fato nasce: `hb_pp_patternMatch()` **pareia** cada token-fonte com o token
do padrão enquanto casa — e **descartava** o par quando o padrão era um literal
(só registrava via `hb_pp_patternAddResult()` quando havia índice de marker).
**É a mesma omissão do `ast-14`, do outro lado do balcão.**

Agora cada token consumido carrega **`ruletok`** = o índice, no `match[]` da regra,
do literal que ele casou:

```jsonc
"match": [ {"text":"GRAVAR"}, {"text":"x"}, {"text":"GRAV"}, {"text":"y"} ]
                 [0]              [1]           [2]            [3]

"tokens": [ { "text":"GRAVAR", "marker":0, "ruletok":0 },   // ← a cabeça
            { "text":"1",      "marker":1 },
            { "text":"GRAV",   "marker":0, "ruletok":2 },   // ← o literal #2, NÃO a cabeça
            { "text":"2",      "marker":2 } ]
```

A pergunta *"o literal que este site casou É a palavra que estou renomeando?"* vira
**fato**, e a aritmética de prefixo sai do caminho de decisão. Gated por
`fTrackPos` (build default byte-a-byte intocado; `lexdiff` 0).

Contrato completo: [../ast-schema.md](../ast-schema.md) § `ppApplications`.

---

## Lacunas (VERIFICADO)

- **[LACUNA real — em aberto]** *"O nome NOVO colidiria com a cabeça de OUTRA regra
  sob abreviação dBase?"* é predição sobre casamento **FUTURO** — o dump descreve o
  que **casou**, não o que casaria. Hoje o hbrefactor responde isso replicando a
  aritmética do `ppcore.c:2533` numa função própria (`AbbrevClash`) — **réplica de
  gramática**, divergência esperando acontecer. O canal correto é **perguntar ao
  próprio pp** (`__pp_init`/`__pp_process`) em vez de reimplementá-lo: ver
  [pp-as-instrument.md](pp-as-instrument.md) e a fatia **P11** do roadmap.
