# Roadmap — hbrefactor sobre AST do compilador (v3 enxuto, 2026-07-07)

Responsável pela ferramenta: Claude (planejamento, implementação,
verificação); decisões de produto e autorizações (commits, PR upstream):
Diego. Regra de manutenção: **este documento é vivo** — fase futura só
começa com escopo e critério de pronto escritos; fase concluída ganha UMA
linha no índice de entregues e o registro completo vai para o arquivo.
Fluxos definidos vivem em **Makefile**; hbmk2 direto é só experimentação.

Histórico: [roadmap-v2-arquivado.md](roadmap-v2-arquivado.md) (smoke
test), **[roadmap-fases-entregues.md](roadmap-fases-entregues.md)**
(narrativa integral das fases B0-B4f-3, congelada na limpeza de
2026-07-07). Mapa permanente do alcançável:
[limites-e-alavancas.md](limites-e-alavancas.md).

> **bravo-experimento: FORA DO ESCOPO (ordem do Diego, 2026-07-05).**
> Corpus de validação: fixtures da suíte + work/hbhttpd. Projetos grandes
> de produção só quando o Diego liberar.

## O NORTE (ordem do Diego, 2026-07-07 — regra durável no CLAUDE.md)

O Harbour inteiro se apoia em diretivas de pp para criar açúcar sintático.
O hbrefactor refatora **QUALQUER construto criado por diretiva** — do
core ou inventado pelo programador no próprio aplicativo — sem ajuste
por-caso. **Classes/hbclass são SÓ UM CASO**, jamais o alvo do desenho.
Fato faltante → fato de compilação ou relato honesto; ajeito é
inaceitável. Régua executável: casos 64 e 72-74.

**A REGRA DO FATO — META: ZERO INFERÊNCIA (Diego, 2026-07-08; revoga a
escada "inferência antes de linguagem" do mesmo dia).** O hbrefactor
lida com fatos; heurística e TRIAGEM não são produto. Fato ausente →
estender o CORE para o fato existir (canal/invariante novo — tipos
impostos da spec-b9 são o exemplo canônico) ou usar ferramenta do core
como oráculo — nunca construir inferência nova. **CORE = o projeto
Harbour oficial INTEIRO** (Diego, 2026-07-08): não só o compilador —
hbrun, hbmk2, hbpp, RTL/VM, utilitários e o resto da árvore oficial
contam como core para estender ou usar. A inferência entregue
(B7/B7b) converge para SUGERIDORA de anotações (ciclo virtuoso:
materializar `AS CLASS` provados → core impõe → veredito vira fato), não
para fonte de veredito de longo prazo. Regra completa no CLAUDE.md.

**AVISO (Diego, 2026-07-07)**: commits das eras B4e/B4f-2/extensão foram
feitos com enquadramento hbclass-cêntrico — há código, specs e testes a
revisar. O instrumento é
**[revisao-generalidade.md](revisao-generalidade.md)** (achados V1-V7
verificados + checklist Q1-Q8 executável). **REVISÃO CONCLUÍDA em
2026-07-07** (casos 75-81 + atualizações; o documento fica como registro
e régua para trabalho futuro).

## Fundação (provada no smoke test + B0/B1; não re-derivar)

Compilador como oráculo (ganchos de 1 linha gated, `.hrb` byte-idêntico
sem `-x`); editor ≠ verificador (recompilar, comparar, rollback); hbmk2
como resolvedor de projeto; fixtures como contrato de comportamento;
réplica sintática na ferramenta é proibida (a fonte da verdade é o
compilador). Dump por módulo `.ast.json` (schema atual **ast-6**), specs
de consumo em [ast-schema.md](ast-schema.md) — LER antes de mexer.

## Fases entregues (registro completo no [arquivo](roadmap-fases-entregues.md))

