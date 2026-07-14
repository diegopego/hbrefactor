<!-- guarda: corpus_abbrev -->
# Família ABREVIAÇÃO dBase — a keyword pela metade (e o fato `ruletok`)

Índice: [README.md](README.md). Ensina: **em `#command`/`#translate` (as famílias
SEM `x`), o Harbour aceita a palavra da regra ABREVIADA** — herança do Clipper/dBase.
Isso torna "qual palavra da regra é este pedaço de código?" uma pergunta que **só o
pp** pode responder. Fixture: `tests/fixabr/`; prova: **caso 115**. Canal de core
nascido daqui: **`ast-15`** (`ruletok`).

---

## A regra, tirada do CORE (não de memória)

`ppcore.c:2725`, em `hb_pp_tokenEqual()`:

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

---

## A predição de casamento FUTURO — e o SEQUESTRO REVERSO (P11, caso 116)

O `ruletok` resolveu *"que literal este site casou?"*. Sobrava a pergunta gêmea, que
o dump **não** responde: *"o nome NOVO colidiria com a cabeça de OUTRA regra sob
abreviação?"* — casamento **futuro**, e o dump só descreve o que **casou**. A
ferramenta respondia replicando a aritmética do `ppcore.c` (o `>= 4`) — e a réplica
era **degradada em três frentes**: ignorava o **tipo do token** (o pp exige
`KEYWORD`), passava `"?"` como tipo da regra renomeada (desligando meia checagem) e
só enxergava *"uma cabeça é prefixo da outra"*.

**O furo (provado, não deduzido):**

```harbour
#command ROTULA <t>  => qq_( <t>, 0 )    // 6 letras, SEM NENHUM site no projeto
#command PAUTAR <x>  => qq_( <x>, 1 )
```

Renomear `PAUTAR` → `ROTULAGEM` era **ACEITO**. E aí as grafias de `ROTULA` passavam
a casar a regra **renomeada** — perguntado ao próprio pp, com as duas regras
registradas (`qq_( …, 1 )` é o corpo da regra RENOMEADA; o de `ROTULA` é
`qq_( …, 0 )`):

```
ROTULA 9  -->  qq_( 9, 1 )     // ← nem o nome INTEIRO escapa
ROTU 9    -->  qq_( 9, 1 )
```

A regra vizinha era **sequestrada**, em silêncio — inclusive quando escrita **por
extenso**. E a rede de verificação
(`.ppo`/`.hrb` byte-idênticos) **não via nada**: como a regra sequestrada não tinha
**nenhum site**, não havia diferença a observar. A ferramenta chegava a imprimir
*"verified: byte-identical"*. A ambiguidade ficava **latente** — quebrava no próximo
site que alguém escrevesse.

**O conserto: perguntar ao pp** ([pp-as-instrument.md](pp-as-instrument.md)). Num pp
isolado registra-se uma **regra-sonda** com aquela cabeça e aquele tipo, alimenta-se
a grafia, e vê-se se saiu transformada. Nenhum limiar no fonte da ferramenta.

**Completude sem constante mágica:** toda grafia que casa uma cabeça é **prefixo**
dela (o `hb_pp_tokenValueCmp` compara por prefixo no modo dBase e por igualdade nos
demais) — então varre-se **todo** prefixo do nome novo e deixa-se o **pp** dizer
quais casam. Se o limiar do Harbour mudasse amanhã, a ferramenta continuaria certa.

**Só se recusa a ambiguidade que o rename CRIA.** A que já existia é do código do
usuário — e existe de verdade: duas cabeças com prefixo comum de 4 letras já se
disputam hoje (`MENUITEM`/`MENUBOX` → escrever `MENU` já é ambíguo **antes** de
qualquer rename). Recusar por isso seria punir o usuário por uma condição que não
foi a ferramenta que criou.

A recusa agora exibe a **testemunha** — a grafia concreta:

```
$ hbrefactor rename seq.hbp seq.prg:4:4 ROTULAGEM
hbrefactor: 'ROTULAGEM' colide por abreviação com a regra #command ROTULA (seq.ch:1)
            - depois do rename, escrever 'ROTU' casaria com as DUAS regras
```

---

## Lacunas (VERIFICADO)

- **[Fechada — P11]** A predição de casamento futuro deixou de ser réplica: quem
  responde é o pp vivo. Fixture `tests/fixseq/`; prova: **caso 116**.
