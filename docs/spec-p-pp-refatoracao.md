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

**Resíduo:** `AbbrevClash` segue vivo para a pergunta *diferente* ("o nome NOVO
colidiria sob abreviação?") — predição de casamento **futuro**, que o dump não
responde. Canal certo: perguntar ao pp (**P11**).

---

# Fatias em aberto

| fatia | o que é |
|---|---|
| **P9** | custo do reverse-scan `O(tokens × from)` (adr-003:96-98) |
| **P10** | síntese/completude da fase + atualização de adr-003, ast-schema, CHANGELOG |
| **P11** | **`__pp_process`/`hb_compileFromBuf`** — o pp in-process; reabre o P7 e mata o resíduo do `AbbrevClash` |
| **P-AUDIT** | continuar: `ResolveInclude`, os "se não é X então é Y", comparações de texto onde há id |
| **D-P5** | *(portão do Diego)* migração de DSL ganha verbo próprio? — decidir **depois** do P11 |