| Fase | Entrega (1 linha) |
|------|-------------------|
| B0+B1 (2026-07-05) | Mecanismo `-x` no core + fundação da ferramenta; lexdiff 0 divergências reais; occ↔ast paridade total |
| B2 (2026-07-05) | 11 comandos re-assentados na AST (renames, extract, reorder, usages `--json`); run.sh novo |
| B3 (2026-07-05) | reorder multi-linha; `inline-local` com pureza pela árvore do compilador |
| B4 (2026-07-06) | `ppRules`/`ppApplications` (ast-2); `rename-dsl`; usages de palavra de DSL; lifting; S1-S5 |
| B4b (2026-07-06) | memvars: mapa de visibilidade no usages; `rename-memvar` fecho-fechado; WorkDir atômico (R1) |
| B4c (2026-07-06) | rename-method por âncoras de forma — **MORTAS na B4d** (registro histórico) |
| B4d (2026-07-06) | Rastro de derivação `from` (ast-3); `rename-pp-marker` genérico; G1-G7; âncoras por forma removidas |
| B4e (2026-07-06) | Comandos cientes de construtos (P0-P3, extract-para-método) — **generalidade só provada em hbclass: ver revisão Q1-Q3/Q7** |
| B4f (2026-07-06) | Canal de tipos da linguagem (ast-4); camadas confirmed/excluded/possible no usages |
| B4f-2 (2026-07-07) | Resolução de dispatch (`ResolveDispatch`); homônimos; declarações vinculadas à dona; extensão v0.5.0 — **`ClassParentsSeq`/methodQuery: ver revisão Q4/Q5** |
| B4f-3 (2026-07-07) | PROVA da generalidade: DSLs inventadas com homônimos, comandos embrulhando classes, cstruct real, escrita `o:x`, construtos não-classe (casos 72-74; suíte 467/0) |
| B4g (2026-07-07) | A regra POR DENTRO (ast-5): `match[]`/`result[]`; usages nomeia sites em regra; rename-dsl de qualquer palavra do match (reancoragem textual morta); rename-function `--edit-rules` (caso 74 acionável); resolve-at em diretiva; extensão 0.7.0; ADR-001; suíte 555/0 |
| B-infra Etapa 1 (2026-07-07) | Suíte paralela: pool bash por-caso, saída byte-idêntica, 10/10 sem flake, 109 s → 11-14 s (~8×); `JOBS=1` p/ depurar |
| B-infra Etapa 2 (2026-07-08) | Runner em Harbour: despacho+join `tests/parrun.prg` (`hb_processOpen`) + checker `tests/tcheck.prg` (`hb_jsonDecode`) — python fora do `make test`; paridade byte-idêntica nos dois modos, 10/10 sem flake, 14 s |
| B7 (2026-07-08) | Tipos interprocedurais: cadeia de construção + oráculo QSelf (ast-6 `ret`); rito D4 (5 checks/6 sites aprovados caso a caso); homônimos separados por receptor; união de call sites/IIF; casos 84/85; suíte 582/0 |
| B7b (2026-07-08) | Inferência fatia 3 (zero core): retorno de MÉTODO pelos pushes `ret` (send encadeado, identidade em cadeia); 1º param de bloco INLINE = receptor (fato classes.c:4554, provado em DSL não-espelho); param de bloco pela união dos Evals rastreáveis; venenos honestos; furos latentes fechados (B7AllRetsSelf envenenado, índice do B7ParamType); caso 86; suíte 600/0; delta M-cov 2 no mapa |
| Auditoria (2026-07-05) | Gramática duplicada morta (`NameAccepted` via compilador-biblioteca; `CoreFunction` via harbour.hbx) |

Réplicas conservadoras remanescentes (da auditoria, não urgentes):
`StrDelimsOk` (delimitadores de string — ideal: span original no dump);
cheque textual de continuação `;` em 2 pontos (falso positivo só recusa).

## Fases ATIVAS (por prioridade)

### R — Revisão de generalidade ✅ CONCLUÍDA (2026-07-07)

