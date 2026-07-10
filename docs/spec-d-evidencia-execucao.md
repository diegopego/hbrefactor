# Spec Alavanca D — evidência de execução (funil de dispatch + gêmeo das macros)

Status: **PORTÃO FECHADO NA FORMA PROPOSTA (Diego, 2026-07-08).** A
camada `observed` anotando sites `possible` para priorizar conferência
manual é TRIAGEM — e a REGRA DO FATO (CLAUDE.md/O NORTE, mesmo dia)
estabelece: hbrefactor lida com fatos, meta ZERO INFERÊNCIA; fato
ausente → estender o core para o fato EXISTIR (caminho canônico: B9,
tipos impostos) ou usar ferramenta do core como oráculo. Este documento
fica como REGISTRO dos fatos re-auditados (o funil refinado
`hb_objGetMethod` etc.); evidência de execução só volta com um consumo
100% fato (ex.: alimentar cheques impostos), por decisão do Diego.

Texto original do portão (histórico):
Fase com MUDANÇA NO CORE (ganchos de 1 linha gated, padrão
B0) + consumo na ferramenta. Terceiro nível epistêmico — **confirmado
por execução: prova presença, nunca ausência; jamais misturado ao
estático** (mapa, alavanca D).

## Motivação (números pós-B7b)

A B7b fechou o que a inferência estática alcança com os fatos atuais
(delta no mapa: confirmed 25,6% → 27,4% no corpus). O que sobrou de
dominante NÃO é alcançável por compilação:

- **cls\*cast**: 2.260 sites de tortura de casting — classes montadas
  dinamicamente; são programas que RODAM (a evidência de execução os
  cobre por construção);
- blocos de GET/tbrowse cujos `Eval` vivem na RTL (fora do projeto);
- hbhttpd (M-cov 1): "local sem cadeia 132" dominado por sistema de
  classes próprio montado em runtime + objetos nascidos na VM (`oErr`).

## Fatos verificados no fonte (2026-07-08, re-auditados)

1. **O funil REAL é `hb_objGetMethod` (classes.c:1802)** — refinamento
   do mapa (que dizia `hb_vmSend`): a auditoria dos call sites mostra
   que TODA resolução de dispatch passa por ele, por três caminhos —
   `hb_vmSend` (hvm.c:6092; os opcodes `HB_P_SEND*` e as APIs
   `hb_objSendMessage`/`hb_vmEvalBlock` caem nela), `hb_vmDo` com Self
   objeto (hvm.c:6037) e `hb_objGetVarRef` para `@obj:var`
   (classes.c:2211→2229). As consultas `hb_objHasMsg`
   (classes.c:2460/2477) chamam com `pStack == NULL` e NÃO são
   dispatch — o filtro é o próprio argumento.
2. **Classe REAL do receptor**: `hb_objGetClsName( pSelf )` — o próprio
   VM a usa no `HB_TRACE_PRG` de hb_vmSend ("Calling: %s:%s").
3. **Site do chamador**: a pilha do VM é a mesma fonte de
   `ProcName()`/`ProcLine()` — proc+linha correntes no frame abaixo do
   novo (verificação fina do accessor barato é tarefa da fase).
4. **Macro — gate único**: `hb_macroCompile` (vm/macro.c:798); a árvore
   INTEIRA existe em macro.y:257-266 (`Main : Expression`, `$1`),
   construída pelo MESMO motor `hb_compExprNew*` do compilador; padrão
   de compartilhamento já existente: macroa.c
   (`#define HB_MACRO_SUPPORT` + `#include "hbexpra.c"`).
5. **Hot path**: `hb_objGetMethod`/`hb_vmSend` são o caminho mais
   quente do OOP — o gancho tem que custar UM teste de flag estática
   quando desligado; prova de custo por medição entra no critério.

## Desenho (fatias)

