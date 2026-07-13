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

### P4 + P5 ✅ os 15 mkinds EXAURIDOS (2026-07-12)
13 com consumo provado, 2 com recusa documentada (`strdump` vive na maquinaria de
STREAM; `dynval` é canal interno do pp). O `<@>` desvendado: é o **guarda
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
`AbbrevClash` **replicava a gramática** (abreviação dBase, `ppcore.c:2533`) e o
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

## P9 ✅ — o custo do reverse-scan do `generates` (2026-07-13)

O [adr-003](adr-003-derivacao-pp-como-fato.md) registrou o custo do `generates`
(`ast-12`) como *"barato no dump de um módulo; um ponto a vigiar"*. **Não era barato,
e o "ponto a vigiar" era uma parede** — achado por medição, que era a entrega desta
fatia.

**O que estava errado.** `hb_compAstMarkerGenerates` respondia a pergunta *"o valor
escrito neste marker alimenta um paste/stringify?"* com uma varredura reversa
**por token consultado**, e cada varredura percorria o fluxo de tokens INTEIRO **e**
todas as aplicações do pp. Como o número de tokens-marker consultados cresce junto
com o número de aplicações, isso é **O(markers × módulo)** — quadrático no tamanho do
módulo.

**A medição** (linhas de comando expandido, `harbour -x`, melhor de 3):

| N linhas | antes | depois |
|---:|---:|---:|
| 4 000 | 1,42 s | 0,05 s |
| 8 000 | 8,76 s | 0,09 s |
| 16 000 | **69,30 s** | **0,21 s** |
| 32 000 | (não medido) | 0,45 s |
| 64 000 | (não medido) | 0,94 s |

Dobrar N quadruplicava o tempo (assinatura de quadrática); agora dobrar N **dobra** o
tempo.

**⚠️ O 330× é do STRESS, não do dia a dia — e eu quase publiquei a mentira contrária.**
O stress tem **uma aplicação de pp por linha**, densidade que código Harbour real não
tem; o que dirige o custo é o **número de expansões**, não o de linhas. Escrevi no
CHANGELOG que 16 mil linhas expandidas são *"um tamanho ordinário em aplicação real"* —
**eu inventei isso** (o Diego pegou perguntando *"então por que você me disse que não
houve ganho no dia a dia?"*, e a resposta exigia medir a ferramenta INTEIRA, coisa que
eu não tinha feito). O pecado é o mesmo que a P9 flagrou: afirmar sem medir. A medição
ponta a ponta, comando completo, projetos reais do corpus (melhor de 2):

| projeto | módulos | antes | depois |
|---|---:|---:|---:|
| hbhttpd | 3 | 1,16 s | 1,07 s |
| gtwvg | 28 | 12,28 s | **7,49 s** |
| xhb | 42 | 12,35 s | **8,36 s** |

**O ganho real é ~1,4–1,6× (um terço da espera), não 330×** — e é ganho de verdade, mas
essa é a manchete honesta. O caso catastrófico é **patológico** (módulo denso em
expansão), e vale dizer que ele existe *sem* afirmar que o código do leitor é assim.

**O conserto (core, `compast.c`).** A resposta é propriedade do **par (aplicação,
marker)**, não do token — então o conjunto dos pares que geram é construído **uma vez
por módulo**, numa passada linear sobre as **mesmas duas fontes** que a varredura
antiga percorria (o fluxo de tokens sobrevivente e os tokens consumidos das
aplicações), e cada token responde por **lookup**. Nenhum canal novo, nenhum campo
novo, **nenhuma mudança de semântica**.

**A prova de equivalência é o ponto.** Otimização que muda resposta é bug: os
**847 dumps** do corpus (toda fixture da suíte + 6 módulos reais do core, incluindo
`debugger.prg` e `tbrowse.prg`) saem **byte a byte idênticos** ao binário anterior.
Suíte **961/0**, `lexdiff` 0 divergências reais.

**O que fica registrado como limite honesto:** o que sobra é linear e é dominado por
**escrever o JSON** (64 mil linhas produzem um dump de 107 MB). Se um dia doer, o
alvo é o tamanho do dump — não mais a busca do fato. *(O `-inc` do hbmk2 já dá dumps
incrementais; item 0c do backlog.)*

---

# Fatias em aberto

| fatia | o que é |
|---|---|
| **P9** | custo do reverse-scan `O(tokens × from)` (adr-003:96-98) |
| **P10** | síntese/completude da fase + atualização de adr-003, ast-schema, CHANGELOG |
| **P12** | **o pp como ENGENHO DE BUSCA** (ideia do Diego) — casar para ACHAR; plano em [pp-as-search.md](pp-corpus/pp-as-search.md) |
| **P-AUDIT** | continuar: `ResolveInclude`, os "se não é X então é Y", comparações de texto onde há id |
| **D-P5** | *(portão do Diego)* migração de DSL ganha verbo próprio? — **desbloqueado**: o instrumento (P11) está na mão |