**Escopo e checklist**: [revisao-generalidade.md](revisao-generalidade.md).
**Q4 ✅ FECHADA (2026-07-07, caso 75)**: o veneno do pai falso era real
(probe fixq4: forjador por `@ref` na linha da declaração virava pai e
`t:Pintar()` saía confirmed para um send que seria ERRO em runtime);
conserto `DispatchVia` — vínculo escrito nunca confirma/exclui, acerto
próprio decide; 7 asserts de herança flipam para possible nomeado
(**mudança de contrato, aguarda portão do Diego**); suíte 474/0.
**Q8 ✅ FECHADA (2026-07-07)**: auditoria commit a commit REFUTOU a
suspeita — nenhuma lógica keyed a biblioteca no core do branch, só
transporte 1:1 de canal da linguagem (gates fAst = tabelas vivas com
warnings nível-3 gated na emissão; schema espelha a gramática; canal de
tipos é write-only no core; evidência arquivo:linha no doc da revisão).
Pendência cosmética opcional: comentário de compast.c:106 (→ B6).
**Q1-Q3/Q7 ✅ FECHADAS (2026-07-07, casos 76-79, fixture fixofi)**: DSL
inventada NÃO-espelho (colagem MENSAGEM-primeiro `Talha_na_Banca`,
assinatura única sem par protótipo/impl, dispatch REAL
`__clsNew`/`__clsAddMsg`). Q2 = prova pura (o açúcar é só política de
unicidade sobre o motor genérico). Q1/Q3 = conserto `GenMsgPart`: a
mensagem do composto é a parte que NÃO nomeia função-de-classe (fato da
co-derivação) — eleger a última parte era forma-de-hbclass (call-graph
respondia VAZIO; o reorder cru elegia a dona). Q7 = a síntese
`METHOD ... CLASS` fica exclusiva da forma hbclass (portão = vocábulo da
regra raiz via `PpMarkerLift`; DSL própria degrada para FUNÇÃO verificada
com o fato relatado) + veneno novo morto: range com `QSelf()` extraído
para função mudava comportamento EM SILÊNCIO (receptor não viaja) — nó
`SELF` na árvore agora recusa limpo nomeando a exceção. Suíte 517/0.
**Q6 ✅ FECHADA (2026-07-07, caso 72 atualizado + caso 80 novo)**: rótulo
do DONO no vocabulário da DSL que o declarou (`cog declaration
(rig TOTEM)`, `oficio definition Talha (tenda Banca)` — prova na DSL
não-espelho). Semântica decidida por probe: a cabeça da regra cuja
expansão LIGOU o nome ao canal de classe (o `from` do próprio nome), NÃO
a regra raiz do site — `CREATE CLASS` tem raiz `create` e o hbclass segue
`(class ...)` porque a regra `CLASS` é quem declara; dona sem derivação
cai para "class" (o nome do canal da linguagem). Suíte 520/0.
**Q5 ✅ FECHADA (2026-07-07, casos 81 + 71 novo; opção B do Diego)**: o
`methodQuery` (regex hbclass da extensão, V1) morreu — a extensão manda a
POSIÇÃO do cursor (`usages --at arq:linha:col`, UMA compilação) e o CLI
resolve por fato (`ResolveAtQuery`, mesmo core do `resolve-at`
standalone): co-derivação do site + aplicação-identidade (P1a) + canal
declared. Homônimos pelo SITE; DSL qualquer promove (a regex só via
hbclass); send/posição-vazia degradam honesto. Extensão 0.6.0.

**A REVISÃO ESTÁ COMPLETA**: V1-V7 tratados, Q1-Q8 fechadas com prova
executável (casos 75-81 + atualizações 64/72-74), régua do caso 64
assertada nos casos novos, extensão sem regex de construto.

### B4g ✅ ENTREGUE (2026-07-07) — registro no [arquivo](roadmap-fases-entregues.md)

Portão + decisões: [adr-001-b4g-diretiva-fonte.md](adr-001-b4g-diretiva-fonte.md);
spec (fatos 1-13): [spec-b4g-diretiva-fonte.md](spec-b4g-diretiva-fonte.md).
Todos os critérios mecânicos fechados (zero impacto 224/224; byte-exato
campo a campo no caso 82; caso 74 acionável com round-trip; suíte 555/0 +
lexdiff limpo; extensão 0.7.0).