- **D-a (core, sends)**: gancho gated em `hb_objGetMethod` (1 linha,
  `pStack != NULL`, arquivo novo tipo `src/vm/vmexec.c` ou anexo ao
  compast — decidir na fase) registrando `(classe real do receptor,
  mensagem, módulo/proc/linha do site, contagem)` com DEDUP em memória;
  flush em `hb_vmQuit` → `<caminho>.astx.json` (schema `astx-1`, um por
  EXECUÇÃO, carimbado com data/argv).
- **D-b (core, macros)**: gancho gated em `hb_macroCompile`
  registrando `(string, exprType, flags HB_SM*, status)` no MESMO
  arquivo (seção própria) — fatia MÍNIMA; a árvore completa é a
  fatia 1 da spec-b8 (ast-7) e fica lá.
- **D-c (ferramenta)**: camada epistêmica nova no `usages`, só com
  `--evidence <arquivo(s)>`: `observed send (ran as CLASSE:MSG, n=N,
  run <carimbo>)` no site correspondente. NUNCA promove/rebaixa
  confirmed/excluded estáticos; site estático `possible` + evidência =
  as duas linhas de fato, cada uma com sua natureza.

## Decisões para o portão (recomendações marcadas)

- **D1 — forma do gate**: env var `HB_ASTEXEC=<caminho>` lida UMA vez
  no init do VM (recomendada: é runtime, não build; custo desligado =
  1 load+branch) × função de ativação exportada.
- **D2 — escopo do registro de macro**: mínimo string/tipo/status
  nesta fase (recomendado) × árvore completa (isso é a B8; não
  duplicar).
- **D3 — dedup+contagem em memória com flush no quit** (recomendado:
  tamanho O(sites distintos)) × stream bruto (cresce sem teto, mas não
  perde nada se o processo morrer — ver caveat do flush).
- **D4 — MT**: tabela única com seção crítica do HVM (recomendada para
  começar; medir) × tabelas por-thread com merge no quit.
- **D5 — consumo**: `usages --evidence` (recomendado) × comando novo
  de relatório.

## Critério de pronto (executável)

- **Zero impacto sem a env**: ganchos de 1 linha gated (padrão B0);
  não há mudança de pcode (`.hrb` byte-idênticos por construção —
  conferir mesmo assim); bench A/B de send apertado com diferença
  dentro do ruído, números REGISTRADOS.
- **cls\*cast rodando com `HB_ASTEXEC`**: o `usages --evidence` mostra
  `observed` nos sites que a estática deixa `possible`; delta
  registrado no mapa (a M-cov 2 ganha a coluna observed).
- Epistemologia intacta: nenhum confirmed/excluded muda por evidência;
  rótulo observed carrega n e o carimbo do run.
- Fixture executável + casos novos na suíte (o programa roda com o
  gancho e produz `.astx.json` determinístico para os asserts); caso
  MT (`hb_threadStart`) sem corrupção; suíte verde byte-idêntica
  paralelo × `JOBS=1`.
- Relink conferido (armadilha conhecida: `strings` no binário).

## Venenos e caveats

- Prova PRESENÇA, nunca ausência: cobertura = o que rodou; o rótulo
  nunca autoriza remoção/exclusão.
- `hb_hrbLoad()` RODA os INIT PROCEDUREs (runner.c) — harness de
  observação tem efeitos colaterais possíveis (caveat do mapa).
- Processo que morre sem `hb_vmQuit` perde o flush (documentar; flush
  periódico opcional ao custo de IO — decisão da fase se doer).
- Dedup por (classe, mensagem, site) perde ordem/tempo — irrelevante
  para refatoração; registrado.

## Fora do escopo

- Árvore de macro / ast-7 / `.astc.json` (spec-b8, na gaveta dela).
- Alavanca G / B9 (gaveta, decisões T1-T5 preservadas).
- Qualquer mistura estático × observado num veredito só.

## Adendo — observação do Diego (2026-07-10): debugger + `hb_compileFromBuf` como coletores

