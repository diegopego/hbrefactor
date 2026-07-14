# Spec P — investigação exaustiva do pp para refatoração

**Este arquivo é o REGISTRO DE FASE: um veredito por fatia, curto.**
O **conhecimento sobre o pp** (mecânica, oráculos, limites) mora no corpus —
**[docs/pp-corpus/](pp-corpus/README.md)**, um arquivo por tema. O **contrato
técnico** dos canais mora no [ast-schema.md](ast-schema.md). As **regras de
trabalho** moram no [CLAUDE.md](../CLAUDE.md).

> **Regra de organização (ordem do Diego, 2026-07-12; esta spec já foi
> monolito e virou 832 linhas):** fato novo sobre o **pp** → **corpus**
> (família própria). Canal novo → **ast-schema**. Veredito de fatia → **aqui**,
> em um parágrafo, com link. Regra durável → **CLAUDE.md**. Não duplicar.

Portão aberto pelo Diego (2026-07-11); pré-requisito D-P0 (fase U fatia 2)
FECHADO. Escopo, eixos e critério de pronto no [roadmap § P](roadmap.md).
Achado que abriu a fase: [adr-003](adr-003-derivacao-pp-como-fato.md); tese
arquitetural (grafo de transformação): [adr-004](adr-004-grafo-transformacao-pp.md).

## O enquadramento (nota do Diego, 2026-07-11) — o pp É, em muitas formas, um refatorador

Não é uma boutade. O preprocessador do Harbour é um **motor de reescrita de
termos** em tempo de compilação: `#define`/`#[x]translate`/`#[x]command` são
regras **padrão → substituição** — casa uma FORMA no fonte, emite uma forma
TRANSFORMADA. É a definição de um refatorador. Duas consequências:

1. **O pp transforma padrões extremamente complexos.** De uma palavra escrita
   (`METHOD Info`) ele deriva, em múltiplos passes, um símbolo colado
   (`CAIXA_INFO`), uma string de registro (`"Info"`) e a entrada de
   `__clsAddMsg` que liga os dois. Multi-sítio, determinístico, disparado por
   um token.
2. **O pp já opera sobre TODO código Harbour** — é universal e canônico. Uma
   transformação expressa COMO regra de pp fala a mesma língua que o ecossistema
   inteiro já usa. É o insumo do **Eixo B**.

Isso NÃO afrouxa o preceito: o hbrefactor continua agindo só sobre FATO. O ponto
é que o "fato" e o "instrumento" moram no mesmo lugar — o motor de reescrita que
o pp já é.

---

# Vereditos por fatia

## Eixo A — fonte de fato

### P1 ✅ granularidade `paste` × `stringify` (2026-07-11)
`genOp` isolado **RECUSADO**: a resolução do kind usa o booleano `generates`
(ast-12) e a predição já lê a granularidade fina do rastro `from`; stringify não
exige `--force`. O `ast-13` foi para outra coisa — a **genealogia de regra** —
depois que a prova adversarial revelou a colisão de homônimo e **duas hipóteses
minhas caíram por execução**; a visão do Diego venceu: *o conserto era completar o
GRAFO*. Casos 51/52/107/108. Conhecimento: [derivation.md](pp-corpus/derivation.md),
[generated-rules.md](pp-corpus/generated-rules.md).

### P2 ✅ marker que GERA **e** passa adiante (2026-07-11)
Veredito **sem canal novo**: não há corrupção silenciosa porque a segurança é
**ESTRUTURAL** — a rede dupla (recompilação `-es2` + símbolos/identidade do `.hrb`)
confere o ARTEFATO COMPILADO FINAL, indiferente à multiplicidade e ao aninhamento.
Todo caso é rollback honesto OU re-derivação verificada. Caso 109 (fixture `fixp2`).
Conhecimento: [derivation.md](pp-corpus/derivation.md).

### P3 ✅ `generates` para `usages`/find-references (2026-07-12)
A hipótese grande do adr-003 **confirmada**: `usages --at` calculava o papel do site
e **jogava fora**, caindo numa busca cega por texto — um marker de pp e um símbolo
homônimo do seu código voltavam no MESMO blob. Agora estreita pelo papel. Zero core
(o fato já estava no dump). Caso 112. Resíduo: artefatos derivados como `Location`
no `--json`. Conhecimento: [derivation.md](pp-corpus/derivation.md).

### P4 + P5 ✅ os 15 mkinds EXAURIDOS (2026-07-12) — **um veredito CAIU (2026-07-13)**
13 com consumo provado, 2 com recusa documentada. **A recusa do `strdump` era FALSA**
(ele é o `#<x>`, e 31 regras do ecossistema o emitem — 6 no próprio `std.ch`): placar
corrigido para **14 consumidos, 1 recusado** (só o `dynval`, canal interno do pp).
Derrubada pela MEDIÇÃO, não por leitura — ver [pp-corpus/strdump.md](pp-corpus/strdump.md). O `<@>` desvendado: é o **guarda
anti-recursão**. Três consumos: `restrict` validado, `logical`/`nul` relatados, e
`wild`/marker-não-usado separado de palavra-de-regra **por FATO** — canal novo
**`ast-14`** no core, que **matou uma heurística de texto minha que o Diego pegou**.
Caso 111. Conhecimento: [markers.md](pp-corpus/markers.md),
[reference-guard.md](pp-corpus/reference-guard.md).