### B5 — Extensão VSCode (restante)

Fatias entregues no arquivo; **consulta por POSIÇÃO entregue (Q5,
extensão 0.6.0)**; **B4g entregue (0.7.0)**: confirm-then-force de
`--edit-rules` no rename-function + conserto do confirm de `--force`
(regex testava mensagem em inglês, CLI fala português — estava morto).
**`--show-expansion` entregue (0.7.1, 2026-07-08 — decisão do Diego:
SEMPRE-ligado no usages da extensão, sem comando/setting novos)**: o
flag é só-rótulo do canal (` -> CAIXA_SOMA`, ` -> derives ...`) e o
`--json` do peek é byte-idêntico com/sem ele (provado em fixmth e
fixppm), então suprimir custaria caro — cada invocação recompila o
projeto (`hbmk2 -rebuild`) e re-perguntar pagaria outra compilação;
divergência com o default do CLI documentada no README da extensão;
guarda executável no harness do caso 71.
**HB_BIN definitivo (0.7.2, 2026-07-08)**: a validação do Diego morreu
com "o projeto não compila" porque o host de desenvolvimento não tinha
`hbrefactor.hbBin` configurado — sem `HB_BIN` o CLI cai no hbmk2 do
PATH (sem `-x`), sintoma já catalogado no CLAUDE.md. Conserto em três
camadas: default do setting = layout do repo
(`~/devel/harbour-core/harbour/bin/linux/gcc`, o mesmo do Makefile);
dica honesta no `AstDumps` do CLI nomeando a causa quando o build falha
com `HB_BIN` vazio; 2 guardas novas no harness do caso 71 (13 pass).
**Picker ciente do arquivo entregue (0.8.0, 2026-07-08)**: subcomando
`projects-of <arq> <candidatos...> [--json]` no CLI — pertencer = o
hbmk2 resolve o arquivo como fonte na linha de comando do compilador
(`LoadProject`/`-traceonly`, medido ~3 ms por candidato ⇒ sem cache),
identidade por caminho canônico COMPLETO (nome+ext daria falso positivo
entre projetos com `main.prg` distintos — provado no caso 83); órfão =
resposta vazia com exit 0, nenhum candidato resolvido = exit != 0 (a
pergunta falhou, não é órfão). Na extensão a decisão é pura
(`pickerChoices`): dono único entra SEM pergunta, fonte compartilhada
pergunta só entre os donos, órfão/falha degrada para a lista completa;
`projCtx` (relatórios de projeto inteiro) inalterado. Provas: caso 83
novo (10 checks, inclui a armadilha do basename e a forma absoluta da
extensão) + 9 guardas novas no harness do caso 71 (22 pass); suíte
**565/0**.
Restante, por fricção do uso diário:

- preview `--dry-run --json` se a fricção pedir.

**Critério**: Diego usa no dia a dia; sem regressão.

### U — Verbos de refatoração unificados (`rename`/`extract`/`reorder`) — **PORTÃO: decisão do Diego**

**A pergunta, firme**: por que a CLI expõe OITO comandos de rename
(`rename-local`, `rename-static`, `rename-memvar`, `rename-param`,
`rename-function`, `rename-method`, `rename-dsl`, `rename-pp-marker`) mais
`extract-function`, `inline-local`, `reorder-params`? Para renomear, o
usuário precisa CLASSIFICAR de antemão o alvo — é local ou static? memvar
ou param? método ou função ou palavra de DSL ou marcador de pp? Isso é
justo o trabalho que **o compilador já fez** e que a ferramenta consome em
`usages --at` / `resolve-at` / `ResolveAtQuery` (Q5): dado um ponto, o
FATO diz o que o nome é. Fazer o usuário repetir essa taxonomia no sufixo
do comando é uma **réplica sintática na superfície da CLI** — o mesmo
anti-padrão que O NORTE proíbe no motor (sem ajuste por-caso; a fonte da
verdade é o compilador, não uma tabela de tipos remontada à mão, aqui na
UX).

