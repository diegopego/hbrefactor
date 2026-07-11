# Roadmap — hbrefactor sobre AST do compilador (v3 enxuto, 2026-07-07)

Responsável pela ferramenta: Claude (planejamento, implementação,
verificação); decisões de produto e autorizações (commits, PR upstream):
Diego. Regra de manutenção: **este documento é vivo** — fase futura só
começa com escopo e critério de pronto escritos; fase concluída ganha UMA
linha no índice de entregues e o registro completo vai para o arquivo.
**Regra de arquivamento (2026-07-09)**: o mesmo vale para SEÇÕES já
concluídas dentro deste arquivo e para pendências de sessão resolvidas —
a narrativa migra para o [arquivo](roadmap-fases-entregues.md) na mesma
sessão e aqui fica só o stub com os links; este documento carrega apenas
estado atual + o que está por fazer.
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
compilador). Dump por módulo `.ast.json` (schema atual **ast-8**), specs
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
| B9 fatias 1+2 (2026-07-08→10) | Tipos declarados IMPOSTOS: `-kt` no core (ast-7) + camada `guaranteed` honesta (RE.2) + materializador `annotate`/`--apply` (escada de declarações, padrão-ouro inerte/compila/roda-`-kt` com rollback byte a byte); candidato (g) de core adotado; casos 87-97 (inclui rollback provocado e projeto já-`-kt`); Rotas A/B dos testes-suspensos RECONQUISTADAS; extensão 0.9.0; suíte 699/0 |
| Auditoria (2026-07-05) | Gramática duplicada morta (`NameAccepted` via compilador-biblioteca; `CoreFunction` via harbour.hbx) |

Réplicas conservadoras remanescentes (da auditoria, não urgentes):
`StrDelimsOk` (delimitadores de string — ideal: span original no dump);
cheque textual de continuação `;` em 2 pontos (falso positivo só recusa).

## Fases ATIVAS (por prioridade)

### RE — Re-escopo pós-revisão externa — **PRIORIDADE 1 (portão aberto pelo Diego, 2026-07-09)**