### P6 ✅ ESTRUTURA da regra (2026-07-12)
Três vereditos + um bug consertado. (a) **Regra sem cabeça**: funciona **por
construção** (a ferramenta nunca chaveou no `head`) — fecha o item 3 do backlog com
mais do que o "relato" que ele pedia. (b) **Opcionais reordenados**: o pp casa em
qualquer ordem; nenhuma posição se perde. (c) **Multi-passe**: o fecho atravessa as
passadas; **limite honesto** — palavra emitida no result de outra regra não tem
posição no fonte e a ferramenta recusa nomeando o motivo. (d) **A guarda de órfão
estava CEGA dentro de comando** (`--dry-run` aprovava o que o apply desfazia) —
consertada pelo fato `clone` × `paste`. Caso 113, fixture `fixp6`.
Conhecimento: [rule-structure.md](pp-corpus/rule-structure.md),
[derivation.md](pp-corpus/derivation.md).

## Eixo B — instrumento

### P7 ✅ o pp como INSTRUMENTO — **veredito PARTIDO, e CORRIGIDO pelo Diego** (2026-07-12)
- **Oráculo: VIÁVEL** — e uma perna **já estava em produção** sem ter sido nomeada:
  o padrão-ouro do `rename-dsl` (`.ppo` + `.hrb` byte-idênticos → rollback).
- **Escritor: recusei — e a recusa estava MAL FUNDAMENTADA.** Provei que o `.ppo`
  destrói comentários/`#include`/formatação (4 comentários → 0) e concluí
  "o pp não escreve fonte". O Diego apontou `tests/hbpp/hbpptest.prg`:
  **`__pp_init`/`__pp_process`** expõem o pp **vivo, in-process, LINHA A LINHA**.
  A destruição é propriedade do canal de **arquivo**, **não do pp** → a premissa
  cai. **Veredito corrigido:** a recusa vale para *`.ppo` como fonte*, e só.
  O pp como motor de reescrita é **viável** e vira a fatia **P11**.
- Conhecimento (e o catálogo dos canais): [pp-as-instrument.md](pp-corpus/pp-as-instrument.md).

## Eixo C — editar a regra

### P8 ✅ rename do nome de MARKER da regra (2026-07-12)
O `<n>` é **variável local da diretiva** → identidade = **(regra, NÚMERO do
marker)**, nunca o texto; o conjunto de edição sai do `ast-5` e mantém match e
result coerentes por construção. É um **alpha-rename**, o que dá a verificação mais
forte da ferramenta **de graça** (`.ppo`/`.hrb` obrigatoriamente byte-idênticos).
**O `.ch` deixou de ser inalcançável** — e aqui o Diego corrigiu um desvio meu: eu ia
responder "de quem é este include" pelo canal **mais barato** (o dump); o canal
**correto** já existia (**`harbour -gd`**, com caminho resolvido e fecho transitivo).
Caso 114. Conhecimento: [pp-as-instrument.md](pp-corpus/pp-as-instrument.md) § `-gd`.

## P-AUDIT — varredura anti-heurística

### 1º achado ✅ `ast-15` — e era um BUG (2026-07-12)
`AbbrevClash` **replicava a gramática** (abreviação dBase, `ppcore.c:2725`) e o
`RenameDsl` a usava para **adivinhar por prefixo** qual literal um site casou —
porque o dump só dizia `marker: 0`, nunca QUAL literal. Furo provado: keyword
secundária que é prefixo da cabeça → **recusa FALSA** → cabeça da DSL
**irrenomeável**. Conserto onde o fato nasce: o pp pareia token-fonte com token do
padrão ao casar e **descartava** o par do literal (a mesma omissão do `ast-14`, do
outro lado) → **`ruletok`**. `lexdiff` 0. Caso 115, fixture `fixabr`.
Conhecimento: [abbreviation.md](pp-corpus/abbreviation.md).

**Resíduo → fechado no P11.**

## P11 ✅ — o pp VIVO (`__pp_init`/`__pp_process`), 2026-07-12