**Proposta a avaliar**: colapsar para os verbos que descrevem a AÇÃO, não a
espécie do alvo — `rename <arq:linha:col> <novo>`, `extract`, `reorder` —
despachando pelo fato da árvore no ponto (a máquina do `resolve-at` já
existe e já é o caminho da extensão). O KIND deixa de ser escolha do
usuário e vira consequência do que está sob o cursor.

**Contra-argumentos honestos (para o portão, não varrer)**:
- Os sufixos explícitos são também um CONTRATO/salvaguarda: `rename` cego
  num ponto ambíguo poderia renomear a coisa errada em silêncio. Resposta
  proposta: degradar honesto — desambiguar/recusar nomeando a exceção
  (idioma já usado no SELF/dispatch), NUNCA adivinhar. Isso pode custar uma
  pergunta interativa que hoje o sufixo dispensa.
- Alguns comandos carregam semântica/flags próprias que o verbo único
  precisa PRESERVAR, não perder: `rename-function --edit-rules` (caso 74),
  `rename-pp-marker` genérico, `rename-dsl` de qualquer palavra do match
  (B4g). Unificar sem regressão dessas capacidades é o custo real.
- Scripts/harness (os ~565 casos) e a extensão chamam os nomes antigos —
  aliases retrocompatíveis ou migração registrada, decisão do Diego.
- Peso fraco a favor de manter separado: o sufixo é auto-documentado no
  `--help` e no shell-completion; um `rename` único esconde o alcance.

**Critério de pronto (executável, se o portão abrir)**: `rename
<arq:linha:col> <novo>` resolve o KIND pelo fato e produz saída
BYTE-IDÊNTICA ao `rename-*` específico correspondente, provado em casos
cobrindo os oito alvos (local/static/memvar/param/function/method/dsl/
pp-marker); ponto ambíguo ou sem fato degrada honesto (recusa nomeada, sem
adivinhação); capacidades por-flag preservadas sob o verbo; nomes antigos
viram aliases OU a remoção fica registrada em ADR; `extract`/`reorder`
recebem o mesmo tratamento se o fato os cobrir. Zero regressão na suíte.

### B-infra — suíte paralela (pool dinâmico)

Racional: [testes-paralelos.md](testes-paralelos.md).
**Etapa 1 ✅ ENTREGUE (2026-07-07)** — registro no
[arquivo](roadmap-fases-entregues.md): pool bash `xargs -P` por-caso,
`TMPDIR` por unidade, artefato + tally no join; asserts intactos (drift
zero). Provas: saída BYTE-IDÊNTICA à sequencial (J1 e paralelo), 10/10
rodadas sem flake, **109 s → 11-14 s (~8×)**; `make test` = paralelo
default, `JOBS=1` sequencial com saída ao vivo para depurar.
**Etapa 2 — runner em Harbour ✅ ENTREGUE (2026-07-08)**: mesma FORMA
da Etapa 1 (pool por-caso, unidades bash intactas, protocolo filho
`--unit N` + `@@counts` + logs impressos na ordem), só a tecnologia
troca, em duas fatias independentes:

- **(a) checker Harbour** — `tests/tcheck.prg` (compilado pelo
  Makefile) substitui os **10 heredocs `python3`** das unidades
  18/26/42/62/65/66/70/72/82 (o "18/26" do desenho original cresceu):
  asserts sobre JSON via `hb_jsonDecode`, mesmos exit codes e mesmas
  saídas assertadas ("json ok", "consistente").
- **(b) despacho+join Harbour** — `tests/parrun.prg` via
  `hb_processOpen`/`hb_processValue` (fato verificado no fonte:
  `waitpid(WNOHANG)`, -1 enquanto roda) substitui o ramo `xargs -P`
  do run.sh; `JOBS>1` delega ao binário, `JOBS=1` continua bash
  sequencial com saída ao vivo (R7 preservado).