A revisão externa independente (Codex, 3 rodadas em 2026-07-09 —
instrumento
[revisao-codex-zero-inferencia.md](revisao-codex-zero-inferencia.md))
convergiu com o julgamento interno de 2026-07-08: **manter** dump
`-x`/rastreamento PP/refatorações verificadas; **`-kt` é R1-legítimo
mas o consumo overclaima** (`guaranteed` para sites que o cheque não
cobre); **B7/B7b são inferência** → rebaixar a sugeridora/
materializadora. Plano vinculante com achados A1-A6, itens RE.1-RE.6,
guarda de fase e critérios executáveis (**RE.1-RE.4 FECHADOS em
2026-07-09** — RE.1: A1/A2/A5 confirmados com probes, extras gap de
`@ref` e A6, segfault upstream com `AS CLASS` em param de codeblock;
RE.2: marca `kt` restrita a site coberto, caso 88; RE.3, portão
aberto na forma "a" + possible sem nomes de inferência: máquina
B7/B7b/dispatch-por-grafo DORMENTE, usages só-fato, M-cov 3 com
confirmed 1.715→545 100% canal declarado, casos 39/61/63/66-69/72/75/
84-86 re-baselinados — o furo dos homônimos degradou nos sends;
RE.4: `pPosTbl` limpo no reset, 460/460 byte-idêntico, harbour-core
`ef0abe3688`. Suíte 622/0 byte-idêntica. **RE.5 EXECUTADO
(2026-07-10, portão aberto pelo Diego na mesma sessão da spec):
[spec-re5-cobertura-kt.md](spec-re5-cobertura-kt.md)** — K1 (A6 morto:
classe de param de bloco EXISTE e chega ao dump), K2 (prólogo de bloco
impõe por Eval), K3 (pós-store de detached em bloco), K4 (fato `chk`
no dump, **ast-8**; `B7KtCovered` virou LEITOR — a matriz replicada
morreu; portões de capacidade convertidos a `AstAtLeast`, lição do
bump); K5 MEDIDO (zero receptores-objeto em @ref no corpus → FORA
com registro), K6 FORA. Caso 88 re-baselinado como matriz por FATO
(escrita em bloco e param de bloco AS CLASS RECONQUISTADOS →
`guaranteed`; site 5 era INESCREVÍVEL antes do A6). Zero impacto
1085/1085 (+3 = o próprio A6 no compilador base); suíte **700/0**
byte-idêntica paralelo × `JOBS=1`; lexdiff limpo. Commits do core sob
autorização. **RE.6 — F6.1+F6.2+F6.3 ENTREGUES (2026-07-10, D1-D6 como
recomendados): o FURO DOS HOMÔNIMOS (caso 66, o caso original do Diego)
FECHADO por FATO.**
[spec-re6-parentesco-declarado.md](spec-re6-parentesco-declarado.md)
§ Executado — F6.1: canal `_HB_SUPER` no core (léxico+gramática
0-conflitos+hbclass.ch, pai posicionado prov `s`; `.hrb` 356/0
byte-idêntico; lição hbmk2 = 2º binário que embute o compilador,
commit `52ca3e0b6f`). F6.2: schema `ast-10` (`5a9ba73f91`) + consumidor
(`ClassSuperFacts`/`ResolveDispatchSuper`/`KinshipExcludes`, exclusão de
send por parentesco de FATO com degrade honesto sob is-a). F6.3:
re-baseline dos 16 asserts da Rota C + generalidade adversarial (caso
104, DSL inventada declara herança só via `_HB_SUPER`) + CHANGELOG;
suíte **757/0**, lexdiff 0. Commit consumidor+re-baseline `6df5c50`;
generalidade+CHANGELOG sob portão. Parentesco DECLARADO reconquistou a
exclusão de SEND sobre arestas de FATO:
**[spec-re-reescopo-pos-revisao.md](spec-re-reescopo-pos-revisao.md)**
— retomada de sessão COMEÇA por lá. Registro narrativo da sessão
2026-07-09 (rodadas, commits `c1927dfcac`/`6584aa8`/`590a4a5`) no
[arquivo](roadmap-fases-entregues.md).

### R — Revisão de generalidade ✅ CONCLUÍDA (2026-07-07) — narrativa no [arquivo](roadmap-fases-entregues.md)

V1-V7 tratados, Q1-Q8 fechadas com prova executável (casos 75-81 +
atualizações 64/72-74); checklist e achados:
[revisao-generalidade.md](revisao-generalidade.md). Pendência viva que
sobrou: os 7 asserts de herança flipados para possible nomeado (Q4)
foram **mudança de contrato que aguardava portão do Diego** — absorvida
pela fase RE (o rebaixamento de B7/B7b decide o contrato final).

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
**Descoberta por proximidade entregue (0.11.0, 2026-07-10)**: o Diego
relatou que no dia a dia o picker mostrava vários `.hbp` (às vezes o
mesmo repetido) e o `.hbp` do próprio diretório do arquivo SUMIA.
Diagnóstico (três raízes, todas na extensão): (1) `findFiles` com teto
de **32** truncava a lista em ordem indefinida ANTES da lógica de dono
rodar — neste workspace há 158 `.hbp`/`.hbc`, então o do diretório caía
fora; (2) zero ordenação (a `fsPath` crua na ordem de varredura); (3)
zero dedup. Conserto **no CLI** (fiel à extensão fina — o walk-up e a
ordenação são inteligência, não podem morar na extensão): o
`projects-of` ganha um **modo DESCOBERTA** — `projects-of <arq> [--root
<dir>]... [--json]` sem candidatos. A ferramenta ACHA o projeto por
FATO: caminha os diretórios ANCESTRAIS (dir do arquivo → raiz que o
contém) listando `.hbp/.hbc` (só nome por extensão — nunca parse de
`.hbp`), sonda o hbmk2 do mais PRÓXIMO ao mais distante (`FileOwnedBy`
fatorado de `ProjectsOf`) e, só se nenhum ancestral for dono, amplia
varrendo a(s) raiz(es) (adaptativo; teto `OWNER_BROADEN_CAP` avisa se
truncar). Devolve `{ owners, candidates }` JÁ ordenados por proximidade
(`RankByProximity`, matemática de caminho pura). **A proximidade é só
APRESENTAÇÃO; o veredito de posse continua sendo fato do hbmk2** — o
auto-select ainda exige dono ÚNICO de fato, nunca "o mais próximo". Na
extensão: `ownerOf` passa o arquivo + as raízes do workspace e renderiza
(rótulos legíveis: nome do `.hbp` + diretório); `findFiles` perde o teto
e deduplica (só usado no caminho SEM arquivo/degradado); `pickerChoices`
intacto. Modo FILTRO legado (candidatos explícitos, array JSON, ordem
dos candidatos) preservado byte-a-byte → caso 83 inalterado. Provas:
caso 102 novo (6 checks: dono único, fonte compartilhada nearest-first,
decoy mais perto que NÃO é dono, órfão, objeto JSON) + 6 guardas novas
no harness do caso 71 (32 pass).
Restante, por fricção do uso diário:

- preview `--dry-run --json` se a fricção pedir.

**Critério**: Diego usa no dia a dia; sem regressão.

#### B5.1 — `.hbp` multi-alvo reconhecido por inteiro ✅ ENTREGUE (2026-07-10)

Sintoma do Diego: `.hbp` com estrutura/flags mais complexa "não era
reconhecido". Raiz: um `.hbp` pode resolver para **vários alvos de build**
— `-hbcontainer` referenciando sub-`.hbp`, referência direta a outro
`.hbp`, ou `-target=` — e o `hbmk2 -traceonly` imprime **uma linha
"Harbour compiler command" por alvo**. O `LoadProject` lia só a PRIMEIRA;
as fontes dos demais alvos ficavam invisíveis e o `.hbp` deixava de ser
reconhecido como dono delas (owners vazio no `projects-of`). Fix:
`LoadProject` captura TODAS as linhas de comando e **une** fontes/includes/
flags/hbx com dedup (`AddUniq`). Fiel à REGRA DO FATO — `.hbm` (coleção de
opções), `.hbc` (pacote), `-i`, `${macros}` e filtros `{...}` já vêm
**resolvidos DENTRO de cada comando** pelo hbmk2; a ferramenta nunca
parseia `.hbp`, só lê o comando do compilador que o builder oficial
emitiu. Prova: caso 103 novo (4 checks: fixtures limpas, dono do 1º alvo,
dono do 2º alvo — a regressão —, descoberta do container). A API de plugin
do hbmk2 foi avaliada como canal alternativo e DESCARTADA: expõe
`hbmk_AddInput_*` (escrita) e vars como `cTARGETNAME`, mas **não** a lista
de fontes resolvida (leitura) — o comando do `-traceonly` continua sendo o
canal de fato mais completo.
Limite conhecido (não do escopo deste fix): se dois alvos compilam módulos
de MESMO nome-base em diretórios distintos, o dump `.ast.json` é chaveado
só pelo nome-base (`ReadAst`) e colidiria — só afeta análise, não a posse.

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

### B-infra — suíte paralela ✅ ENTREGUE (Etapas 1 e 2) — narrativa no [arquivo](roadmap-fases-entregues.md)

Racional: [testes-paralelos.md](testes-paralelos.md). Etapa 1
(2026-07-07): pool bash por-caso, 109 s → 11-14 s (~8×). Etapa 2
(2026-07-08): runner em Harbour (`tests/parrun.prg` +
`tests/tcheck.prg`), python fora do `make test`, paridade
byte-idêntica nos dois modos.

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

### B9 — Tipos declarados impostos (`-kt`) + materializador `annotate` — ✅ ENTREGUE (fatias 1 e 2, 2026-07-08→10) — narrativa no [arquivo](roadmap-fases-entregues.md)

A fase-modelo da REGRA DO FATO: fato ausente → **estender o core** —
a anotação `AS <tipo>`/`AS CLASS` virou INVARIANTE imposta (fail-fast
sob `-kt`, cheque por NOME no objeto VIVO: cobre classes de runtime
que a estática nunca alcança) e o `annotate` fechou o ciclo virtuoso:
a máquina B7/B7b (dormente, RE.3) SUGERE → o comando ESCREVE
declarações da linguagem pela ESCADA (nível 1 fato puro; nível 2
one-liner `DECLARE`/`_HB_MEMBER`/`_HB_CLASS`; nível 3 SÓ relata) com
padrão-ouro por edição (inerte byte-idêntico sem `-kt` + compila limpo
+ roda sob `-kt`) e rollback → o `-kt` IMPÕE → o site decide por fato
(`confirmed declared` → `guaranteed`). Specs:
[spec-b9-anotacoes-impostas.md](spec-b9-anotacoes-impostas.md) (fatia
1) e [spec-b9-fatia2-materializacao.md](spec-b9-fatia2-materializacao.md)
(fatia 2); plano executado F2.0-F2.5:
[plano-b9-fatia2-escada.md](plano-b9-fatia2-escada.md); candidato (g)
de core ADOTADO (`00ccbc20b3`). Casos 87-96 (execução real; round-trip
por semente [FATIA-2]; ROLLBACK PROVOCADO com recusa nomeando o
BASE/3012); [testes-suspensos-re3.md](testes-suspensos-re3.md) Rotas
A/B **RECONQUISTADAS**; extensão VSCode 0.9.0; corpus hbhttpd: 31
declarações + 7 anotações verificadas, re-relatório DRENA (M-annotate
no [limites-e-alavancas.md](limites-e-alavancas.md)). Suíte **692/0**
byte-idêntica paralelo × `JOBS=1`; lexdiff limpo.

**Projeto já-`-kt` ENTREGUE (2026-07-10, escopo aberto pelo Diego)**:
o teste inerte compila baseline/pós-edição SEM a flag (`AnnNoKt`) — a
anotação sob `-kt` muda pcode por DESIGN (emite os cheques); caso 97:
quem já adotou `-kt` anota e o site coberto sai `guaranteed` direto.
Suíte **699/0** byte-idêntica paralelo × `JOBS=1`.

**Fatia 3 — materializador de param de bloco (2ª perna da Rota D) —
✅ EXECUTADA (2026-07-10, mesma sessão do portão; decisões do Diego:
D1 contrato espelho da Rota B, D2 fato de posição para TODAS as
declarações, D3 ambas as fontes)**:
**[spec-b9-fatia3-param-bloco.md](spec-b9-fatia3-param-bloco.md)** §
Executado — F3.1: âncora de escrita como FATO do dump (**ast-9**:
`nameLine`/`nameCol` = posição do token ESCRITO do nome; param de
bloco captura no parse via `HB_CBVAR`, padrão K1; ausente = param de
diretiva, inescrevível — honesto), zero impacto 230/230, adversarial
`LOCAL conta AS CLASS Conta` provado; F3.2/F3.3: balde `bp` do
`annotate` (sugestão pelo caminho de bloco da máquina dormente:
receptor-inline + união de Evals convergente) + escrita na âncora do
fato com registro `_HB_CLASS` quando a classe de runtime não é
conhecida do módulo; `AnnNameCol` (régua de unicidade) rebaixado a
degrade de dump antigo; F3.4: casos 98-100 fecham a Rota D nos itens
escrevíveis (detached, params q1 inclusive CONTINUADO, DSL
não-espelho JUNTO), venenos assertados, 89/97 re-baselinados só nas
contagens. Suíte **729/0** byte-idêntica paralelo × `JOBS=1`; lexdiff
limpo. q1:13/14 seguem suspensos com rota futura registrada
(anotação na regra da DSL / hbclass.ch no core). Commits do core sob
autorização.

### RD — Rota da diretiva (q1:13/14): tipo do receptor INLINE por FATO — ✅ **ENTREGUE (2026-07-10, mecanismo M-B; suíte 762/0)**

O furo que sobrou da B9 fatia 3 (fato 8): o `Self` gerado pela diretiva
`INLINE`/`OPERATOR`/`ACCESS`/`ASSIGN` do hbclass.ch NÃO tem token de
fonte, então os sends `::Msg()` dentro do bloco degradavam para
`possible` (q1:13/14 suspenso, caso 99). Alvo: o tipo do receptor
INLINE vira FATO de compilação, **nascendo genérico** (regra da DSL do
usuário; hbclass.ch = instância core). Experimento E0-E2 (2026-07-10):
**(E0)** gap = 2 params `SELF` (declLine 13/14) com `class:None`;
**(E2, empírico)** a ferramenta JÁ consome `type:'S'+class` num param de
bloco → `confirmed send (receiver declared AS CLASS MOEDA, codeblock)`,
ZERO mudança no consumidor (caminho vivo K2 do RE.5, TypeOf/DeclType);
**inércia** provada byte-idêntica sem `-kt`; **custo -kt** confirmado
(`__HB_CHKTYPE(Self,"S:MOEDA","MOEDA:SELF")` por Eval). O problema
colapsa em: preencher `type:'S'+class` no dump SEM o cheque `-kt`.
**Mecanismo M-B (canal dedicado, sem AS CLASS — escolha do Diego sobre
M-A/M-C)**: `bType` sentinela `HB_VARTYPE_INLINE_SELF` para "classe
fact-only" — flui `VarType→CBVAR→HVAR→pDecl` sozinho; `hb_compChkTypeGenCall`
(único emissor do cheque) pula o sentinela → cobre bloco simples E
estendido; `hb_compAstWriteType` mapeia sentinela→`'S'` só na escrita do
dump (E2 de graça); keyword `_HB_INLINESELF` no léxico (molde `_HB_SUPER`)
que hbclass.ch emite no `Self`, no-op sob `HB_CLS_NO_DECLARATIONS`.
Bônus: sem resolução de classe (linha hbmain.c:471 pulada) → sem W0025,
funciona até p/ classe de runtime não-registrada (DSL não-espelho).
**EXECUTADO (2026-07-10)**: 6 edições no core — sentinela
`HB_VARTYPE_INLINE_SELF` (hbcomp.h), keyword `_HB_INLINESELF` (complex.c),
`%token`+2 produções `BlockVarList` (harbour.y, bison regen 0-conflitos),
skip no `hb_compChkTypeGenCall` (hbmain.c), mapa sentinela→`'S'` no
`hb_compAstWriteType` (compast.c), os 4 blocos `INLINE`/`OPERATOR` +
no-op sob `HB_CLS_NO_DECLARATIONS` (hbclass.ch). Provas: **E1** dump
com `type:'S'+class` e `.c` `-kt` **byte-idêntico** ao original (zero
cheque); **E2** q1:13/14 = `confirmed` sem mudar a ferramenta (mesmo sob
`-kt`: confirmed, nunca guaranteed — fact-only); **E3** caso 105 novo
(DSL não-espelho fixself: FORGE/BELLOW/STOKE, receptor `oIt` gerado por
diretiva tipado só pelo canal — régua do caso 64); **zero-impacto** 43
módulos `-kt` M-B×original byte-idênticos; suíte **762/0**, lexdiff limpo.
Casos 86/99 re-baselinados (q1:13/14 `possible`→`confirmed`, portão do
Diego). Consumidor NÃO muda (canal declarado vivo, TypeOf/DeclType/K2).
Commits do core sob autorização por-commit. Rebuild: harbour E hbmk2
(libhbcplr). Fallback M-C (`AS CLASS` impõe) ficou desnecessário.

**Resíduos em aberto (fatias futuras da B9, portão de ESCOPO do
Diego)**: (1) anotação de PARÂMETRO de assinatura (colapsa em
`tokens[]`, pede o idioma `SigParamHits`; rendimento auto-escrevível
baixo hoje — param quase sempre é nível 3; o fato de posição da
fatia 3/D2 destrava a âncora se emitido para assinaturas); (2)
candidato (f) de core ADIADO (New implícito — protótipo como
coluna-delta quando reabrir); (3) execução controlada como 2ª FONTE
da sugeridora — **fatia 4 FECHADA (2026-07-10): F4.1+F4.2 entregues;
F4.3 (escrita) MORTA POR MEDIÇÃO (decisão do Diego sobre o M1b —
critério de matar acionado; spec na gaveta, padrão B8)**:
**[spec-b9-fatia4-execucao-controlada.md](spec-b9-fatia4-execucao-controlada.md)**
§ Executado — `exec-registry` entrega o retrato da tabela viva
(driver `-hbexe`+`-main=`, seleção 100% fato, proveniência por
chamada, flush por `EXIT PROCEDURE` contra QUIT do código executado,
schema `rtr-1` determinístico, zero edição no core; fixture fixreg +
caso 101; suíte **740/0** byte-idêntica). M1+M1b no
[mapa](limites-e-alavancas.md) (régua recalibrada: corpus = código do
CORE, regra no CLAUDE.md): casting raro no core bem escrito (rtl ~0%,
gtwvg ~1%, xhb ~0%; 38% do cls\*cast é tortura); classe invisível à
estática existe (escalares de startup do xhb) mas é nicho; registrador
paramétrico fica fora do alcance honesto — continuar/matar a escrita
(F4.3) é decisão do Diego sobre estes números.

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
   final — só depois de suíte + hbhttpd verdes. **Recalibrada (Diego,
   2026-07-10, regra no CLAUDE.md)**: antes de qualquer produção/bravo,
   a maturação acontece em corpus do CORE ampliado (copiar mais pastas
   pertinentes de `harbour-core/harbour` para work/); o bravo é só
   exploração até a ferramenta estar sólida no código do core.