O resíduo do `AbbrevClash` (predição de casamento **futuro**: *"o nome novo colidiria
sob abreviação?"*) morreu — não por aritmética melhor, mas **perguntando ao pp**:
registra-se uma **regra-sonda** (mesma cabeça, mesmo tipo) num pp isolado, alimenta-se
a grafia, vê-se se saiu transformada. A réplica escondia um **sequestro de regra
silencioso** que a rede `.ppo`/`.hrb` **não via** (a regra sequestrada podia não ter
site nenhum). Recusa-se só o que o rename **cria**; a recusa traz a **grafia-testemunha**.
Também **provada a equivalência** do pp vivo com o pp do build, e achado o limite
honesto — *o pp destrói o que você **alimenta**, não "o arquivo"* — o que **derruba de
vez a minha recusa do P7** (o Diego estava certo). Caso 116, fixture `fixseq`;
suíte 904/0, `ppcorpus` 42/0, **zero core**. Conhecimento:
[pp-as-instrument.md](pp-corpus/pp-as-instrument.md) ·
[abbreviation.md](pp-corpus/abbreviation.md).

## P9 ✅ — o custo do `generates` era QUADRÁTICO (2026-07-13)

O adr-003 registrava o custo como *"barato; um ponto a vigiar"* — **errado nos dois
adjetivos**, e a MEDIÇÃO era a entrega da fatia. A resposta *"este marker alimenta um
paste/stringify?"* era recalculada **por token**, varrendo o módulo inteiro a cada vez:
O(markers × módulo). Conserto no core (`compast.c`): o fato é propriedade do par
**(aplicação, marker)** → conjunto construído **uma vez por módulo**, token responde por
lookup. Virou **linear**, com os **847 dumps** do corpus **byte-idênticos** (otimização
que muda resposta é bug). **⚠️ E o ANÚNCIO mentiu:** publiquei o ganho do *stress
sintético* (uma expansão por linha — densidade que código real não tem) como se fosse o
produto, e ainda inventei que "16k linhas expandidas é tamanho de aplicação real". Medido
ponta a ponta em projeto real, o ganho é **~1/3 da espera**, não 330×. Os quatro anúncios
foram reescritos. Números e a lição no [roadmap § P9](roadmap.md); regra durável no
[CLAUDE.md](../CLAUDE.md).

## P10 ✅ — síntese: o adr-003 fecha, e a completude achou um BUG (2026-07-13)

**O [adr-003](adr-003-derivacao-pp-como-fato.md) está FECHADO** — as 5 perguntas têm
veredito, pelo critério que ele mesmo fixou. A que **inverte de sinal** é o
**acoplamento**: o ADR o listava como risco ("menos independência do pp"), e a fase provou
o contrário — **independência do core é o que PRODUZ réplica degradada** (cada
desacoplamento restante virou bug: `ast-15`, `ast-14`, a aritmética de colisão do P11, a
busca de include do P8). E "isto pode ser descoberta RUIM?" **passou por pouco**: o 2º
consumidor do `ast-12` apareceu por **BUG** (o `usages --at` estava errado sem o fato,
P3), não por elegância.

**O bug que a completude achou:** o canal `ast-16` entrou no core **sem versionar o
`HB_AST_SCHEMA`** — contrato mentindo, num campo que o NEWS manda o consumidor conferir. E
o conserto detonou o segundo: o `ReadAst` tinha **lista ENUMERADA** de versões aceitas, que
morre em silêncio a cada bump — a ferramenta **recusou o projeto inteiro**, dizendo *"dump
missing"* com o dump no lugar. **Um esquecimento escondia o outro.** O pior: o
`ast-schema.md` **já tinha essa lição** (bump `ast-8`: *"portão usa VERSÃO MÍNIMA, NUNCA
lista"*) **e abria exceção para o `ReadAst`** — **a exceção era o bug; regra excetuada não
é regra**.

**E o Diego foi mais fundo do que o meu conserto.** Eu troquei a lista por um **piso**
(`ast-2` para cima) — e piso ainda é compatibilidade, **com o quê?** *"Estamos fazendo a
AST sob demanda, então mexer no core é parte do trabalho e é normal; não existe esta busca
de compatibilidade — estamos INVENTANDO a ferramenta"*. O dump nasce **a cada comando**, do
`harbour` do `HB_BIN`: **não existe dump antigo**, existe **toolchain fora de passo** — e
isso se **BERRA**, não se degrada. Pior que peso morto: com um build velho, a escada
entregaria `possible` onde há `confirmed` — **rebaixando o veredito por causa de um build,
calada**. Hoje o schema é **EXATO** (`AstSchema()`), e as **5 funções + 23 sítios** de
degradação por versão **saíram** — nada na suíte dependia deles (964 checks passaram sem
tocar em um). O **caso 122** confere que o schema que a ferramenta fala é o que o binário
do core **realmente emite**: o esquecimento de bump vira **impossível de embarcar**.
Regra durável no [CLAUDE.md](../CLAUDE.md); contrato no [ast-schema.md](ast-schema.md).

**FASE P ENCERRADA.** Saldo: 4 canais novos no core (`ast-13`..`ast-16`), **zero heurística
nova** na ferramenta, e três erros meus registrados com nome — o custo que chamei de
"barato" sem medir (P9), a recusa que declarei sem varrer o core (P7), e o número do stress
publicado como se fosse o produto (P9).