Fora do escopo (decisão de menor arrependimento, mesma da Etapa 1):
reescrever os 555 asserts em .prg (drift alto, valor novo nulo — as
unidades bash JÁ são auto-contidas) e o `occ_ast_diff.py` do
`make lexdiff` (fora do caminho do `make test`; morre quando o alvo
legado morrer). Critério de pronto, TODO provado por execução no
fechamento (2026-07-08): `python3` ausente do `run.sh` (resta 1 menção
em comentário — história); saída do `make test` **byte-idêntica** nos
dois modos (diff paralelo × `JOBS=1` limpo); 10/10 rodadas paralelas
sem flake e byte-idênticas entre si; wall-time 14 s (patamar da
Etapa 1); binários construídos pelo Makefile (`bin/tcheck`/`bin/parrun`
são dependências do alvo `test`).

### D — Evidência de execução — **PORTÃO FECHADO NA FORMA PROPOSTA (Diego, 2026-07-08)**

A forma proposta (camada `observed` anotando sites `possible` para
priorizar conferência manual) é TRIAGEM — e triagem não é produto
(REGRA DO FATO, acima). A spec fica como registro dos fatos
re-auditados (o funil real é `hb_objGetMethod`, classes.c:1802 — cobre
`hb_vmSend`, `hb_vmDo` com Self objeto e `@obj:var`; HasMsg se filtra
por `pStack == NULL`):
**[spec-d-evidencia-execucao.md](spec-d-evidencia-execucao.md)**.
Evidência de execução só volta se tiver consumo 100% fato (ex.:
alimentar cheques impostos), decisão do Diego.

### B9 — Tipos declarados impostos: cheque de runtime para `AS <tipo>` (flag `-kt`) — **SAI DA GAVETA pela REGRA DO FATO (2026-07-08): é o caminho canônico — aguarda portão do Diego para executar**

A REGRA DO FATO inverte a escada do início do dia: fato ausente →
**estender o core para o fato existir**, e a B9 é exatamente isso — a
anotação `AS <tipo>`/`AS CLASS` vira INVARIANTE imposta (fail-fast sob
`-kt`), transformando promessa em fato e fechando os baldes que a
estática nunca alcança (classes montadas em runtime, objetos nascidos
na VM — cheque por nome no objeto VIVO). Ciclo virtuoso com a
ferramenta: a análise B7/B7b vira MATERIALIZADORA (escreve os
`AS CLASS` que provou) → a flag impõe → o veredito vira fato. A spec
está pronta ([spec-b9-anotacoes-impostas.md](spec-b9-anotacoes-impostas.md),
T1-T5 decididas: flag `-kt` opt-in fluindo pelo hbmk2, NIL falha,
is-a satisfaz, escopo params+locals+retorno); a fatia de
MATERIALIZAÇÃO (comando que escreve anotações provadas) precisa de
escopo+critério antes de executar.

### B8 — Macros: pipe hbmk2, ast-7 + complemento por probe — **EM ESPERA (rebaixada pela M-cov, 2026-07-08)**

Rebaixamento (decisão do Diego ao seguir a análise estratégica):
a M-cov achou **zero receptor por macro** no corpus e o Diego
despriorizou macros para refatoração. A spec fica pronta na gaveta;
executa quando a fricção real pedir. Adendo verificado no mapa
(alavanca D): a AST de toda macro existe completa em runtime
(macro.y:257; gate único em vm/macro.c:798) — o dump de macro em
runtime é o gêmeo do funil `hb_vmSend`, e viaja com a alavanca D,
não com esta fase.