Registro da proposta (sessão do RE.5): *"se numa sessão de debug dá
para inspecionar tanta coisa, por que não usar essas ferramentas para
criar a AST? compilar com debug e navegar com hb_compileFromBuf
coletando a mesma informação; macro, é só avaliar/compilar em
runtime"*. Mapeamento honesto sobre os fatos já auditados:

- **O que a ideia acerta em cheio**: os DOIS coletores citados são
  CORE — usá-los é a REGRA DO FATO por definição ("usar ferramenta do
  core como oráculo"), não inferência. E a parte de MACRO é
  exatamente o gêmeo já registrado no mapa/B8: a AST de toda macro
  existe COMPLETA em runtime (macro.y:257; gate único vm/macro.c:798)
  e `hb_compileFromBuf` é o instrumento da fatia 2 da spec-b8 (sondar
  conteúdo rastreável). A intuição converge com duas gavetas que já
  têm spec: B8 (macros) e esta (alavanca D).
- **O que o debugger acrescenta de NOVO**: a dimensão dos VALORES — o
  gancho de debug (`hbdbginf.c`/entry points HB_DBG_*) vê a classe do
  objeto VIVO em cada linha executada, sem canal novo no core. É um
  candidato de IMPLEMENTAÇÃO para esta alavanca melhor que gancho
  inventado: infraestrutura oficial, gated por build, zero impacto
  sem `-b`. Fica registrado como candidato para QUANDO o portão
  reabrir.
- **O limite que não muda (o motivo do portão fechado)**: evidência de
  runtime é verdade CONDICIONAL — prova o que RODOU, com aqueles
  dados; nunca prova ausência nem cobre caminho não exercitado. Para
  ESTRUTURA em compile-time, o dump `-x` já colhe no único lugar onde
  a derivação de pp existe (dentro da compilação real, com os
  includes/defines que o hbmk2 resolveu) — navegar fonte com
  `hb_compileFromBuf` reproduziria essa colheita por fora, com o
  mesmo compilador mas sem o contexto de projeto, e é por isso que o
  dump continua sendo o canal da estrutura. O consumo de runtime que a
  REGRA DO FATO aceita segue o decidido aqui: alimentar FATO imposto
  (ex.: sugerir anotações que o `-kt` passa a checar — o ciclo
  virtuoso), jamais veredito estático.

Refinamento (Diego, mesma data): aumentar o lado IMPOSTO tem duas
fontes — entendimento profundo da arquitetura (lexer/parser/pp/
macrolex; foi o motor de (g), prólogo de bloco, chk) e ENGENHOSIDADE
com ferramentas do core: compilar/executar com `hb_compileFromBuf`,
pp ou debug os trechos que só rodariam em runtime. Candidato nomeado
que sai disso: **execução controlada como sugeridora do
materializador** — rodar em sandbox só o código de REGISTRO de
classes de runtime (top-level, tipicamente incondicional), ler a
tabela viva (`hb_clsName`/seletores) e materializar os `DECLARE`
correspondentes, que o `-kt` impõe dali em diante. A propriedade que
o viabiliza sob a REGRA DO FATO: **a imposição lavra a evidência
condicional** — o sandbox só SUGERE; o veredito é do cheque imposto
em toda execução real (retrato errado → BASE/3012 nomeando, como o
caso 90). Limites a espec-ar se abrir: sandbox/efeitos colaterais,
critério de seleção do que rodar (parente do problema da spec-b8),
relato com proveniência ("materializado a partir de execução de X").
Encaixe natural: fatia da B9 (segunda FONTE da sugeridora), não fase
nova. Alvo medido: o balde "classes de runtime" da M-cov (DSLs
__clsNew-puras; cls*cast, 2.260 sites). **Espec-ado (2026-07-10,
escopo aberto pelo Diego): a fatia 4 da B9 —
[spec-b9-fatia4-execucao-controlada.md](spec-b9-fatia4-execucao-controlada.md).**