Requisito do Diego (2026-07-08): macros como caso difícil + smoke test
com `hb_compileFromBuf()` colhendo insights que generalizem. Spec com
fatos verificados (arquivo:linha), decisões E1-E4 + dialética do pipe,
veredito de valor, venenos e critério de pronto executável:
**[spec-b8-macros.md](spec-b8-macros.md)**.
Arquitetura (dialética fechada 2026-07-08): pipe `[pré: slot vazio
documentado] | compilador -x (ast-7) | pós: seleção por análise +
sondagem 100% core → <projeto>.astc.json`. O pré NÃO alimenta o core
durante a compilação (só há 3 bocas de entrada; pp externo destruiria
a derivação from/ppRules); o complemento (schema `astc-1`, um por
projeto) fica epistemicamente SEPARADO do dump — sub-árvore de macro é
verdade condicional ao valor rastreado, com proveniência por entrada.
Resumo das fatias: (1) transporte ast-7 — `SubType`/`cMacroOp` do nó
`HB_ET_MACRO` que o dump descarta hoje; só compast.c + zero impacto;
fazer incondicionalmente (veredito). (M0) medição no corpus ANTES de
construir a fatia 2 — quantos sites `&`/`HB_MACROBLOCK` são
rastreáveis; os números dimensionam a profundidade (E3 interprocedural
mantida ou encolhida para literal-local). (2) subcomando gera o
`.astc.json` sondando via `hb_compileFromBuf` (dialeto `-k*` do trace,
idioma do NameAccepted, + `-u -x<tmp>`); conteúdo não-rastreável
degrada honesto. Plugin fino hbmk2 `post_build`: ADIADO (API
documentada na spec como ponto de acoplamento; implementar só no
dogfooding real). Critério de matar: divergência probe×macro.y grande
→ probe degrada ou morre, com relato.

### B6 — PR upstream (BLOQUEADA: só quando o Diego mandar)

Mensagem com consumidor real; 1 arquivo novo + ganchos opt-in; prova de
zero impacto na árvore inteira; build limpo (corrigir o `-Wtype-limits`
de compast.c:658 — tirar o `iType >= 0`; a linha andou com o ast-5);
regen bison 3.8.2 documentado;
split opcional em 2 PRs; ChangeLog via `bin/commit.hb`; uncrustify.

## Backlog (por valor)

0. **Velocidade em projetos grandes**: `-inc` já dá dumps incrementais;
   verificação proporcional à edição quando o uso real doer.
1. **Análise de programa inteiro (tipos interprocedurais)** — **PROMOVIDA
   para a fase B7 (2026-07-08)**, spec no portão:
   [spec-b7-tipos-interprocedurais.md](spec-b7-tipos-interprocedurais.md).
   Ponto fixo sobre os dumps com conjuntos finitos de classes — alavanca
   B do [mapa](limites-e-alavancas.md); nota de probe: RETURN vira `push`
   no dump mas SEM rótulo (D2 da spec propõe o gancho ast-6).
   **Fricção relatada (Diego, 2026-07-08, fixext)**: usages de `Deposita`
   mistura os sends de `oC` (Conta) e `oV` (ContaVip) — os 4 sends saem
   `possible (receiver unknown)` nas DUAS consultas e o peek junta tudo.
   A separação por homônimo nas definições/declarações JÁ funciona
   (caso 81: excluded com fato nos dois sentidos); o que falta é tipar o
   RECEPTOR dos sends. Alvo executável: com `oC := Conta():New()` /
   `oV := ContaVip():New()` no MAIN, a consulta `CONTAVIP:Deposita` deve
   excluir os sends de `oC` e confirmar o de `oV`, cada um com seu fato;
   receptor sem fato (parâmetro de fora, macro, `Self := oOutra` do
   próprio fixture) permanece possible — o contrato de 3 camadas fica.
2. **Evidência de execução — PROMOVIDA a fase D no portão
   (2026-07-08)**: spec própria com fatos re-auditados
   ([spec-d-evidencia-execucao.md](spec-d-evidencia-execucao.md));
   ver a seção da fase acima.
3. **Regra sem cabeça** (`head null`, hbcompat legado): dump já registra;
   candidata a fixture de RELATO se um projeto real trouxer o caso.
4. Dedup pré/pós-decremento: não-fazer mantido (v2).
5. **Projetos grandes de produção** (quando o Diego liberar): dogfooding
   final — só depois de suíte + hbhttpd verdes.
