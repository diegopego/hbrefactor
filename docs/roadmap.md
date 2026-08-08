# Roadmap — hbrefactor sobre AST do compilador

Responsável pela ferramenta: Claude (planejamento, implementação, verificação);
decisões de produto e autorizações (commits, PR upstream): Diego.

> **REGRA DE MANUTENÇÃO — este documento carrega ESTADO ATUAL + O QUE FALTA, e nada mais.**
> Fase futura só começa com escopo e critério de pronto escritos. Fase concluída ganha UMA
> LINHA no índice de entregues, e a narrativa integral migra **na mesma sessão** para o
> [arquivo](roadmap-fases-entregues.md). O mesmo vale para seção concluída dentro deste
> arquivo e para pendência de sessão resolvida.
> **Ao arquivar, EXTRAIA as pendências vivas** que a narrativa carregava — elas vão para
> § Pendências vivas, nunca para o arquivo. *(A limpeza de 2026-07-13 nasceu porque a regra
> vinha sendo violada: o roadmap tinha 1.495 linhas, quase todas registro de coisa já
> entregue, com a intenção viva enterrada no meio.)*

Fluxos definidos vivem no **Makefile**; hbmk2 direto é só experimentação.
Mapa permanente do alcançável: [limites-e-alavancas.md](limites-e-alavancas.md).
Retomada de sessão: [handoff.md](handoff.md).

> **bravo-experimento: FORA DO ESCOPO (ordem do Diego, 2026-07-05).** Corpus de validação:
> fixtures da suíte + `work/` (cópias de pastas do CORE). Projetos grandes de produção só
> quando o Diego liberar.

## O NORTE

A lei vive no **CLAUDE.md** (§ 1, A REGRA DO FATO) e a jurisprudência em
[cicatrizes.md](cicatrizes.md) — **não se duplica aqui**. O resumo de uma linha, porque é
o que decide toda fase: **o hbrefactor age só sobre FATO produzido por compilação**; fato
ausente → estender o CORE (Harbour oficial inteiro) ou usar ferramenta do core como
oráculo; nunca inferir. Classes são só um caso; o alvo é **qualquer construto**, inclusive
DSL inventada pelo usuário. Régua executável: casos 64 e 72-74.

## Fundação (provada; não re-derivar)

Compilador como oráculo (ganchos gated, `.hrb` byte-idêntico sem `-x`); **editor ≠
verificador** (recompilar, comparar, rollback); hbmk2 como resolvedor de projeto; fixtures
como contrato; réplica sintática na ferramenta é proibida. Dump por módulo `.ast.json`, com
o schema corrente **definido em UM lugar só** (`AstSchema()` na ferramenta ×
`HB_AST_SCHEMA` no core) e especificado em [ast-schema.md](ast-schema.md) — **LER antes de
mexer**. *(Nenhum número de schema se escreve aqui: em 2026-07-13 esta seção ainda dizia
`ast-8` com o core em `ast-16` — um fato velho na seção que manda não re-derivar.)*

## Fases entregues (registro completo no [arquivo](roadmap-fases-entregues.md))

| Fase | Entrega (1 linha) |
|------|-------------------|
| B0+B1 (2026-07-05) | Mecanismo `-x` no core + fundação da ferramenta; lexdiff 0; occ↔ast paridade total |
| B2 (2026-07-05) | 11 comandos re-assentados na AST; run.sh novo |
| B3 (2026-07-05) | reorder multi-linha; `inline-local` com pureza pela árvore do compilador |
| B4 (2026-07-06) | `ppRules`/`ppApplications`; `rename-dsl`; usages de palavra de DSL; lifting |
| B4b (2026-07-06) | memvars: mapa de visibilidade; `rename-memvar` fecho-fechado; WorkDir atômico |
| B4c (2026-07-06) | rename-method por âncoras de forma — **MORTAS na B4d** (registro histórico) |
| B4d (2026-07-06) | Rastro de derivação `from`; `rename-pp-marker` genérico; âncoras por forma removidas |
| B4e (2026-07-06) | Comandos cientes de construtos; extract-para-método |
| B4f (2026-07-06) | Canal de tipos da linguagem; camadas confirmed/excluded/possible no usages |
| B4f-2 (2026-07-07) | Resolução de dispatch; homônimos; declarações vinculadas à dona |
| B4f-3 (2026-07-07) | PROVA da generalidade: DSLs inventadas, cstruct real, construtos não-classe |
| B4g (2026-07-07) | A regra POR DENTRO: `match[]`/`result[]`; rename de qualquer palavra do match; `--edit-rules` |
| B-infra 1+2 (2026-07-07→08) | Suíte paralela (109 s → ~14 s); runner em Harbour, python fora do `make test` |
| B7 + B7b (2026-07-08) | Tipos interprocedurais (cadeia de construção, oráculo QSelf) + inferência fatia 3 |
| B9 fatias 1-3 (2026-07-08→10) | Tipos declarados IMPOSTOS (`-kt` no core) + materializador `annotate` com escada e rollback |
| RE (2026-07-09→10) | Re-escopo pós-revisão externa: RE.1-RE.6; B7/B7b DORMENTES; parentesco declarado (`_HB_SUPER`) fecha o furo dos homônimos |
| RD + RD-c (2026-07-10→11) | Tipo do receptor INLINE por FATO (`_HB_INLINESELF`); params tipados no nó CODEBLOCK |
| B5 + B5.1 (2026-07-07→10) | Extensão VSCode 0.6.0 → 0.13.0; `projects-of` (posse por fato, descoberta por proximidade); `.hbp` multi-alvo |
| U (2026-07-11) | Verbos unificados: `rename <arq:linha:col>` despacha pelo FATO; os 8 `rename-*` REMOVIDOS |
| P (2026-07-11→13) | pp EXAURIDO: 4 canais novos no core (`ast-13`..`ast-16`), pp vivo como oráculo, zero heurística nova |
| SITE-EX (2026-07-12) | CLI em inglês; exemplos da página EXECUTADOS (`make site-check` falha se divergir) |
| L (2026-07-13) | **MORTA no dia em que nasceu** — o `unused-locals` SAIU: não se otimiza um comando que não devia existir |
| A.2 (2026-07-13) | `snapshot`/`verify`: o verificador sai da jaula e prova edição que a ferramenta NÃO fez |
| Auditoria (2026-07-05) | Gramática duplicada morta (`NameAccepted` via compilador-biblioteca; `CoreFunction` via harbour.hbx) |
| W (2026-08-06→07) | Isolamento: `-workdir` próprio (para de sujar o projeto do usuário), lock por projeto, dump reusado por CONTEÚDO |
| X (2026-08-06) | `ast-22`: o dump declara de que arquivos foi feito; `--ast-fresh`/`--filesum` respondem se ainda vale |

**Réplicas conservadoras remanescentes** (da auditoria, não urgentes): `StrDelimsOk`
(delimitadores de string — ideal: span original no dump); cheque textual de continuação `;`
em 2 pontos (falso positivo só recusa).

---

# FASES ATIVAS

## V — Velocidade da refatoração em PROJETO GRANDE — **ATIVA (fatia 1 entregue 2026-07-13)**

A P9 consertou o dump **por módulo**. O que sobrou é **estrutural, e é o que o usuário
sente**: todo comando re-dumpa o **projeto INTEIRO** — `AstDumps` passa `-rebuild`
([hbrefactor.prg:249](../src/hbrefactor.prg)), de propósito (*"dump sempre fresco"*: a
ferramenta jamais pode agir sobre fato velho). **A espera é a mesma para renomear 1
variável ou 20.** *(A extensão VSCode é o consumidor diário do Diego — é lá que dói.)*

**FATIA 1 ✅ ENTREGUE — onde o tempo VAI (e ela DERRUBOU o desenho das outras duas).**
Medida com a ferramenta **instrumentada por dentro** — e isso não é detalhe: por FORA,
emulando o `hbmk2` que eu *achava* que ela dispara, os números não fechavam e um projeto
quebrado passava por bom. **Cronometrar processo não é medir trabalho.** Em `work/xhb` (43
módulos, compila, lê e analisa): `call-graph` 8,4 s (gerar dumps 58%, ler+parsear 11%,
analisar 31%); `usages` 12-15 s (gerar 35%, ler ~10%, **analisar ~50%**).

**Os três vereditos:**
1. **NÃO existe gargalo único.** No `usages` — o verbo mais usado — a ANÁLISE pesa mais que
   a geração.
2. **Cache de dump ataca no máximo METADE.** Com cache perfeito o `usages` no xhb ainda
   levaria ~7-9 s. **O desenho original da fase (fatia 3 = "cache de dumps") estava ERRADO**
   — e só se soube medindo.
3. **As TRÊS etapas são proporcionais ao PROJETO**, inclusive a análise, que re-deriva os
   fatos do projeto inteiro a cada comando. O objetivo (*custo proporcional ao que você
   TOCOU*) **não se alcança sem tornar incremental o FATO ANALISADO**, não só o dump.

**FATIA 2 (RE-DESENHADA pela fatia 1) — o FATO ANALISADO por módulo, incremental.
ABERTA; a parte do DUMP saiu na W.3, a da ANÁLISE é o que resta.** O que tem de ser
reaproveitado quando um módulo não muda é o **resultado da análise daquele módulo** (o que
ele define, chama, declara) — o dump vem junto, de graça, pelo mesmo critério. **REGRA DO FATO:** é PROIBIDO inventar staleness na ferramenta (mtime é
heurística; include transitivo a quebra). Quem decide o que recompilar é o **`hbmk2 -inc`**
(sondado 2026-07-13: tocando 1 de 3 módulos, **só o dump dele é regravado**); o fecho
transitivo de include vem do **`harbour -gd`** (P8).

**TABELA DE SONDAS — o `-inc` responde sobre o `.c`, NÃO sobre o dump** *(medido
2026-08-06; §1.7.1: a sonda antes do mecanismo)*. Comando de todas as linhas:
`hbmk2 p.hbp -hbcmp -q -prgflag=-x<dir>/` com `-inc` no `.hbp`, projeto de 3 módulos
(um deles com `#include` próprio):

| classe de caso | o core responde HOJE |
|---|---|
| nada editado *(controle)* | nada regravado ✅ |
| 1 de 3 módulos editado, mtime > artefato | só o dump dele ✅ *(confirma a sonda de 2026-07-13)* |
| módulo editado, mtime **dentro do mesmo segundo** do `.c` | **nada regravado — o dump fica VELHO** |
| só o **include** (`.ch`) editado | **regrava o dump do dependente, e SÓ dele** ✅ |
| **dump apagado**, `.c` em dia | **não regenera** — só com `-rebuild` |

**RESOLUÇÃO DA COMPARAÇÃO ≈ 1 SEGUNDO** *(medido; é o coração do furo)*. Com o `.prg` posto a
`.c + N`: `0`, `1ms`, `100ms` → não recompila (3/3); `500ms` → instável (a fronteira do
arredondamento); `999ms`, `1s`, `2s` → recompila (3/3). Logo **edição feita no mesmo segundo em
que aquele módulo foi de fato recompilado é INVISÍVEL**, e o efeito é intermitente: quando a
chamada anterior foi no-op, o `.c` é velho e a edição aparece. Instrumentado, dentro de um lock,
sem concorrência nenhuma: `.c=…144.080` → edição `…144.395` → dump inalterado, sem a edição.

**Como MEDIR isto sem se enganar** *(a tabela saiu errada duas vezes antes de sair certa)*:
1. **mtime em NANOSSEGUNDOS** (`stat -c%y`), nunca em segundos (`%Y`) — as duas compilações
   caem no mesmo segundo e o medidor reporta "não regravou" sobre algo que regravou;
2. **nunca md5** — não distingue *"não recompilou"* de *"recompilou e deu igual"*;
3. **o mtime do arquivo editado é a VARIÁVEL do caso**, e tem de ser setado explicitamente
   (`touch -d`), senão o caso cai dentro da janela que ele mede e o resultado oscila;
4. **reset entre casos** (`-rebuild` + mtime de TODOS os fontes num instante fixo no passado):
   mtime futuro de um caso contamina o seguinte;
5. `LC_ALL=C` ao converter timestamp (locale pt_BR usa vírgula decimal e quebra o `float()`).

**Consequência para o desenho da fatia:** delegar ao `-inc` **não elimina** a heurística de
mtime que esta fatia proíbe — muda o DONO dela, e o dono decide sobre OUTRO artefato (o
`.c`; o `.ast.json` é efeito colateral do `-prgflag=-x`, e nada no incremental o observa —
por isso apagar o dump não o traz de volta). Nenhum dos dois furos é canto: o de mtime é o
regime de quem edita por MÁQUINA (a própria ferramenta aplicando um rename; o ciclo do
agente da fase A), e dump ausente é o que acontece a cada limpeza de temporário (fase H).
**O que o `-inc` faz BEM e a fatia pode contar:** o fecho de include é dele — editar um `.ch`
regrava o dump do dependente e só dele (3/3), porque o hbmk2 chama o `harbour -gd` para
detectar headers na hora de decidir (`hbmk2.prg`, `_hbmk_...` de detecção de dependências).

**A PERGUNTA QUE ABRIA A FATIA — *que fato o CORE pode dar sobre a correspondência
dump↔fonte?* — FOI RESPONDIDA** *(2026-08-07)*. Virou a fase
[X](roadmap-fases-entregues.md#arquivadas-fases-w-e-x--isolamento-do-trabalho-e-procedência-do-dump-2026-080607) (o dump declara de que
arquivos foi feito, com identidade de conteúdo) e a
[W.3](roadmap-fases-entregues.md#arquivadas-fases-w-e-x--isolamento-do-trabalho-e-procedência-do-dump-2026-080607) (o `harbour --ast-fresh` diz quais dumps ainda
valem, e o hbrefactor pergunta em vez de comparar). **O `-rebuild` incondicional saiu**: o
dump agora é reaproveitado quando corresponde, e regerado quando não.

**O QUE SOBROU DESTA FATIA — e é a metade cara.** O escopo escrito acima diz que o que se
reaproveita é *"o resultado da ANÁLISE daquele módulo — o dump vem junto, de graça"*. **A
W.3 entregou o "de graça", não o principal**: o dump deixou de ser regerado à toa, e o
ganho medido no corpus foi **~1,6x** (`contrib/xhb`, 42 módulos: `usages` 5,14 s →
3,25-3,59 s). Isso é exatamente o teto que a fatia 1 previu — geração ~35%, análise ~50% —
e o objetivo da fase (**custo proporcional ao que se TOCOU**) continua fora de alcance
enquanto a análise for refeita inteira a cada comando.

**Por onde ela começa agora**, com a dependência já satisfeita:
- o fato de correspondência **existe e é do core** (`--ast-fresh`): o mesmo veredito que
  hoje decide reusar um dump pode decidir reusar a análise daquele módulo;
- falta responder o que a fatia 1 já tinha nomeado como o duro: **o veredito de um send
  depende do PROJETO, não do módulo**. Uma análise por módulo tem um piso irredutível, e
  descobrir onde ele está é a primeira sonda — não o mecanismo (§1.7.1);
- **REGRA DO FATO, inalterada:** é proibido inventar staleness aqui. O que mudou é que
  agora existe a quem perguntar.

**FATIA 3 — CANCELADA** (era paralelizar o `unused-locals`; o comando SAIU — ver fase L no
arquivo).

**PORTÃO:** resultado **byte-idêntico** ao modo de hoje — a mesma régua de equivalência que
provou a P9 (suíte inteira verde nos dois modos).

**PORTÃO DE PROCEDÊNCIA — se alguma fatia adotar o compilador IN-PROCESS** *(levantado
2026-08-06)*. A alavanca `hb_compileFromBuf`/`hb_compMainExt` in-process, nomeada na
[spec-a](spec-a-oraculo-para-agentes.md) § A.5 como caminho para a latência, é **outra** que
a da fatia 2 (esta ataca re-analisar o que não mudou; aquela, pagar processo e I/O) e as duas
podem coexistir. O que a in-process muda, e que não estava escrito: ela linka `libhbcplr`
**na ferramenta**, e então o compilador que emite o VEREDITO passa a ser o de quando a
FERRAMENTA foi buildada — não mais o do `HB_BIN` que gerou o dump. Hoje essa procedência sai
de graça, invisível, porque o compilador é processo externo. Com a alavanca, exige-se:
1. a ferramenta AFIRMAR na partida que o compilador linkado e o do `HB_BIN` são a mesma
   versão, recusando alto quando não forem — a mesma régua do schema (§1.5 do CLAUDE.md:
   não existe degradação por versão, existe toolchain fora de passo, e isso BERRA);
2. caso de suíte que FALHE com os dois fora de passo (portão executável, §1.6 — regra sem
   portão é regra que se viola de novo).

Sem (1) e (2) a fatia não entra. A razão é a assimetria do ponto: analisador stale erra e
alguém percebe; **verificador stale APROVA** — imprime `verified` sobre uma comparação feita
pelo compilador errado. É o falso verde do `b18801e` pela outra ponta. Mecanismo já vivido:
cicatriz (b) do §5.1 — o `make` reporta "up to date" e **não relinca** após reconstruir a
`libhbcplr.a`, e o hbmk2, que embute a mesma lib, ficou stale exatamente assim.

**Riscos honestos:** (i) cache é a classe de bug mais cara que existe, e *"agiu sobre fato
velho"* é **exatamente** o que esta ferramenta promete nunca fazer — fail-closed em qualquer
dúvida; (ii) a análise pode ter um piso irredutível (o veredito de um send depende do
PROJETO, não do módulo) — se tiver, isso é **limite honesto a registrar**, não a esconder.

**PRONTO da fase:** num projeto de dezenas de módulos, um comando que toca 1 módulo custa
proporcional a **1 módulo** — com equivalência byte-idêntica provada contra o `-rebuild` de
hoje.

## A — A IA COMO CONSUMIDOR DE PRIMEIRA CLASSE (jamais FONTE de fato) — **ATIVA: A.2 entregue; A.1 ABERTA (Diego, 2026-07-24); A.3/A.4 em PORTÃO FECHADO**

Spec: **[spec-a-oraculo-para-agentes.md](spec-a-oraculo-para-agentes.md)**. Regra durável:
CLAUDE.md § 1.6.

**A tese (Diego, 2026-07-13).** O programador Harbour vai pedir a um LLM *"renomeie este
método no projeto inteiro"*. O LLM vai fazer isso por **substituição de texto** — com
confiança, e errado: homônimo entre classes, nome que também é palavra de DSL, site gerado
por diretiva, string que casa por coincidência. **É exatamente o modo de falha que o
hbrefactor existe para eliminar.** O agente não é "mais um consumidor": é o que **MAIS
PRECISA** de um oráculo de fato. **O hbrefactor é o que torna a refatoração por IA em
Harbour SEGURA** — tese de produto, não recurso.

**O enquadramento que impede a leitura errada.** LLM é máquina de **heurística**; hbrefactor
é máquina **anti-heurística**. Complementaridade: **o agente propõe a INTENÇÃO**; **a
ferramenta decide o que é PROVÁVEL, executa verificando, e recusa com MOTIVO.** A fase muda
a **SUPERFÍCIE**, jamais o motor.

> **NÃO-OBJETIVO, executável e não retórico:** a ferramenta **não tem modelo, não tem chave
> de API, não fala com rede, e NUNCA pergunta nada a um LLM**. Régua no fonte, na família do
> caso 64.

**A REFRAME — o catálogo de verbos NÃO é o produto.** O produto é o **VERIFICADOR**:
compilar antes/depois, comparar o pcode byte a byte, reverter. Essa máquina é **agnóstica de
verbo** — e estava **trancada dentro dos 12 comandos**. Um agente nunca vai querer só os 12:
ele vai querer *"converta este `DO CASE` em `SWITCH`"*. **O catálogo jamais alcança a
imaginação de um LLM; o verificador alcança — porque não sabe nem se importa com qual foi a
edição.**

### A.1 — Contrato de máquina na CLI *(base: sem isto, nada em cima se apoia)* — **EM EXECUÇÃO (2026-07-25); PASSO 1 COMPLETO; plano em [plano-a1-contrato-de-maquina.md](plano-a1-contrato-de-maquina.md)**

> **DECISÃO DE ARQUITETURA (Diego, 2026-07-24/25), final:** o CLI é consumido por **VSCode
> e Claude**, e só. A saída é o **envelope (JSON), e nada mais**. **Sem renderizador humano**
> (a prosa é arrasto → deletada); a **flag `--json` some** (sempre-envelope); `Usage()` fica
> texto puro. Ordem VERTICAL por comando (arrancar a flag agora deixaria ~1000 testes
> vermelhos de uma vez).
>
> **Estado (2026-07-25): PASSO 1 COMPLETO — os 14 comandos modelam o fato.** Os 8 de leitura
> já estavam; agora os **6 de edição** também (`rename` e a família de 7 subverbos,
> `extract-function`, `inline-local`, `reorder-params`, `annotate`, `exec-registry`):
> `edits[]` LSP `{uri,range,newText}` sob `--dry-run`, `result.locations` sempre,
> `result.verdict` (applied/preview) + `result.proof` (a força da verificação), `scope` P17
> como campo, avisos → `diagnostics[]`. **Placar PENDENTES da régua-json VAZIO (14/14).**
> `make test` 1046/0, `ppcorpus` 121/0, `site-check` verde. O desenho (para não re-derivar)
> está no plano linkado, § Passo 1.
>
> **Estado (2026-07-26): PASSO 2 EM EXECUÇÃO, e ele MUDOU DE FORMA.** Migrar assert de prosa
> para campo estruturado (`tcheck enveq`) provou-se insuficiente — o `grep` de um campo não diz
> o que a ferramenta NÃO disse, e o formato declarativo que existia (`tests/cases/`) tinha o
> esperado **GRAVADO da execução**, que congela o defeito atual em vez de afirmar o contrato.
> Ordem do Diego: **todos os testes migram para `tests/scenarios/`**, no formato especificado em
> **[tests/README.md](../tests/README.md)** — `source/` + `expected/` escritos À MÃO, a saída
> como transcrição byte a byte, o retrato `.ppo`/`.ppt` do core, e a régua do caso 64 declarada
> no próprio cenário. `make scenarios` roda só o conjunto migrado; o `make test` encadeia os dois.
>
> **Critério de pronto do passo 2 (mecânico), ATUALIZADO em 2026-07-27 com o destino
> decidido:** `tests/run.sh` sem nenhum `unit_*`, **`tests/cases/` e `tests/scenarios/`
> vazios**, `tests-go/suite/` cobrindo o que os três provavam, `make test` verde. Fila hoje:
> **137** (125 units + 12 casos; os 9 cenários acabaram, e o `scenarios.sh` MORREU em
> 2026-07-27). Quando os dois que restam esvaziarem, morrem junto o `run.sh`, o
> `casedir.sh`, o `parrun` e o `tcheck`. A fila e o que cada
> teste virou ficam no handoff § 0.
>
> **Falta: passo 2 (a migração), passo 3 (arrancar prosa+flag), passo 4 (extensão), passo 5
> (página).** Estado de retomada: handoff § 0.
>
> **Estado (2026-07-26, fim do dia): o envelope é `cli-2` e o FORMATO DE TESTE foi
> reespecificado.**
>
> **`cli-2`** ganhou dois campos, ambos por crítica do Diego ao esperado de um cenário:
> **`exit`** (que NÃO é derivável do `status` — o `verify` BROKEN sai `status: "ok"` com exit
> 1, e quem lê o stdout num pipe concluía o oposto do shell) e **`argv`** (a invocação
> inteira, para o envelope carregar o par comando/resultado). Propagado a `tcheck`, às duas
> réguas, aos 7 casos de `tests/cases/`, à spec e ao plano.
>
> **O `NameAccepted` morreu** *(ordem do Diego: "o próprio compilador vai reclamar depois")* —
> ver a fase U/A no roadmap-fases-entregues e o handoff § 0-hoje. Medido: ele recusava `while`
> como nome de LOCAL, que o projeto real aceita — falso-negativo barrando rename legítimo.
> Os erros do compilador viraram `diagnostics[]` no mesmo passo.
>
> **O formato de teste foi reespecificado** em `tests/README.md`, agora **independente de
> linguagem**, com a ordem que a sessão descobriu: *primeiro a especificação, depois cada
> implementação a partir dela* — implementar numa e traduzir para a outra produziu, três
> vezes, uma versão estranha às duas. E com **duas classes**: transformação (o hbrefactor) e
> estudo (o pp-corpus, que fica em Harbour+hbtest e não migra).
>
> **A camada de controle da suíte é GO — DECIDIDO (Diego, 2026-07-27).** A comparação
> anterior estava contaminada e foi refeita: a versão Go que existia era transliteração do
> Python, então media o custo da TRADUÇÃO. Reescrita da spec: infra 447→351 linhas de
> código, caso 26→7. **O que decidiu não foi o placar**, foram dois portões que o desenho em
> Go torna impossíveis de esquecer (§1.6 — portão executável × regra): a **vacuidade**
> deixa de existir (as duas comparações são do harness, depois da função do caso) e a
> **fixture órfã** reprova (no Python passava verde, calada). A candidata Python foi
> removida inteira. Estado, layout e comandos: handoff § 0.
>
> **A DISCIPLINA DO PASSO 2 virou FERRAMENTA (2026-07-26, ordem do Diego: *"crie ferramentas
> para garantir disciplina, que é preferível a prosa"*).** São ~127 iterações repetitivas, e
> a lei §1.6 diz que regra em prosa é regra que eu quebro — no mesmo dia eu quebrei duas.
> Então:
> - **`tcheck scenlint <dir>`** — a disciplina do cenário, sem rodá-lo: `unclassified`
>   congelado no esperado, caminho absoluto de máquina, comando sem `--json` (prosa é
>   arrasto: o passo 3 a deleta), fixture com diretiva sem `forbid`, `desc` citando número
>   de caso. Roda como prova (0) de cada cenário.
> - **`tests/scenarios.sh`** — `expected/` espelha `source/` arquivo a arquivo (ausência não
>   significa nada), e `outputs/N` é a transcrição do N-ésimo `cmd`, faltando ou sobrando
>   reprova.
> - **`.claude/hooks/formato-de-teste.sh`** — barra o commit que ACRESCENTA `unit_N` ao
>   `run.sh`/número a `ALL_UNITS`/arquivo a `tests/cases/`. Remover continua livre: o fluxo
>   é de mão única.
> - **`tools/unit-brief.py`** (o que o unit antigo prova + a coluna COMPUTADA de cada alvo;
>   `--fila` mostra o que falta) e **`tools/caso-new.sh`** (`source/` + o `.go` que registra
>   o caso). **Nenhum dos dois escreve `expected/` ou `outputs.json`, e nenhum roda o
>   hbrefactor** — ver o esperado antes de escrevê-lo transforma escrever em copiar. *(O
>   `scen-new.sh`, do formato-ponte, foi deletado em 2026-07-27: ele criava arquivos que o
>   hook agora barra no commit.)*
> - **skill `migrate-test`** (substitui a `new-fixture`, que ensinava o formato legado):
>   fina, sem duplicar o contrato, com o catálogo de erros que já custaram uma iteração.
>
> **Os portões que 2026-07-27 acrescentou** *(todos com controle negativo rodado)*: o hook
> passou a barrar `tests/scenarios/` também (os três legados só encolhem); o **harness Go**
> recusa `unclassified` congelado, artefato novo não declarado, caso que não comparou e
> **fixture órfã**; e **`tests-go/docs`** cobra que todo comando/caminho citado pela spec e
> pela skill exista — ela nasceu porque a skill ensinou `tools/scen-new.sh` e
> `make scenarios` por uma sessão inteira depois de os dois morrerem.
>
> **Critério de pronto desta fatia (mecânico):** `make test` verde com o `scenlint` ligado;
> o hook barrando `unit_` novo e passando em remoção (as duas provas rodadas); a
> `new-fixture` deletada. **✅ 2026-07-26 — `make test` 1021/0 + 10 cenários 70/0.**
>
> **Fase 1 (revisar os 10 já migrados) FEITA, e ela achou dívida:** 9 dos 10 reprovaram no
> `scenlint` recém-escrito (nenhum declarava `forbid`; três congelavam prosa).
>
> **O ENVELOPE VIROU `cli-2` (Diego, 2026-07-26), com DOIS campos novos.** Os dois vieram da
> mesma crítica dele ao esperado de um cenário — *"o resultado não me parece estruturado para
> consumo de máquina: vejo o json do comando, mas o exit desestruturado, fora"*:
> - **`exit`** — e ele **não é derivável do `status`**: medidas as 37 chamadas de `Ok()`, uma
>   devolve exit ≠ 0 (`verify` de veredito BROKEN: `status: "ok"` + exit 1, `hbrefactor.prg`
>   § Verify). Sem o campo, quem lê o stdout — o normal num pipe — concluía SUCESSO onde o
>   shell dizia falha. O modo de falha que a fase existe para eliminar, dentro do contrato.
> - **`argv`** — a invocação inteira, *"demonstrando claramente o conjunto comando/resultado"*.
>   O `command` dava o VERBO; quem lê um envelope solto não sabia sobre o quê.
>
> **Consequência no formato de teste:** `outputs/N` deixou de ser híbrido texto+JSON e passou a
> ser o **envelope PURO**, byte a byte — sem eco do comando (está no `argv`) e sem linha de
> exit (está no `exit`). O runner ganhou duas provas: o exit real do processo **contra** o
> campo, e **stderr vazio sob `--json`** (stdout e stderr agora são colhidos separados; juntá-los
> escondia violação da regra *"aviso é `diagnostics[]`, stderr só carrega falha de processo"*).
>
> **E o método pegou um defeito no caminho:** o esperado escrito à mão acusou uma **linha em
> branco a mais** em todo envelope — `hb_jsonEncode( x, .T. )` já termina em `}`+newline e as
> quatro emissões somavam `+ hb_eol()`. Removido.
>
> **`cmd` virou LISTA DE ARGV, a mesma forma do campo `argv`** *(Diego: "se o cmd no case.json
> é em um formato, por que o do output está em outro?")*. A invocação é um fato só, e
> representá-la como linha de texto de um lado e array do outro obrigava quem lê o cenário a
> traduzir de cabeça. Ganho além da simetria: **o runner perdeu o `eval`** — os argumentos vão
> direto ao binário, e argumento com espaço, aspas ou `*` deixou de ser bomba armada. A forma
> antiga (linha de texto) recusa nomeando a nova.

> **O portão abriu com uma ordem de desenho junto:** *"quero que o Claude crie a especificação
> para a interface CLI do hbrefactor que seja ideal para o Claude usá-la"* — e, na revisão,
> **"os principais consumidores do hbrefactor são o VSCode e o Claude"**. A resposta é a
> **§2.5 da spec**, com declaração de conflito de interesse (quem escreve é UM dos dois
> consumidores) e a **§2.6** listando o que eu pedi e **retirei**.
>
> **A correção do Diego mudou o desenho, não a redação.** A primeira versão dizia *"compacto por
> padrão, `--verbose` para o resto"* — o que poria o **default errado para a extensão** e criaria
> DUAS formas de envelope para testar. Regra que ficou: **flag nenhuma muda a FORMA do envelope,
> só o VOLUME** (`--limit` corta quantos itens, nunca quais campos). Um schema, e quem quer menos
> pede menos **explicitamente**.
>
> **E ela expôs um buraco:** a extensão regexa **`stderr + stdout`**, e eu havia especificado só
> o stdout. Sob `--json`, todo aviso (referência textual, macro vivo, alcance da P17) vira
> **`diagnostics[]` no envelope** e o **stderr fica só para falha de processo** — senão o
> `--json` é meia-entrega.
>
> **Escopo:** `describe --json` gerado da mesma fonte da `Usage()` (para mim é descoberta, para a
> extensão é **detecção de descompasso** no startup); flag desconhecida sempre reprova ecoando o
> conjunto válido, sem abreviação nem prefixo; **truncagem declarada**; `action` como CAMPO ao
> lado do `reason`; **incerteza como campo POSITIVO, jamais ausência** — a regra que só o
> consumidor sabe, porque ausência não me chama atenção **por construção**; `Location` LSP;
> determinismo byte a byte; **a extensão reacoplada na mesma fase**, com régua de zero regex de
> prosa nela.
>
> **O `scope` do `ast-19` entra aqui:** a P17 acabou de produzir o fato, e sob `--json` ele vira
> `scope: { complete, unseen[] }` — com `complete: true` **explícito**, senão eu leio todo rename
> como completo.
>
> **Casos novos nascem no formato de CENÁRIO** (`tests/scenarios/`, spec em
> [tests/README.md](../tests/README.md)): `source/` + `expected/` + a transcrição, todos
> escritos À MÃO, do contrato. O `tests/casedir.sh` da fase T foi o passo intermediário e é
> legado — ele provava o envelope inteiro, mas o esperado dele era GRAVADO da execução.

**A contradição que se fecha:** a ferramenta **proíbe comparação de texto no MOTOR e obriga
comparação de texto no CONSUMIDOR**. A extensão decide **fluxo** casando prosa (`/--force/`,
`/no compile-time identifier/`, `/BROKEN/` — `vscode/extension.js`), e já **quebrou
calada** quando a CLI foi traduzida. É o **mesmo padrão da fase L** (*"o compilador SABE e
joga o fato fora numa string"*), agora com a ferramenta fazendo isso com a **própria saída**.

- `--json` vira flag **global, em STDOUT** — hoje só 3 dos 12 comandos têm, e escrevem em
  **arquivo**. A forma antiga **morre**; a extensão é reacoplada **na mesma fase**.
- **Envelope único, schema versionado.** Semente pronta: `LocationsJson()` já emite
  `Location[]` no formato LSP.
- **Toda recusa carrega CÓDIGO.** `Refuse()` já é funil único. A taxonomia **separa o que
  hoje está fundido**: recusa de política × ambiente quebrado × **resposta vazia legítima** —
  hoje `usages` com **zero resultados sai `EXIT_REFUSED`**: o agente não distingue "não há
  usos" de "eu me recusei".
- **`--dry-run --json` devolve as EDIÇÕES como dado.** Absorve dois resíduos que o roadmap
  adiava por conta própria (preview da B5; `Location` estruturada para artefato derivado, da P3).

> **Restrição de desenho que vem da tese, e é a mais séria da fase:** a recusa tem de ser
> legível o bastante para o agente **RELATAR**, não para **CONTORNAR**. Um agente que recebe
> "recusado" sem entender por quê vai fazer aquilo pelo que é famoso: **editar o texto na
> mão** — e aí a ferramenta virou obstáculo que se contorna, não proteção. O código precisa
> distinguir *"pare e conte ao humano"* de *"repita com `--force`"*.

### A.2 — `verify`: o ORÁCULO EXPOSTO — ✅ **ENTREGUE (2026-07-13; caso 123, suíte 978/0, extensão 0.14.0)**

`snapshot <project>` grava a linha de base; o agente edita à vontade; `verify <project>
[--rollback]` responde `PRESERVED` (prova) / `CHANGED` (**ausência** de prova, com o delta
que o compilador viu) / `BROKEN` (`--rollback` restaura byte a byte). Narrativa completa no
[arquivo](roadmap-fases-entregues.md); duas coisas ficam AQUI porque governam o resto da
fase:

> **O LIMITE, e é o CORAÇÃO do desenho:** identidade de pcode é oráculo **DE UM LADO SÓ**.
> **`PRESERVED` é PROVA; `CHANGED` NÃO é prova de quebra** — um `extract-function` legítimo
> muda o pcode. Ler "mudou" como "está errado" seria **chutar a intenção do autor** =
> heurística. Por isso o `CHANGED` **sai com exit 0** e **nenhuma palavra de reprovação**, e
> o caso 123 trava isso com régua textual. **Não "melhore" isso.**

**Fica de fora, honesto:** a equivalência do `verify` é a **mais estrita** (identidade byte a
byte do `.hrb`). Os degraus mais frouxos que os verbos usam por dentro (`HrbEquivalent`,
`HrbExtractCheck`) **dependem de saber o que se esperava mudar** — e numa edição que a
ferramenta não fez **não existe expectativa**. Usá-los seria inventar intenção.

### A.3 — Servidor MCP *(a porta pela qual o agente entra)* — PORTÃO FECHADO

O agente do usuário chama `resolve-at`/`usages`/`rename`/`verify` como **ferramenta nativa**,
em vez de dar shell e regexar prosa.

- **Só existe DEPOIS do A.1** — MCP sobre a saída de hoje seria um regexador com outro nome.
- **CRITÉRIO DE MATAR (o teste da fase L virado contra nós):** o servidor **não pode conter
  DECISÃO**. Se precisar decidir algo que a CLI não decidiu, ele **morre** — a decisão
  pertence à ferramenta, e a necessidade dele **prova que o contrato do A.1 ficou ruim**.
  Adaptador, nunca dono de lógica.
- **Subsome o "manifesto de capacidades"**: o MCP anuncia os schemas pelo protocolo —
  descoberta em vez de decoreba, e morre a classe de bug "o manual do agente envelheceu".
- Linguagem: **Harbour** (JSON-RPC sobre stdin/stdout; `hb_jsonEncode` basta; dogfooding
  real) × **Node** (a extensão já é JS; há SDK). Inclinação: Harbour — contra honesto:
  escreveríamos o protocolo à mão.

### A.4 — `-ge2`: diagnóstico do compilador em JSON *(core; fecha a sonda da fase L)* — PORTÃO FECHADO

`-ge<mode>` **já existe** (`0=Clipper`, `1=IDE`) → **`-ge2` é MODO NOVO de opção existente**,
não flag nova. E `hb_compOutMsg()` é o **formatador único**, que **já recebe tudo desmontado**
(módulo, linha, severidade, número, template, args) — e só então **achata numa string**.

**É útil? Sim — mas o hbrefactor é o consumidor MAIS FRACO dele, e isso fica escrito.** A
ferramenta usa o compilador como **oráculo binário** e tira os fatos do **dump**. O que o
sustenta, em ordem de força: **(1)** é o **PR fácil que abre a porta do PR difícil** (a B6
pede um canal num diff grande e intrusivo; o `-ge2` é minúsculo e não-controverso, e
estabelece a narrativa *"o Harbour fala com máquinas"* ANTES do pedido grande); **(2)** o
**painel Problems** da extensão; **(3)** o agente do usuário que recebe *"conserta este
erro"*. **Limite honesto: não há COLUNA** no diagnóstico — sondar se o lexer tem, antes de
prometer. **No PR a palavra "AI" não aparece**: lá isso se chama *machine-readable
diagnostics*.

### A.5 — Latência: **o contrato sem velocidade entrega uma ferramenta que o agente não vai querer chamar**

Um humano faz 3 perguntas por hora; um agente faz 30 por minuto. Um `usages` no `work/xhb`
custa **12-15 s**. Isso **não é detalhe da fase A — é pré-requisito dela**, e é a **fase V**.
**Ordem sugerida: V.2 antes do A.3** (A.1 e A.2 são independentes).

### O que foi considerado e REJEITADO *(o teste da fase L, aplicado ANTES de escrever)*

- **Comando `describe` ("dê ao agente o mapa do projeto")** — soa ótimo e **já existe**: o
  `dump` gera os `.ast.json`. Falta ele **imprimir um caminho em vez de uma frase**. Não é
  capacidade nova; é conserto de 3 linhas dentro do A.1.
- **Regras de refatoração em linguagem natural** — é a heurística entrando pela janela. **Não.**
- **"O agente sugere onde refatorar"** — é TRIAGEM, que a REGRA DO FATO já proíbe como produto.

### Riscos honestos

1. **O `verify` vira heurística** se "mudou o pcode" for lido como "está errado". Risco nº 1.
2. **O agente contorna a recusa** que não entende — recusa ilegível não protege, só é ignorada.
3. **O rótulo é cavalo de Troia da heurística** se mal escrito → não-objetivo executável.
4. **Drift em teste PRÉ-EXISTENTE → vai ao Diego, site a site.** Dois sítios já
   identificados: `usages` com zero hits deixa de sair `1`; `--json <arquivo>` some. Quebram
   a suíte **e** a extensão.
5. **Superfície nova é peso** (régua da fase L). O envelope **não** é capacidade nova; o
   **MCP e o `verify` são**, e por isso nascem com critério de matar.
6. **Custo:** toca a saída dos 12 comandos, e o `verify` mexe no núcleo de verificação — a
   parte do fonte onde um bug é mais caro.

### PRONTO da fase (executável, se o portão abrir)

- Todo comando sob `--json` emite **um** envelope válido em stdout, e **nada mais** ali.
- **Nenhuma** decisão de fluxo da extensão casa prosa — os três regexes morrem, e um caso da
  suíte **prova** que morreram.
- Toda recusa carrega código, e o código distingue *pare* de *repita com `--force`*.
- "Zero resultados" deixa de ser recusa (com o drift aprovado pelo Diego).
- `verify` prova preservação de edição que a ferramenta NÃO fez; edição que quebra volta byte
  a byte; e um caso trava o LIMITE (edição legítima que muda o pcode → *"não provei
  preservação"*, **nunca** *"está errado"*).
- MCP: o agente lista e chama os verbos, recebe **fato**, e o servidor **não contém decisão
  nenhuma** (verificado por leitura).
- `make test` verde; `make site-check` verde.

---

# PENDÊNCIAS VIVAS (herdadas de fases encerradas)

*Cada item aqui sobreviveu ao arquivamento porque é trabalho POR FAZER, não registro.*

## Portões abertos a submeter ao Diego

- **D-P5 — migração de DSL como VERBO novo.** O instrumento existe e está PROVADO (P11: o pp
  vivo como oráculo, `__pp_init`/`__pp_process`); o desenho está pronto (P7c: o pp computa o
  texto novo com `-u`, a FERRAMENTA escreve por posição de byte a partir do span da
  statement, preservando comentário e formatação). Barrado por DUAS regras do projeto, não
  por dificuldade: é **verbo novo** (portão do Diego) e o **critério de matar do adr-003**
  (*"fato sem consumidor = fato local, não arquitetura"*). **Pergunta ao Diego, não decisão
  minha.**
- **B9 — resíduos (portão de ESCOPO):** (1) anotação de PARÂMETRO de assinatura (colapsa em
  `tokens[]`, pede o idioma `SigParamHits`; rendimento auto-escrevível baixo hoje); (2)
  candidato (f) de core ADIADO (New implícito); (3) F4.3 (escrita da execução controlada)
  **MORTA POR MEDIÇÃO** — spec na gaveta, padrão B8.

## P12 — o pp como ENGENHO DE BUSCA *(ideia do Diego, 2026-07-12; **NADA PROVADO AINDA**)*

Usar o casador do pp para **ACHAR**, não para transformar — busca estrutural, lint com regras
do usuário, codemod. O trunfo não é técnico e sim de adoção: a linguagem de consulta seria a
do `#xcommand`, que **todo programador Harbour já sabe escrever** — e quem casa é o casador
do CORE, não uma réplica. Hipótese central a sondar: o canal de fato **já existe**
(`ppApplications` + `ast-13/14/15` dão site, posições e o que casou em cada marker); falta
**injetar a regra de consulta** — e uma regra **no-op** com o `<@>` (o guarda anti-recursão)
pode registrar a aplicação **sem alterar o código**. O mecanismo de injeção/remoção com
escopo é o `ast-16` (P13). Se confirmar, a 1ª versão sai **sem mudança no core**.
Plano, usos candidatos e limites: **[pp-corpus/pp-as-search.md](pp-corpus/pp-as-search.md)**
— **o arquivo é plano, não registro.**

> **CONSUMIDOR NOMEADO pela fase A:** a primeira coisa que um agente faz antes de editar é
> **PROCURAR** — e hoje ele grepa. Busca estrutural cujo casador é o do core é capacidade de
> agente por excelência. A fase A não executa a P12; ela responde a pergunta que a P12 deixava
> no ar (*"quem consome isto?"*).

## P14 — TIPOS DECLARADOS COM ALCANCE, e o cursor que os consome *(situação levantada pelo Diego, 2026-07-13; **EXPLORATÓRIA — NADA PROVADO AINDA**)*

Plano completo: **[plano-tipos-com-alcance.md](plano-tipos-com-alcance.md)** — **o arquivo é
plano, não registro.**

**O pedido**: com três classes homônimas (todas com `METHOD Brilho()`), a COLUNA do cursor tem
de selecionar qual símbolo está em jogo em `oF:Brilho()` — cursor em `oF` dá os usos **daquele**
`oF`; cursor em `Brilho` dá declaração + definição do método **de Farol** e só os envios que
atingem Farol. A mesma máquina alimenta um **go to definition** (o `rename` já senta nela).

**Dois achados que reordenaram o trabalho:**

1. **A ferramenta JÁ resolve o receptor** — `tests/fixhom/m1.prg` é, letra por letra, o exemplo;
   `run.sh:1978-1981` já assere `confirmed send (receiver class TOTEM...)` / `excluded send
   (dispatches to FAROL:BRILHO)` para a consulta **por NOME**. **O buraco é o CURSOR**:
   `ResolveAtQuery` camada 4 (src:1924-1945) vê o `:` e devolve a consulta **NUA**, sem nunca
   perguntar o receptor. E **`run.sh:2347` fossilizou o bug como CONTRATO** (exige
   `query: Brilho`, sob o rótulo *"consulta crua honesta"* — era verdade quando foi escrito).
2. **O Harbour já tem um sistema de tipos declarados COMPLETO — e SEM ALCANCE**: a linguagem de
   anotação (`AS CLASS`), a tabela (`DECLARE`/`_HB_CLASS`/`_HB_MEMBER`/`_HB_SUPER`) e — neste
   branch — o **EXECUTOR** (`-kt`, que impõe as anotações em runtime via `__HB_CHKTYPE`).

> **O REENQUADRAMENTO que governa a fase:** *as paredes não são "não dá para inferir" — são **"o
> programador não tem como DIZER, e onde ele diz, o compilador JOGA FORA"***. Estender o Harbour
> aqui **não é ensinar o compilador a adivinhar**: é dar **alcance** às anotações e deixar o `-kt`
> executá-las. Toda parede cai **por DECLARAÇÃO**, jamais por inferência — é o **oposto** de
> heurística: em vez de *deduzir* fato, **fabrica-se fato declarado e verificado**.

**Os quatro fatos que o core descarta hoje** (cada um é um experimento):
**E1** `FUNCTION F() AS CLASS Farol` **não compila** (`harbour.y:329-335`) — e
`hb_compChkTypeRetWrap` (`hbmain.c:2845`) **já existe para impor o retorno declarado e não tem o
que impor**. É a parede do `oX := AlgumaFabrica()`, e é a **maior alavanca do sistema**.
**E2** o cast `AS CLASS` em expressão é parseado e **descartado** (`harbour.y:845-875`) — honrá-lo
dá a **saída de emergência universal**. **E3** `_HB_SUPER` é parseado e a **ação da gramática está
VAZIA** (`:1277-1278`) — o core nunca liga o pai. **E4** parâmetro já aceita `AS CLASS` e o `-kt`
já o confere: `F( @oF )` declarado **já é fato**, e a ferramenta envenena sem olhar.
A **única** parede que fica de pé é a do **macro** — e **deve** ficar: recusa honesta é produto.

**A LINHA entre FATO e PALPITE** *(decidida na sessão; é a contribuição conceitual)*: o motor
interprocedural **já existe** e está desligado (`hInter := NIL`, src:563 — portão RE.3). O
desligamento em bloco foi **certo no efeito e GROSSO na causa**. **Dedução FECHADA** (fontes
enumeráveis por construção — *todos os `RETURN` de F estão no corpo de F*) é **FATO** e pode
julgar. **Dedução ABERTA** (exige enumerar o inenumerável — *"todos os chamadores passam um
Farol"*) é **PALPITE** e só sugere: **`B7ParamType` fica desligado no veredito PARA SEMPRE**.
*Corolário: a diferença entre "a ferramenta infere" e "o core infere" **não é o repositório onde o
código mora** — o que legitima é **exaustividade + colapso-para-desconhecido**, e só isso.*

**Não é caminho — o preprocessador** *(tiro no escuro do Diego, respondido)*: ele varre todas as
linhas, mas vê **TOKENS, não PROGRAMA**. Dar-lhe tipos = **segundo parser dentro do core**
(réplica de gramática, §1.2/#2) — heurística **vestindo a autoridade do core**. E ele **já faz o
papel certo**: é ele que **DECLARA**; o compilador é quem **RESOLVE**. Os fatos já vêm dele —
morrem **depois**, sem leitor.

**Escopo** — três fases, nesta ordem (**decisão do Diego: experimentos PRIMEIRO**):
- **Fase 0 — SONDAR AS PAREDES** *(ordem do Diego: "sondar antes de decidir")*. **Zero linha de
  core**: script em `tools/` (instrumento, **não** verbo da CLI) que roda no corpus do CORE
  (`work/`) e emite o histograma dos sends por veredito e, nos desconhecidos, **o bucket do
  PORQUÊ** (`macro-message` / `funcall-no-rettype` / `cast-discarded` / `member-not-declared` /
  `param-byref-poison` / `param-untyped`). **É o portão que ORDENA a Fase 1** — se 90% for
  macro-dispatch, E1/E2 são decoração; se for retorno de fábrica, **E1 é o jogo inteiro**.
- **Fase 1 — trilha de linguagem**: E1 → E2 → E3 → E4, **na ordem da alavancagem MEDIDA**, cada um
  gateado pelo que já existe (`fAst` / `-kt`) → **sintaxe nova nunca quebra código velho**. Fecha
  com **E5**: re-medir e decidir **com prova** o que vai ao PR da B6.
- **Fase 2 — o cursor**: coluna exata da mensagem no sítio de envio + classe do receptor **por
  sítio** vindas do core (`comptype.c` novo, `ast-17`); `ResolveAtQuery` passa a **perguntar o
  receptor**; `usages` ganha **recorte por escopo** (reusando o `FuncAtLine` que o `rename` já
  usa — hoje o `usages` **vaza homônimos de outras funções**); verbo novo **`definition`** +
  **`DefinitionProvider`** na extensão VSCode.

**Critério de pronto (mecânico)**:
- Fase 0: o histograma roda no corpus e **cada experimento da Fase 1 tem um NÚMERO atrás dele**.
  **Nenhum experimento sobe sem esse número.** *(Número vive aqui e na spec — **nunca em página**,
  §4.)*
- Fase 1: por experimento — contagem de conflitos do bison **INALTERADA**; pcode **byte-idêntico**
  sem as flags; e, sob `-kt`, a **anotação mentirosa ESTOURA** com o sítio nomeado.
- Fase 2: cursor em `oF` lista só o `oF` daquela função; cursor em `Brilho` dá
  `query: Farol:Brilho` com `oT`/`oI` **excluded**; `definition` sai **1 com motivo ACIONÁVEL** no
  receptor desconhecido (**nada de lista de candidatos — isso é TRIAGEM**); casos 72/73/74/84/85/86
  **byte-idênticos** (divergência = **BUG**, não contrato); régua adversarial do caso 64
  **estendida ao `comptype.c` do core**.

> ⚠️ **DRIFT PRÉ-EXISTENTE, a submeter ao Diego ANTES de re-baselinar** (§3): `run.sh:2347`
> (o assert que **codifica o bug como contrato**), o `rename` a partir de um send (passa a
> **não** renomear homônimos — é conserto), e o `TokenCols()` que casa por TEXTO e aponta
> **todas** as colunas da linha (muda `Location[]` existente).

> **W0026 fica FORA** (`hbgenerr.c:114-150`, **zero emissores**): o `comptype.c` **é** a máquina que
> falta a ele, mas ligá-lo mudaria a saída do `harbour -w3` **STOCK**. Fase própria, **depois do
> B6**, atrás de flag opt-in — e **só depois de E3**.

## P15 — o PROFILER do core, e a pergunta da COBERTURA *(pista do Diego, 2026-07-13; **EXPLORATÓRIA — NADA EXPLORADO AINDA**)*

**O arquivo a abrir**: `~/devel/harbour-core/harbour/tests/profiler.prg` — o driver; a camada
de relatório é `src/rtl/profiler.prg` (classes `HBProfile*`, `CREATE CLASS`), e o canal do VM é
`__SetProfiler( <lLiga> )` (hvm.c:12343). **A pista do Diego**: *"ele pode até ser ou ajudar a
criar cobertura de código"*.

**O que o canal dá HOJE** *(lido no fonte, não suposto)*: contadores no VM — por **função**
(símbolo, via `__dynsGetPrf()`), por **método** (classes.c) e por **opcode** (globais
`hb_ulOpcodesCalls`/`hb_ulOpcodesTime`, hvm.c:1342-1357), cada um com **chamadas + ticks**. O
opcode é **agregado no processo inteiro**, não por site. Build gated por `HB_NO_PROFILER`.

**Logo, a leitura honesta antes de sonhar**: a granularidade nativa é
**função/método chamado ≥ 1 vez** — isso é *alcançabilidade de símbolo*, **não** cobertura de
linha, de site nem de ramo. A pergunta da exploração é a de sempre (§1.2): **o core passa a
contar por SITE/LINHA?** (o pcode já carrega `HB_P_LINE`; um contador por linha/por site de
chamada é **hipótese plausível, não fato**) — e a resposta certa, se ele não conta, é
**estender o core**, nunca inferir cobertura na ferramenta.

**Consumos a avaliar** (nenhum aprovado):
- **Cobertura da nossa própria suíte** — ferramenta de PROCESSO nosso, fora do produto: qual
  código de `src/hbrefactor.prg` os 120+ casos nunca executam. É o uso de menor risco e o que
  não precisa passar pelo portão da Fase D.
- **Cobertura como fato do PROJETO DO USUÁRIO** — aí sim é produto, e cai direto no portão
  abaixo.

> ⚠️ **PORTÃO HERDADO — leia a Fase D antes de escrever uma linha**: evidência de execução como
> camada que *prioriza conferência manual* é **TRIAGEM, e triagem não é produto** (fechado pelo
> Diego, 2026-07-08). Cobertura só volta com **consumo 100% fato** (ex.: alimentar cheque
> imposto/verificação, não "olhe aqui primeiro"). **Um fato de execução não vira veredito
> sozinho**: "nunca executado" ≠ "morto" (`possible` continua `possible`).

## P-AUDIT — fila remanescente da varredura anti-heurística

A varredura de 2026-07-12 fechou A1-A4 (todos entregues). **Sobra na fila:**

- **(i) `ResolveInclude`** — re-implementa a busca de include do compilador (gatilho 4). Hoje
  inofensivo porque o dump já traz o caminho RESOLVIDO (`hb_pp_FileNew` reescreve
  `szFileName`, ppcore.c:2945-3060), mas é **cópia degradada por design**: ou morre, ou passa
  a consumir `ModuleDeps`/`harbour -gd`.
- **(iii)** varrer os *"se não é X, então é Y"* (gatilho 3) e as comparações de TEXTO onde o
  dump já tem número/id (gatilho 1).
- **(v)** toda chave OPCIONAL do dump lida SEM `hb_HGetDef` (`marker`, `ruletok`, `from`,
  `col`, `undoes`, `generates`) — acesso direto é **BASE/1132 em produção** e a suíte não
  pega.
- **`HeadClashWitness` fica sob vigilância** (passou na auditoria, não é achado): quem julga
  cada candidato é o pp vivo, mas a **completude do conjunto de candidatos** é raciocínio meu
  sobre o core (`hb_pp_tokenValueCmp`, ppcore.c:2704) — verdadeiro hoje, auditável sempre.
- **Hipótese registrada (não consegui quebrar):** família `y` (case-sensitive) — a ferramenta
  uniformiza toda palavra de regra com `Upper()` e fundiria duas regras `y` que o core vê como
  distintas. **Erro fail-closed, sem quebra demonstrada.**

> **A P-AUDIT é para uma SESSÃO DEDICADA E LIMPA** — prompt pronto em
> [prompt-revisao-anti-heuristica.md](prompt-revisao-anti-heuristica.md). Não a rode como
> apêndice de uma entrega: **quem acabou de escrever o código é o pior juiz dele.**

## P-DOC — corpus explicativo do PP *(ESSENCIAL, ordem do Diego; RETOMÁVEL)*

Bateria que casa diretivas REAIS do Harbour com seus `.ppo` e `.ppt`, explicando também para
o **programador Harbour** — fonte de conhecimento do pp para o Diego, para o usuário e para
as próprias fatias. Método = os QUATRO oráculos (`.ppo` + `.ppt` + dump + fixture
COMPILÁVEL); suíte SEPARADA do contrato (`make ppcorpus`, não `make test`).
**Famílias 1-4 entregues** (SET EXACT, @…SAY, STORE, hbclass) + as do eixo P (markers, `<@>`,
regra-que-gera-regra, derivação, estrutura, abreviação, instrumento, escopo). **Regra de lacuna — TROCADA pelo Diego em 2026-07-13**: era *"a lacuna PAUSA a exploração e vira
experimento de core imediato"* (foi ela que pariu o rename-DATA); passa a ser **PROVE, MARQUE e
SIGA** — repro executável + fase no roadmap com critério de pronto, e o conserto vira **fatia
própria sob autorização**. Motivo: a exploração dos **USOS** produz lacuna mais rápido do que se
conserta, parar a cada uma mata o mapa (que é o produto da fase), e consertar no calor do achado
é como se pula o portão. *(Exceção: achado em que a ferramenta QUEBRA código do usuário sobe na
hora — urgência de aviso ≠ urgência de conserto.)* Régua completa:
[pp-corpus/README.md](pp-corpus/README.md). Spec: [spec-pdoc-corpus-pp.md](spec-pdoc-corpus-pp.md); corpus vivo:
[pp-corpus/README.md](pp-corpus/README.md).

**Família de MEDIÇÃO ✅ (2026-07-13) — e o veredito que ela derrubou.** O alvo previsto (o
`hbct` como "contrib rico") **não existe**: medido, o hbct não declara **uma** diretiva de
comando. A medição foi feita onde as diretivas de fato estão — dump do core sobre os **33
headers do ecossistema que declaram diretiva**, **4.582 regras distintas** — e derrubou uma
**recusa documentada do P4/P5**: o mkind `strdump` *"não existe em regra"* é **FALSO**. Ele é o
**`#<x>`** (`ppcore.c:4277`), **31 regras** o emitem e **6 estão no `std.ch`** — auto-incluído
em todo programa Harbour (`MENU TO`, `SET COLOR TO`, `RELEASE ALL LIKE`, `RUN`, `JOIN`). Placar
real dos mkinds: **14 consumidos, 1 recusado** (só o `dynval`). Guarda: `corpus_strdump`
(`make ppcorpus` 47/0); conhecimento: [pp-corpus/strdump.md](pp-corpus/strdump.md).

**Família TEXT/ENDTEXT ✅ (2026-07-13) — LACUNA REAL achada e FECHADA no core (`ast-17`).** Num
bloco de stream (`TEXT…ENDTEXT`, `#pragma __text|__stream|__cstream`) o fonte do programador
**vira DADO**: cada linha crua sai como string (o pp FABRICA um marker `strdump`,
`ppcore.c:5821`). E essas strings chegavam ao dump com **`line: 0`, `col: null`, `prov: "n"`** —
**sem origem nenhuma** —, enquanto uma string comum do fonte vem posicionada. Não era regra de
string: era a maquinaria de stream **descartando** a linha que ela acabara de ler.
**Por que é correção**: o conteúdo é dado e a ferramenta **não o edita nem com opt-in** (§1) —
mas sem posição ela não podia sequer **RELATAR**. Renomear um símbolo homônimo deixava o bloco
dizendo a coisa antiga **em silêncio**, e nada no mundo podia avisar. **`ast-17`** (em
`hb_pp_tokenAddStreamFunc`, gated por `fTrackPos`): a linha do bloco chega com a sua linha-fonte
e `prov: "s"`. Expansão intacta — `make test` **990/0**, `make ppcorpus` **53/0**. Guarda:
`corpus_text`; conhecimento: [pp-corpus/text-stream.md](pp-corpus/text-stream.md).
*(Commit do core pendente de autorização.)*
> **Correção de rumo (P16, 2026-07-22):** a frase "sem posição ela não podia RELATAR" acima era
> a MOTIVAÇÃO errada. Tudo num bloco de stream é TEXTO — uma palavra igual a um símbolo é
> coincidência, não ocorrência —, então não há o que RELATAR. A posição da linha do bloco serve
> para **SUPRIMIR** o dado (não confundi-lo com uma referência), nunca para relatá-lo. Ver § P16.

**Família DEFINE DINÂMICO ✅ (2026-07-13) — a última recusa de mkind, agora MEDIDA.** O `dynval`
**sobreviveu** à medição que matou a do `strdump`: **0 em 4.582 regras** reais; as únicas duas
são builtin do pp (`__FILE__`/`__LINE__`, `ppcore.c:7253`), e o dump **as exporta**, com cada
aplicação e a sua linha. *(Correção de fato: o `ast-schema` listava `__DATE__` como dinâmico —
não é; dinâmicos são dois, e só dois.)* **O achado é a SENSIBILIDADE A POSIÇÃO**: `__LINE__`
vale a linha corrente, logo **todo verbo que desloca linhas muda o programa** — verificado, o
`extract-function` mudou o valor de 12 para 11. **E isso NÃO é bug**: o statement mudou de linha
mesmo, e a ferramenta não alegou preservação (o verbo cria função nova; identidade de pcode
nunca esteve na mesa). O que falta é o **aviso**. Guarda: `corpus_dyn` (`make ppcorpus` 58/0);
conhecimento: [pp-corpus/dynval.md](pp-corpus/dynval.md).

### P16 — o relato do NÃO-VERIFICÁVEL *(aberto 2026-07-13; **✅ ENTREGUE 2026-07-22, `ast-18`, casos 125/126/127**)*

> **Estado:** as três frentes fecharam, **cada uma sobre um FATO NOVO do core** (`ast-18`), não
> sobre inferência na ferramenta. A escolha do Diego, quando falta o fato, é **sempre estender o
> core** (2026-07-22) — foi ela que reescreveu a fase: a primeira tentativa punha discriminadores
> por FORMA (`col == 0` para dado, `head == "__LINE__"` para dynval, varredura de `&nome` na
> string) e o Diego cortou. Numa **segunda passada** o Diego cortou também a própria PREMISSA da
> (a): eu havia feito o `usages` *buscar* o nome dentro do dado e relatar *"occurrence in data"* —
> mas tudo num bloco de stream é TEXTO, e casar as letras do símbolo contra o dado é gatilho 1
> (identidade por texto). A (a) virou **SUPRESSÃO**: o fato `op:"stream"` serve para o `usages`
> **calar** sobre o dado, não para relatá-lo. `make test` **1015/0**, `make ppcorpus` **117/0**,
> `corerefs` reconciliado (as citações de `ppcore.c` andaram +34 e foram corrigidas).

**Escopo**: o `usages` (e o relatório dos verbos de edição) tratam com honestidade o que a
ferramenta enxerga mas não pode verificar — **suprimindo** o que é dado e **avisando** onde há
acoplamento real. **Três frentes, o mesmo dever** (§1 do CLAUDE.md: *jamais edição automática do
não-verificável; a ferramenta consome fato, nunca busca texto*):
- **(a) DADO de bloco de stream — SUPRESSÃO por fato** ✅. **FATO (`ast-18`):** a string do bloco
  carrega `from` com `op: "stream"` (`app: null`) — o selo declarado que a marca como dado
  (`hb_pp_drvAddStream` em `ppcore.c`, gated por `fTrackPos`). **O que o fato faz:** o relato
  *"possible reference in string"* existe para um mecanismo real (string escrita igual a um nome
  → chamada-por-nome via `&()`/`__mvGet`); uma linha de bloco igual a um nome NÃO tem esse
  mecanismo — é dado impresso. O `IsDataTok` (consome o selo, segue o `clone` do re-scan até a
  origem selada) deixa o `usages` **calar** sobre a linha de dado por FATO, sem inferir data-ness
  pela FORMA (`col == 0`) nem buscar o nome dentro do dado. **A tentativa anterior — buscar o nome
  no dado e relatar "occurrence in data" — era heurística (gatilho 1) e foi REMOVIDA** (`DataHits`
  não existe mais). Caso 125: a string escrita dispara "reference in string"; a mesma palavra no
  bloco é silenciada pelo fato.
- **(b) módulo SENSÍVEL A POSIÇÃO** ✅ — o que expande `__LINE__`. **FATO (`ast-18`):** o `from` do
  `dynval` ganhou `axis` (`"line"`/`"file"`), gravado no próprio ramo da expansão
  (`hb_pp_drvAddDyn` recebe o eixo). `DynLineSites` filtra por `axis == "line"` — o casamento do
  nome `__LINE__` foi **removido**. O `extract-function` e o `inline-local` (verbos que deslocam
  linhas) avisam *"this module expands __LINE__ at N site(s)… the new values are correct"*; o
  `rename` (não desloca) fica mudo (caso 126). *(O lado do FATO da proveniência do `dynval` — o
  `from` com `op: "dynval"` — já viera no `ast-17`; o `axis` é o que o CONSUMO pedia.)*
- **(c) STRING que é MACRO VIVO** ✅ — uma string literal com `&nome` é **reavaliada em runtime** e
  vale o memvar. **FATO (`ast-18`):** o token da string carrega `macrovars` — a lista de nomes que
  ela macro-referencia, extraída pelo compilador com a mesma **extração de `&nome`** do pcode
  `HB_P_MACROTEXT` (`hb_compAstWriteMacroVars`, gated por `HB_SUPPORT_MACROTEXT`; some sob `-kM`).
  *Limite honesto: é a extração LÉXICA do nome, não o teste de escopo do compilador — sob `-kd` um
  LOCAL macro-declarado entra na lista (o modo de falha é um AVISO a mais, nunca edição errada).*
  `MacroLiveHits`
  CASA o nome contra a lista — **sem ler o texto da string** (a varredura de `&nome` foi
  descartada antes de nascer). O `rename` de memvar nomeia cada string, com arquivo:linha e o
  **porquê** (*"macro-expanded at RUN TIME… will NOT be edited"*), no projeto inteiro (caso 127).
**A régua do §1 é dura e vale inteira**: detecção e relato preciso, **jamais** edição automática
— nem com opt-in. O relato é aviso ao humano/agente, não sugestão de edição.
**Critério de pronto (mecânico)** ✅: casos 125/126/127 verdes; cada frente consome um FATO do
`ast-18` (nenhum discriminador por forma, nenhuma busca de texto no dado sobrevive no fonte);
nenhuma palavra de fixture em `src/hbrefactor.prg` (régua do caso 64); `make test` verde (1015/0).

> **Endurecimento pós-revisão (2026-07-23, `make test` 1017/0):** a revisão dos commits `ast-17`/
> `ast-18` achou dois FATOS load-bearing **sem portão** — o consumo passava mas nada reprovava se a
> lógica sumisse. Fechados com portão executável (provado amputando a lógica na ferramenta e vendo
> o check exato cair):
> - **caso 125** ganhou `fixdado/eco.prg`: uma regra re-escaneia o bloco de stream e **clona** a
>   linha; o selo `op:"stream"` fica UM SALTO ATRÁS (medido: 0 em `tokens[]`, 1 em
>   `ppApplications[]`), então só a **recursão** de `IsDataTok` o alcança — antes, zero cobertura
>   desse caminho, que é o único vivo quando há regra sobre o stream.
> - **caso 126** ganhou um `__FILE__` na `fixpos`: as duas builtins são `dynval` e chegam com o
>   mesmo `from op:"dynval"`; só o `axis` (o ÚNICO acréscimo do `ast-18` nesta frente) as separa —
>   sem um sítio de eixo `file`, o filtro `axis == "line"` era no-op e a suíte passava sem prová-lo.
> - **doc-honesto (achado 2):** a frase "extraída com a MESMA regra do pcode" (aqui, no
>   `ast-schema.md` e no comentário do `compast.c`) era forte demais — o emissor re-deriva o `&nome`
>   LÉXICO mas **não** faz o teste de escopo do compilador (`hb_compVariableScope`), então sob `-kd`
>   sobre-lista um LOCAL como se fosse memvar de runtime (provado por sonda). Rebaixada ao limite
>   real; o fato semântico exato (só os nomes que viraram `HB_P_MACROTEXT`) fica como melhoria de
>   core não-urgente (modo de falha é AVISO sob flag não-padrão, nunca edição errada).

### Fase CIT — citações do core à prova de rot *(aberta 2026-07-23 pela revisão do `ast-18`; **✅ CONCLUÍDA 2026-07-23 — `make test` 1017/0, `make ppcorpus` 118/0**)*

> **✅ FEITO (2026-07-23) — a raiz:** a regra *"citou `arquivo:linha`? registra no `corerefs`"*
> guardava o SINTOMA — mantinha a citação frágil honesta em vez de matar a fragilidade, e
> normalizava citar linha (paguei a esteira "+6" nesta própria revisão). Invertida (ordem do Diego):
> **cita-se o NOME DA FUNÇÃO, nunca a linha.** `tests/corerefs.txt` virou `arquivo <TAB> função
> <TAB> trecho`; a guarda `corpus_refs` (`tests/ppcorpus.sh`) extrai o corpo da função (assinatura
> em col 0 até `}` em col 0) e confere o trecho DENTRO dele. **Provado** num mini-core: imune a 80
> linhas de deslocamento (o antigo acusaria 21 podres), e reprova alto e preciso em renomeação de
> função ou sumiço do trecho — os eventos semânticos que a doc DEVE rastrear. A prescrição do método
> (`spec-pdoc-corpus-pp.md`) foi virada junto. `make ppcorpus` 117/0.

**✅ FEITO — as citações inline em COMENTÁRIO.** O `corerefs.txt` guardava só o que está
registrado nele; as citações soltas em comentário ninguém conferia, e a varredura achou-as **todas
podres** (apontavam pré-`ast-17`; a de `hbclass.ch` já apontava para **linha vazia**). Convertidas
para o NOME em **13 fixtures + 5 comentários do `run.sh`**:
- `ppcore.c` → `hb_pp_matchResultLstAdd`, `hb_pp_pragmaNew`, `hb_pp_preprocessToken`,
  `hb_pp_initDynDefines`, `hb_pp_tokenGet`, `hb_pp_resultMarkerNew`, `hb_pp_trackRuleRec`;
  `ppcomp.c` → `hb_pp_CompilerSwitch`; `pplib.c` → `__PP_INIT`, `hb_pp_Destructor`;
  `hbmain.c` → `hb_compMethodAdd`; `classes.c` → `msgClassSel`; `harbour.y` → a regra
  `Declaration:`; os `.ch` do core → a diretiva pelo nome (`#command STORE <v> TO`,
  `#command SET EXACT`, `#command @ … SAY`, `#command PUBLIC`, `#xtranslate __FP_DIM`, `AS CLASS`);
  `hbpp.h` → o `#define HB_PP_MAX_CYCLES`.
- Nenhuma entrada nova no `corerefs` foi precisa: as funções citadas **já estavam** lá (o corpus
  `.md` as citava), então a conversão herdou a guarda.

**✅ Portão de entrada** (§1.6 — regra nova sem portão novo é regra que se viola de novo):
`corpus_noline` em `tests/ppcorpus.sh` REPROVA qualquer citação de core por número de linha em
fixture/`run.sh`/`corerefs`. **Provado nos dois sentidos**: passa hoje, e ao reintroduzir um
`ppcore.c:NNN` numa fixture ele berra nomeando arquivo, linha e conteúdo. Distingue core de fixture
própria — nenhum fixture nosso é `.c`/`.y`/`.h`, e entre os `.ch` só os do core contam (`menu.ch:8`,
`p6.ch:13` etc. são **saída esperada da ferramenta** sobre fixture nossa, e seguem intactos).

**Critério de pronto (mecânico)** ✅: `corpus_noline` verde; `corpus_refs` função-ancorado verde;
`make test` **1017/0**, `make ppcorpus` **118/0** (que recompila todas as fixtures do corpus).
Sem superfície de CLI nova → extensão não afetada.

### P-REV — a REVISÃO do corpus para o método v2 *(aberta 2026-07-14; **EIXO DIRETIVA CONCLUÍDO 2026-07-15 — 31 selos, 0 pendentes; segue no eixo COMPLETUDE**)*

**Por que existe:** o corpus antigo nasceu no método velho — conhecimento no markdown, prova por
`grep` no `.ppo`. O Diego pegou, num único arquivo, **três frases falsas** e um comentário que
**afirmava mais do que o teste provava**. *"Esta documentação é séria"* — e ela vai **treinar o
Claude do futuro**: o que estiver torto aqui vira erro herdado.

**O método v2** (régua completa: [pp-corpus/METODO.md](pp-corpus/METODO.md) § 4b): o
conhecimento mora no **`.prg`**, que **compila, RODA e se afirma** (`hbtest`); o comentário
**INTERPRETA** o oráculo (não o transcreve, não vira ensaio); e nada se afirma sem (a) assert,
(b) oráculo, ou (c) citação do core com `arquivo:linha`.

**Marcação MECÂNICA** *(ordem do Diego)*: fixture revisada leva o selo `METODO-V2(<data>)` no
cabeçalho, e a guarda **`corpus_metodo`** (em `make ppcorpus`) **imprime o placar e NOMEIA a
fila** a cada execução — a pendência não some de vista. Ela **reprova selo mentiroso** (arquivo
selado sem assert próprio nem irmão que asserte).

**DOIS EIXOS, e o segundo depende do primeiro** *(2026-07-15)*. Provar a **diretiva** (camadas
A/B) não fecha a família: falta provar que o **loop dos quatro oráculos rodou até não sobrar
buraco** (METODO §5b/§7). São duas provas, ordem parcial — não se julga a completude da AST de
uma diretiva ainda não provada:

| eixo | guarda | o que prova | estado (2026-07-15) |
|---|---|---|---|
| **diretiva** | `corpus_metodo` | a diretiva VIRA (texto) e VALE (runtime) | ✅ **31 selos · fila VAZIA (0 pendentes)** — `ppc-instr`/`ppc-live`/`ppc-pragma` + os 3 `fix*` fechados 2026-07-15 |
| **completude** | `corpus_completude` | o loop dos 4 oráculos convergiu (§5b respondida no dump) | ✅ **21 vereditos · fila VAZIA (0 pendentes)** — 2 HOLE (`ppc-strfam`=P18, `ppc-pragma`=P19) + 19 COMPLETE (o `ppc-dyn` transitou `HOLE:P16 → COMPLETE` com o `ast-17`), fechados 2026-07-15 |

Ambas as filas são **NOMEADAS a cada `make ppcorpus`** (não-bloqueantes; reprovam só selo/veredito
mentiroso) — não congelar aqui, ler do guarda. Vereditos de completude: `COMPLETE(data)` /
`HOLE=Pxx` (aponta a fase que fecha o buraco) / `⏳` (V2 feito, loop não rodou) / `—` (V2 não
feito → n/a). Exemplo da forma:

| família | diretiva | completude |
|---|---|---|
| `ppc-dyn` | ✅ 07-15 | ✅ `COMPLETE` (o `ast-17` povoou o `from` do dynval) |
| `ppc-deriv` | ✅ 07-15 | ✅ `COMPLETE` (espelho do buraco do dynval) |
| `ppc-instr` | ✅ 07-15 | ✅ `COMPLETE` (o `-u`/`-gd` é instrumento; o resultado está na AST) |

⚠️ **Cuidado à parte — RESOLVIDO 2026-07-15**: `markers`, `rule-structure` e `abbreviation` usam
fixtures de `tests/fix*` **compartilhadas com o contrato** (`make test`, casos 111/113/115). O
drift foi apresentado ao Diego (o casos são line-anchored) e a decisão dele foi **re-baseline com
header no topo**: o selo `METODO-V2` entrou no topo de `mk.prg`/`p6.prg`/`abr.prg` e **todos os
anchors `.prg` do `run.sh` foram deslocados** pelo offset do header (mk +11, p6 +6, abr +9;
colunas e refs `.ch` intactas). A camada B de cada uma vive num **irmão inerte** (`mkrun.prg`/
`p6run.prg`/`abrrun.prg`, fora do `.hbp`, rodado pela guarda). `make test` segue **990/0**.
> **O selo de COMPLETUDE das três (2026-07-15) NÃO repetiu o deslocamento**: ele entrou no
> topo do **runner inerte** (`mkrun`/`p6run`/`abrrun`), que o `run.sh` não ancora e o
> `corpus_completude` lê junto — zero anchor mexido, `make test` intacto. As três fecharam
> `COMPLETE` (mkinds no dump; regra `head null` + multi-passe em `ppApplications`; `ruletok`
> do ast-15 diz qual literal casou, então a ferramenta não replica a abreviação dBase).

**Critério de pronto (mecânico) — eixo diretiva**: `corpus_metodo` acusa **0 pendentes**; toda
família tem guarda que **RODA** o `.prg` (não só `grep`); todo `.md` de família cabe em índice +
lacunas.

### P-COMPLETUDE — o LOOP dos oráculos rodou até não sobrar buraco? *(aberta 2026-07-15; **CRITÉRIO ATINGIDO 2026-07-15 — fila VAZIA, 21/21**)*

> **Estado:** as 21 famílias `METODO-V2` rodaram o loop e registraram veredito — **2 HOLE**
> (`ppc-strfam`=P18, `ppc-pragma`=P19) e **19 COMPLETE**, todos com rastro executável de polaridade
> casada. `corpus_completude` acusa **0 pendentes, 0 mal-formados**; `make test` **990/0**,
> `make ppcorpus` **117/0**. **O piloto `from`-no-dynval foi ENTREGUE (2026-07-15, `ast-17`):** o
> `ppc-dyn` transitou `HOLE:P16 → COMPLETE`. O CONSUMO da P16 (a/b/c) foi **ENTREGUE em 2026-07-22**
> (`ast-18`, casos 125/126/127 — ver § P16); restam os dois HOLE vivos (P18, P19), cada um sua
> fatia própria.

**Por que existe:** a P-REV provou a **diretiva** de cada família (camadas A/B) mas **nunca rodou o
loop dos quatro oráculos** — entender via `.ppo`/`.ppt`/dump/fixture, e quando um oráculo **falta
informação, melhorar o oráculo** (estender o core), até não sobrar buraco (METODO §5b/§7). O buraco
do `dynval` (o literal do `__LINE__` chega ao statement AST **sem `from`** de volta à origem) foi
achado **por sorte**, não pelo método. Regra: "regra nova sem portão novo é regra que eu vou violar
de novo" (CLAUDE.md §1.6).

**A infra (entregue 2026-07-15) — o loop vive no METODO §5b (o passo a passo) e é cobrado pelo
portão `corpus_completude`.** *(Um skill dedicado foi tentado e DESCARTADO, 2026-07-15: o baseline
mostrou agentes rodando o loop **sem** ele — o portão + o METODO §5b já bastam. "Se dá para o portão
cobrar, não é doc: automatize" — writing-skills.)*
- o **portão `corpus_completude`** cobra, por família, um veredito de **rastro executável de
  polaridade casada**: selo `// COMPLETUDE(<data>): COMPLETE|HOLE=Pxx` na fixture **casado** com um
  check tagueado `COMPLETUDE(<fam>=COMPLETE|HOLE:Pxx)` no guarda — `COMPLETE` ⟺ o check **lê a AST**;
  `HOLE=Pxx` ⟺ check **negativo** + `### Pxx` vivo aqui. Não-bloqueante (nomeia a fila), reprova só
  a mentira estrutural.

**A fila:** toda família `METODO-V2` roda o loop e registra o veredito. **O piloto — ENTREGUE
(2026-07-15):** `from`-no-dynval (a extensão de core da **P16 (b)**) fechou o buraco do `ppc-dyn`.
`hb_pp_drvAddDyn` (`src/pp/ppcore.c`, gated por `fTrackPos`) grava um item `from` com `op: "dynval"`
no literal sintetizado por `__LINE__`/`__FILE__`, ligando-o à aplicação da regra builtin —
independente da linha; o emissor `compast.c` mapeia `'d' → "dynval"`; o schema subiu `ast-16 →
ast-17` nos DOIS repos no mesmo passo (heala o esquecimento do stream, que shipara `ast-17` no doc
mas `ast-16` na string). A asserção negativa do `corpus_dyn` inverteu para positiva. `make test`
byte-idêntico (**990/0**, caso 122 verde), `make ppcorpus` **117/0**.

**Critério de pronto (mecânico):** `corpus_completude` acusa **0 vereditos mal-formados** e a **fila
vazia** (toda família V2 com um `COMPLETUDE` casado e verificado).

### P-NOVOS — continuar avançando nos casos do core *(a fila que a revisão não substitui)*

O combinado com o Diego: **revisar o que existe E seguir achando o que falta**. A fila de
espécimes está em [pp-corpus/uses-core.md](pp-corpus/uses-core.md), e a ordem de estudo dos
testes do próprio pp está em [pp-corpus/METODO.md](pp-corpus/METODO.md) § 2b —
`tests/pragma.prg` (a superfície do `#pragma`, **começada e estacionada**), `tests/ppapi.prg` e
`tests/hbpp/` (o pp vivo, caminho do P12). Achado recente que virou família:
[pass-cycle.md](pp-corpus/pass-cycle.md) — *o pp esgota o comando antes de avançar de linha*
(levantado pelo Diego, provado no fonte e nos três oráculos).

### P23 — MACRO: a fronteira declarada, e a pesquisa que fica para depois *(aberto 2026-07-27; **PESQUISA — não bloqueia nada**)*

**A decisão que a abre** *(Diego, 2026-07-27)*: macro é run time, e com o conhecimento atual do
compilador **não dá para controlar**. A ferramenta é limitada nisso, do mesmo jeito que é
limitada diante de um programa que compila código novo em run time e o usa em seguida. Fingir
controle é pior que declarar o limite.

**O que isto significa na prática, e é o produto todo:** `verified` quer dizer *"verificado
contra o que a COMPILAÇÃO enxerga"*. Não é mentira — é **escopo**, e escopo só é honesto quando
está **escrito onde o usuário lê**. Enquanto não estiver, o `verified` promete demais.

**Escopo desta fase (documentação, não código)**
- `docs/manual.md` e `CHANGELOG.md` dizem, na voz do programador Harbour: *o que a ferramenta
  NÃO vê* — macro (`&`), `hb_macroBlock`, e chamada por nome via RTL (`__mvGet`, `Type`).
- O mesmo limite vale para **memvar**, por decisão do Diego (*"memvar é um code smell; é
  aceitável que sejamos limitados também"*).

**O que a pesquisa avançada investigaria (nada disso é compromisso)**
- operando de macro **constante** — o dump já traz `&( "x" )` e a cadeia
  `MACRO(val=V)` → atribuição → `PLUS(STRING,STRING)`; o core poderia publicar o texto
  resolvido, e aí o sítio deixa de ser desconhecido e vira fato;
- a família RTL (`s_stdFunc` em `hbfunchk.c`, onde o `TYPE` já mora) marcando *"esta função
  alcança símbolo por nome"* — de quebra o compilador ganharia aviso de acesso por nome, que é
  armadilha real com `-gh`;
- o que **nunca** será alcançável: texto vindo de parâmetro, arquivo, banco ou entrada.

**Critério de pronto (mecânico)**: o limite escrito no manual e no CHANGELOG, com as três
famílias nomeadas; nenhum código de recusa fundado em macro no fonte.

### P22 — `possible reference in string` é HEURÍSTICA e MORRE *(aberto 2026-07-27; **EM CURSO**)*

**A régua do Diego, 2026-07-27:** *"se o compilador é capaz de detectar, o hbrefactor trata"*
— podendo estender o core, que é onde a AST nasce. **E o inverso:** *"está fora do escopo do
hbrefactor lidar com fatos frágeis e de responsabilidade do desenvolvedor, como simplesmente
colocar o nome de uma variável (sem usar técnicas de macro) dentro de uma string"*.

**O que existe hoje é o lado errado dos dois.** [hbrefactor.prg:1032](../src/hbrefactor.prg)
casa `Upper( hItem[ "text" ] ) == cUpMeth` sobre tokens de string — **§1.2 gatilho 1**, texto
decidindo papel — e **não há um único selo `FATO-OK` no fonte**, então essa detecção nunca
passou pelo portão do §1.1: ela é anterior a ele.

**Errada nas DUAS direções, medido:**

| sonda | resultado |
|---|---|
| `LOCAL a, b` / `a := "b"` (o exemplo do Diego) | reporta `s.prg:5: possible reference in string` — falso positivo, e sobre um `LOCAL` |
| macro nomeando um `LOCAL` (`cN := "nX"`, `? &cN`) | **runtime: `Variable does not exist`** — macro NÃO alcança local, então o aviso acima é impossível de importar |
| nome MONTADO (`cFn := "Acu" + "mula"`, `? &cFn`) | `rename` **sucede em silêncio**: `verified: 6 edit(s); pcode byte-identical`, exit 0 — e o programa quebra em runtime |

O terceiro é o grave: *"pcode byte-identical"* é **verdade**, porque a quebra mora numa string,
que a identidade de pcode não enxerga por construção. A verificação é honesta sobre o que
verifica; o que mente é a palavra **verified** chegando ao usuário.

**Os fatos que o compilador JÁ dá** (medidos no dump de `a.prg`):
- `usesMacro` por função (`MAIN usesMacro = True`);
- nós `MACRO` em `statements[]`, **posicionados** — as avaliações reais nas linhas 14 e 15.

**AS 16 FORMAS DE MACRO, TESTADAS UMA A UMA** *(Diego, 2026-07-27: "existem muitas formas de
se escrever macros. teste todas."; tabela completa no
[backlog da sessão](backlog-2026-07-27.md) § 4)*. O resultado muda o escopo desta fase:

1. **Toda forma com `&` produz UM nó `MACRO` e liga `usesMacro`** — 14 de 14, das mais óbvias
   (`&cN`) às de canto (`&cN.`, `&cN := 9`, `M->&cN`, `FIELD->&cN`, `&cN[1]`, `o:&cF := 1`,
   dentro de codeblock). O compilador é consistente, então o fato é confiável.
2. Duas formas de operando: `val=<VAR>` (texto só existe em runtime) e `expr:LIST` (operando é
   expressão, inclusive constante). `&"literal"` sem parênteses **não compila** (E0030).
3. **Uma TERCEIRA família, invisível ao `usesMacro`: chamada por nome via função da RTL.**
   `__mvGet( "x" )`, `Type( "x" )` e **`hb_macroBlock( ... )`** alcançam o símbolo pelo nome e
   **não acendem `usesMacro` nem geram nó `MACRO`** — o único rastro é `calls[].sym`. O
   `hb_macroBlock` é o pior: é o jeito moderno de montar codeblock a partir de string, o que
   engine de relatório faz o dia inteiro. **É esta família que a heurística de string segura
   hoje.**

**DECISÃO DE ESCOPO — MACRO ESTÁ FORA, INTEIRA** *(Diego, 2026-07-27, e ela encerra o desenho
do veredito)*: *"é sabido que macros são runtime, e não dá para controlar — não com o
conhecimento atual que tenho do compilador. deixo para uma fase de pesquisa avançada. (...) tem
que assumir que macros estão fora do nosso controle totalmente ao menos por enquanto"* — e a
analogia que fecha o assunto: **o Harbour compila código novo em run time e o usa no instante
seguinte**; uma ferramenta de refatoração não controla isso, e fingir que controla é pior do que
dizer que não.

Logo **NÃO existe recusa por alcance de macro**. Não porque seja difícil, mas porque o fato não
existe e não vai existir por esforço nosso. O que existe é uma **limitação declarada** (ver
[P23](#p23)). *(O caso `refuse-rename-macro-may-name-symbol`, escrito e vermelho, foi
REMOVIDO — ele travava um veredito que não se constrói.)*

**E o memvar entra na mesma sentença** *(Diego)*: *"memvar é um code smell. é aceitável que
sejamos limitados também no tratamento dela."*

**A ORDEM DO DIEGO, 2026-07-27 — e ela decide o resto:** *"heurística é code smell e deve ser
retirada mesmo. se houver forma de resolver através de alterações no core, aí sim, senão, o
hbrefactor simplesmente não vai suportar. me recuso a ter heurística nele."*

Logo o casamento de string **morre incondicionalmente** — não "morre se houver substituto".
E o substituto só é legítimo se for **fato do core**. Uma lista de `__mvGet`/`Type`/
`hb_macroBlock` dentro do `src/hbrefactor.prg` seria a mesma heurística com roupa melhor:
conhecimento NOSSO sobre a RTL, não fato dela.

**E o core tem a casa desse fato, sondado:** `s_stdFunc` em `src/compiler/hbfunchk.c` — tabela
das funções conhecidas da RTL (67 entradas, nome + aridade mín/máx), usada para checagem de
argumentos em tempo de compilação. **`TYPE` já está nela.** O caminho é estender a
`HB_FUNCINFO` com o fato *"esta função alcança símbolo pelo nome, no argumento N"*, preencher
para a família, e o dump publicar isso por chamada. Quem sabe quais funções da RTL fazem acesso
dinâmico é a RTL — e o compilador ganha junto a capacidade de avisar sobre acesso por nome, que
é armadilha real com `-gh`/eliminação de código morto.

**Se os mantenedores recusarem a extensão, a regra do Diego decide o resto:** o hbrefactor
**não suporta** esse caso, e diz isso — nunca adivinha.

**ACHADO AO MATAR A HEURÍSTICA — uma capacidade REAL estava escondida dentro dela.** Ao
remover o casamento de string, o caso 73 (DSL real do contrib, `xhb/cstruct.ch`) caiu:
`MEMBER x IS CTYPE_INT` deixava de ser relatado. Investigado antes de re-baselinar, e **não
era heurística**: o dump carrega a derivação do token.

```json
tok: {"line": 9, "col": 10, "type": 41, "prov": "s", "text": "x",
      "from": [{"app": 2, "marker": 1, "op": "stringify"}]}
ppApplications[2].tokens: {"line": 9, "col": 10, "marker": 1, "text": "x", "generates": true}
```

O compilador **diz** que aquela string nasceu de *stringificar* o marcador 1 daquela
aplicação, e a aplicação carrega o token de fonte com posição. A pergunta deixa de ser *"o
texto desta string é igual ao nome?"* (texto decidindo papel) e passa a ser *"esta string foi
PRODUZIDA por este token?"* — junção exata, zero inferência.

**E o fato é MELHOR que a heurística era:** ela reportava a posição da string; o fato reporta
**9:10, o token escrito** — que é o lugar que uma edição precisa tocar. Então o caso 73 não
morre: ele muda de posição e ganha `certainty` de fato provado. **Preservar isto é parte do
critério de pronto**, e a lição vale para as outras duas quedas (casos 11 e 125): antes de
deixar um caso cair junto com a heurística, perguntar se o que ele provava tem fato por trás.

**Escopo**
- **Matar** o casamento por texto em string. O `a := "b"` do Diego passa a não produzir nada —
  por construção, não por ajuste de limiar.
- `usages`: sítio de **avaliação de macro** como kind próprio, com a posição do nó `MACRO`, e a
  certeza dizendo que o nome resolvido é fato de runtime.
- `rename`: o veredito considera macro **só** para símbolo alcançável por nome em runtime
  (função, memvar/public/private, método/DATA) — **nunca `LOCAL`/static-local**, o que está
  provado acima. A evidência da recusa é a posição das avaliações, não um casamento de string.
- Sondar se o dump precisa crescer para dizer **o alcance** de uma avaliação (o módulo inteiro
  × a expressão que ela compila) — e, se precisar, é extensão de core (§1.4).

**E separar os códigos de recusa, que hoje são um só** *(Diego, 2026-07-27)*. O
`RSN_TEXTUAL_FORCE` ("textual-refs-require-force") é o único da taxonomia com ação
`ask-human-then-retry` — *"dá, falta consentimento"* —, e o `--force` é o portão dele. Mas ele
cobre **três situações diferentes**, o que contradiz o §1.6 (*todo código de recusa diz o que
FAZER*): um agente que o lê não sabe qual das três coisas fazer.

| gatilho hoje | destino | o que o usuário tem de fazer |
|---|---|---|
| literal de string igual ao nome | **MORRE** com esta fase | — (é o `a := "b"`, e não é fato) |
| linha `DYNAMIC <nome>` no `.hbx` | código **próprio** | *"regenere o `.hbx` com `-hbx=`"* |
| avaliação de macro alcançando o símbolo | código **novo** desta fase | *"confirme que nenhuma destas avaliações nomeia este símbolo"* |

Com isso o `--force` deixa de ser a muleta de uma heurística e passa a ser o que o nome
promete: consentimento para um risco **provado**. *(A leitura textual do `.hbx` continua sendo
gatilho 4 — o hbmk2 é quem gera e consome aquela lista — mas o FATO que ela reporta é real, e
trocar o canal é item separado.)*

**Critério de pronto (mecânico)**: caso com `a := "b"` provando saída **vazia**; caso com nome
montado provando **recusa** com a posição da avaliação de macro; caso com `LOCAL` alcançado por
macro provando que nada é relatado; `grep` do casamento de texto em string sem resultado no
fonte; cada um dos dois gatilhos sobreviventes com **código de recusa próprio** e um caso que o
exercita, e `RSN_TEXTUAL_FORCE` sem consumidor no fonte; `make test` verde.

### P33 — LSP como superfície de entrega *(aberto 2026-08-08; decisão do Diego: "concordo com: LSP como superfície de entrega"; **A FAZER**)*

**O argumento.** A extensão VSCode fala hoje um protocolo próprio com o CLI. Empacotar o
hbrefactor atrás do **Language Server Protocol** muda a SUPERFÍCIE, jamais o motor (§1.6
literal): rename, usages e recusas viram `textDocument/rename`, `textDocument/references` e
diagnostics — e qualquer editor (Vim, Emacs, IntelliJ) vira consumidor de graça. É a fase A
(saída estruturada para agentes) com mais um consumidor estruturado: o editor.

**Escopo**
- Servidor LSP fino sobre o motor existente: `initialize`, `textDocument/rename` (delegando
  ao `rename` + verificação, com recusa mapeada para `ResponseError` carregando o código de
  motivo), `textDocument/references` (delegando ao `usages`), e diagnostics para o relato
  do não-verificável.
- A extensão VSCode migra para cliente LSP — nenhuma capacidade some no caminho.
- **Não-objetivo**: nenhuma feature as-you-type nesta fase (isso é a P34); o servidor
  responde a COMANDOS, com a mesma latência e as mesmas provas do CLI.
- **Nenhum princípio do §1 cede**: o servidor não responde o que o motor não prova; recusa
  LSP carrega o mesmo código legível-para-relatar da fase A.

**Critério de pronto (mecânico)**: teste dirigindo o servidor por stdin/stdout
(`initialize` + `textDocument/rename` sobre fixture) provando que o `WorkspaceEdit` produz
fonte **byte a byte igual** ao do `rename` do CLI na mesma fixture; caso de recusa provando
o código de motivo na resposta LSP; a extensão operando via servidor; `make test` verde.

### P34 — IntelliSense na IDE *(aberto 2026-08-08; decisão do Diego: "vou querer IntelliSense no futuro"; **EXPLORATÓRIA — NADA MEDIDO AINDA**)*

**O quê.** Completion, hover e navegação **enquanto se digita** — não sob demanda. É outra
classe de problema que o rename: exige latência de tecla e tolerância a fonte que **não
compila** (o estado normal do meio da edição), e o motor de hoje exige projeto que compila.

**A tensão, dita de frente**: a lei do §1 (zero inferência) não cede para IntelliSense. O
caminho honesto é o fato vir de uma **compilação real** — possivelmente a última boa, com a
idade do fato declarada — nunca de parser tolerante que adivinha. Se isso não bastar para a
experiência, a resposta é ir ao core (compilador residente/incremental, §1.4), não
heurística na ferramenta.

**Perguntas que a exploração responde (medindo, §1.7.2 — nada disto se afirma sem número)**
- Quanto custa uma compilação de módulo único nos projetos do corpus? (Se for dezenas de ms,
  "recompila a cada pausa de digitação" pode bastar e o problema morre barato.)
- O que completion precisa saber, e o dump já carrega? (símbolos visíveis no escopo do
  cursor, assinaturas, DATAs/métodos do receiver — a P14 é vizinha direta.)
- Fato da última compilação boa: o que fica errado, por quanto tempo, e como se declara a
  idade sem virar degradação calada (§1.5)?
- Daemon: o que o core precisaria para um modo residente (compilador-biblioteca já existe
  como oráculo — falta medir se aguenta o ciclo de tecla)?

**Critério de pronto (mecânico, da exploração)**: tabela de sondas no formato §1.7.1 com as
medições acima; decisão registrada aqui (que arquitetura, e o que ela recusa a fazer); as
fatias executáveis viram fases próprias com critério próprio.

### P30 — dois STATIC de mesmo nome no mesmo `.prg`, e o cursor já diz qual *(aberto 2026-08-08; **✅ ENTREGUE 2026-08-08**)*

**O caso, e ele NÃO envolve diretiva** *(Diego, 2026-08-08: "vamos separar as coisas...
pode haver static de prg e static na função dentro do mesmo prg")*. Harbour aceita um
`STATIC nTotal` file-wide e outro `STATIC nTotal` dentro de uma função do mesmo arquivo.
São duas variáveis ordinárias e distintas, e o compilador não reclama.

**Medido** (sonda em cópia nova, fixture compilando limpo sob `-w3 -es2`):

| cursor | hoje |
|---|---|
| no `STATIC` de FUNÇÃO (`a.prg:13:11`) | ❌ `STATIC 'nTotal' is declared in more than one place in 'a.prg'` |
| no `STATIC` FILE-WIDE (`a.prg:1:8`) | ❌ a mesma recusa |

**As duas recusas são falsas: a POSIÇÃO desambigua sozinha.** Apontar a linha 13 é
inequivocamente a de função; apontar a linha 1 é inequivocamente a file-wide.

**Onde a informação se perde** *(lido no fonte, a confirmar com sonda antes de mecanismo)*:
o `StaticScan` filtra por função com `IF ! Empty( cFuncFilter ) .AND. ! hFunc[ "fileDecl" ]
.AND. ! ( nome == cFuncFilter )` — a pseudo-função `fileDecl` **nunca** é pulada, então a
declaração file-wide entra mesmo com `--func`, `hOwner` é atribuído duas vezes e a recusa
dispara. E para o cursor na file-wide o despacho cai no ramo (5), que não passa filtro
nenhum. **Não mexer sem sondar antes**: o `! fileDecl` pode existir por um motivo que eu
não conheço, e supor aqui é o erro que este roadmap registra três vezes hoje.

**Escopo**
- O despacho passa a levar **QUAL declaração** o cursor tocou, não só o nome da função —
  file-wide e de-função são alcances diferentes, e a posição já os separa.
- `StaticScan` honra isso: com alvo file-wide, ignora as de função; com alvo de função,
  ignora a file-wide.
- A recusa `RSN_STATIC_AMBIGUOUS` sobrevive só onde é verdadeira: quando o alvo **não** vem
  de posição (chamada por nome) ou quando uma diretiva prende as duas.

**Critério de pronto (mecânico)**: caso renomeando o `STATIC` de função com a file-wide
homônima **intacta**; caso renomeando a file-wide com a de função **intacta**; o caso da
diretiva prendendo as duas continuando a recusar; `make test` verde.

**ENTREGUE.** A sonda confirmou o que o fonte sugeria e mais: o dump **já separa** as duas
declarações — a file-wide vive só na pseudo-função do módulo, a de função só na função dela,
cada uma com linha e coluna. O que se perdia era no DESPACHO, que mandava adiante só o NOME
da função, e nome de função não consegue exprimir "a do arquivo". Entrou o alvo
`FILEWIDE_TARGET`, e o filtro passou a ser por ALCANCE em vez de por nome.

**E a coleta precisou da regra de sombra**, que o critério de pronto não previa: um `STATIC`
de arquivo é visível no módulo inteiro, então varrer tudo engolia os usos da homônima de
`Outra`. Dentro do span de uma função que declara a própria, o nome é o dela — o compilador
liga assim. A coleta file-wide passa a excluir esses spans (`SombreadoEm`).

A recusa por ambiguidade sobrevive onde continua verdadeira: sem posição (busca ampla, o que
o motor da P27/P28 usa) e no caso da diretiva prendendo as duas.

### P32 — renomear a função ESTÁTICA que uma diretiva chama *(aberto 2026-08-08; **✅ ENTREGUE 2026-08-08** — fatia 0 `ast-24` + corpo; spec por ordem do Diego: "quero")*

> **CORPO ENTREGUE** *(2026-08-08, na sequência da fatia 0)* — os quatro pontos do
> critério de pronto, todos mecânicos e verdes:
> - **O arraste é fato de APLICAÇÃO, não de texto** (`ModuleAppliesRuleWriting`:
>   `ppApplications` cujo result escreve o nome): rename da static de f2 edita
>   f2+f3+`fn.ch` e sai `ok`; f1 — que nem inclui o header — provado **byte-idêntico**.
>   Caso pinado `refuse-rename-static-function-cited-by-directive` **INVERTIDO**
>   conscientemente para `rename-static-function-cited-by-directive`.
> - **As duas pontas são uma operação**: cursor no result (`fn.ch:1:23`) delega ao
>   motor de função (fallback no `RenameRuleWritten` quando nenhuma variável liga e o
>   nome é função do projeto) — conjuntos IGUAIS afirmados por `reflect.DeepEqual`.
> - **Misto recusa com mapa e código próprio** (`RSN_STATIC_DYN_MIX` =
>   `directive-binds-static-and-dynamic`): aplicador sem homônima liga dinâmico, e a
>   recusa nomeia o vínculo POR MÓDULO (caso
>   `refuse-rename-static-function-mixed-binding`, com public real em f5).
> - **A prova virou POR MÓDULO no `rename-function`** (a régua da P28): editado — ou
>   aplicador de regra editada, que muda via header — exige a troca de UM símbolo
>   (`FactsEquivalent`); intocado exige byte-identidade. Isso matou o culpa-ao-inocente
>   **e um defeito irmão que a sonda achou no caminho**: static com homônima em outro
>   módulo reprovava injustamente MESMO SEM diretiva (caso novo
>   `rename-static-function-beside-module-homonym`).
> - Citação sem aplicação no módulo da definição = **coincidência de grafia**: o sítio
>   segue relatado, o header NÃO entra no conjunto (o fato que decide é a aplicação).
> - Execução idêntica antes/depois: `unit_142` (par hbmk2 + rodar, à moda do 74).
> - `make test` 1011/0. **Paga de graça**: o item 3 da P31 (rollback culpando o
>   inocente) e a metade "funções" do item 2 (mapa nas recusas).

> **FATIA 0 ENTREGUE** *(2026-08-08, priorizada por sondagem: a prova da P29 —
> "pcode igual a menos da renumeração" — não tem precedente na ferramenta e
> exigiria crescer o leitor caseiro de `.hrb` até um decodificador de pcode,
> o drift que a rodada 2 desta spec já vetou; a fatia 0 serve as duas fases)*:
> - **`ast-24` no core** (`compast.c`): `symbols[]` (nome + escopo de 16 bits +
>   link, espelhando a enumeração do `genhrb.c`) e, por função que vira código,
>   `pcodeSize` + `pcodeHash` (bytes crus) + **`pcodeNormHash`** — o stream com
>   operandos de índice-de-símbolo trocados pelo NOME (lista de 19 opcodes
>   espelhada do `genc.c`, pares near/wide dobrados, `0xFFFF` do
>   `WITHOBJECTMESSAGE` cru). O hash é FNV-1a 64 + tamanho, o MESMO da
>   procedência ast-22 e pela mesma razão estrutural (md5 mora na `libhbrtl`;
>   o adversário é "mudou", não um falsificador) — o "hash forte" da spec
>   original foi ajustado a esse precedente documentado no ast-schema.md.
> - **Controles medidos** (sonda em diretório novo com baseline git): símbolo
>   inserido no MEIO da tabela → função intocada sai raw DIFERENTE / norm
>   IGUAL (o fato exato da P29); edição real → os dois mudam.
> - **O `HrbParse` MORREU e nenhum leitor de `.hrb` nasceu**: `ProofFacts`
>   lê o dump etiquetado (`.before/.after/.snap/.now.ast.json`, copiado pelo
>   `CompileHrbAll` na MESMA compilação que gera o `.hrb`), e os cinco
>   comparadores viraram `FactsEquivalent`/`FactsExtractCheck`/
>   `FactsMethodExtractCheck`/`FactsSymbolsEqual`/`FactsSymbolsRenamed`. O
>   `hb_BAt` do extract-de-método (busca de bytes no pcode) virou fato de
>   stringify do dump (`ClassSpelledSet`). O snapshot do `verify` migrou para
>   `snap-2` (fatos do dump + md5 do artefato). Os 34 sítios de
>   byte-identidade continuam CRUS sobre o `.hrb`.
> - `make test` 1005/0; caso 122 guarda o passo core↔ferramenta em `ast-24`.

**O caso.** `#xcommand XLOG <m> => Remessa( <m> )`, e cada módulo que usa o comando tem a
SUA `STATIC FUNCTION Remessa` — a mesma palavra no result, uma função diferente por módulo
(f1, que nem inclui o header, tem uma terceira, alheia). Hoje qualquer rename ali termina em
rollback, e o rollback culpa o módulo inocente.

**TABELA DE SONDAS** *(§1.7.1 — medidas em 2026-08-08, ANTES do mecanismo; sondas em cópia
nova com baseline git)*

| pergunta | resposta medida |
|---|---|
| o dump diz a qual função uma chamada liga? | **NÃO**: `calls[]` tem só `sym`+posição+`app` |
| o `.hrb` diz? | **SIM**: cada símbolo carrega 2 bytes de escopo; `REMESSA` sai `0x02` = `HB_FS_STATIC` (`include/hbvmpub.h:236`) nos módulos que a definem |
| e com a chamada ANTES da definição (forward)? | **SIM**, `0x02` do mesmo jeito — a resolução é da tabela, não do sítio |
| controle negativo | módulo que SÓ chama, sem definir: `REMESSA` sai `0x00` (dinâmico) |
| a ferramenta já lê isso? | **SIM**: `HrbParse` extrai os 2 bytes (`syms[n][2]`) e o `HrbEquivalent` já os compara |

**A natureza da fase mudou DUAS vezes, e o registro fica** *(§1.7: cada elo é fato)*:
(1) "o core precisa estampar `calls[].bind`" → a sonda do `.hrb` desmentiu — o vínculo já
está gravado nos 2 bytes de escopo; (2) "então lê-se do `.hrb` com o parser da ferramenta" →
o Diego apontou o drift de leitor próprio de formato alheio, e a pergunta seguinte dele
("o quanto já pode vir da compilação?") produziu o inventário que decidiu: (3) **o canal é o
DUMP (`ast-24`, fatia 0 abaixo)** — extensão de core sim, do canal padrão da casa, e o
vínculo estático da ANÁLISE sai do mesmo `symbols[]` que serve às provas.

**Escopo**
- **Fatia 0 — o HrbParse MORRE, e o canal é a PRÓPRIA COMPILAÇÃO, não um leitor de `.hrb`**
  *(a pergunta do Diego em duas rodadas, 2026-08-08: "o correto não seria o core retornar?"
  e depois "o quanto JÁ pode vir direto do processo de compilação?" — a segunda matou a
  primeira resposta)*.

  **O inventário do que as provas LEEM do `.hrb`** (medido nos cinco leitores): nome de
  símbolo; os 2 bytes de escopo; **igualdade** de pcode por função (`funcs[nI][2] ==`,
  nunca decodificado). Única exceção: o extract-de-método BUSCA o nome soletrado dentro dos
  bytes (`hb_BAt`, um contorno) — e o fato que ele procura o dump JÁ carrega no canal de
  classes (`_HB_MEMBER`/declared). **As três necessidades são conhecidas do compilador no
  ato de compilar.**

  **A forma: `ast-24` — o dump ganha, por módulo, `symbols[]` (nome + escopo) e um HASH
  forte do pcode por função.** Com isso:
  - a inspeção de `.hrb` cai a ZERO — as provas estruturadas comparam dump-antes ×
    dump-depois (nomes, escopos, hashes); a exceção do extract-de-método migra para os
    fatos de classe que o dump já tem;
  - os 34 sítios de byte-identidade continuam como estão — comparação crua do artefato,
    SEM parser, e o padrão-ouro ("byte-idêntico") segue sendo sobre o ARTEFATO;
  - a função de introspecção no `runner.c` (versão anterior desta fatia) fica
    DESNECESSÁRIA — não se cria canal para um leitor que deixou de existir;
  - o drift morre pelo mecanismo que a casa já tem: o schema é EXATO e o caso 122 fica
    vermelho no instante em que core e ferramenta divergirem (§1.5) — um formato binário
    não berra, o schema berra.

  **Custos honestos**: o hash tem de ser forte (colisão = prova mentindo; emitir tamanho +
  hash); o snapshot do `verify` guarda `.hrb` e passa a guardar também os fatos (migração
  de formato de snapshot); e confiar o lado estruturado ao canal `-x` é sustentado pela
  prova de impacto-zero que já existe (`make pcode-identity`, 889/889) — o canal é medido,
  não confiado.
- Rename da static citada no result de regra APLICADA: o conjunto é **todas** as statics
  homônimas dos módulos que aplicam a regra + o header — o arrasto da P31, agora para
  função. Módulo que não aplica (f1) fica intacto, byte a byte.
- **O uso do `.hrb` em ANÁLISE é decisão explícita, não inércia** *(5 porquês, gatilho 6)*:
  o parser existe para PROVA (5 famílias: verify, função, memvar, método,
  reorder/extract). Lê-lo na análise porque "já está ali" é o canal mais barato; se o
  papel de análise crescer, o caminho padrão da casa é o dump estampar (`ast-24`).
- **A prova é por-módulo, a régua da P28**: módulo editado → substituição de UM símbolo
  (`HrbEquivalent`); módulo intocado → byte-identidade. É isto que mata o
  culpa-ao-inocente: a verificação de hoje exige a substituição em TODO módulo, inclusive
  no que legitimamente mantém o nome velho.
- **As duas pontas**: cursor na definição de qualquer módulo aplicador, e cursor no nome
  dentro do result — mesmo conjunto (simetria da P31, afirmada por igualdade).
- **Misto recusa com mapa**: módulo aplicador SEM static homônima liga dinâmico (a um
  público de outro módulo) — arrasto atravessaria a fronteira static/dinâmico; recusa
  nomeando o vínculo por módulo, com código próprio.
- O caso pinado `refuse-rename-static-function-cited-by-directive` **INVERTE** na entrega
  (era o combinado ao piná-lo: quem conserta fica vermelho e atualiza consciente).

**Critério de pronto (mecânico)**: caso f1/f2/f3 com rename da static de f2 saindo `ok`,
editando f2+f3+`fn.ch` e provando f1 **byte-idêntico**; caso simétrico pelo result do
header com conjuntos IGUAIS; caso misto (um aplicador sem static) recusando com código
próprio e o vínculo por módulo no detalhe; execução idêntica antes/depois (par `hbmk2` +
rodar, à moda do caso 74); `make test` verde.

### P31 — o lado direito de uma diretiva não é UM símbolo *(aberto 2026-08-08; **DECISÃO DO DIEGO PENDENTE**)*

**A tese do Diego** *(2026-08-08)*: só faz sentido refatorar o lado ESQUERDO de uma diretiva —
o lado direito é transformado pelo pp e o programador não o vê no fluxo dele. Ele pediu
sondas com escopos misturados e com funções estáticas. **As sondas confirmam a metade
profunda da tese e derrubam a metade simples.**

**TABELA DE SONDAS** *(§1.7.1 — todas em cópia nova com baseline git; fixtures limpas sob
`-w3 -es2`)*

| sonda | resultado |
|---|---|
| projeto com o MESMO nome no result e ligações em 4 escopos (local, param, static de função, static de prg em OUTRO módulo) | `usages` rotula cada sítio pelo escopo DELE; rename de UMA local arrasta **as 4 variáveis distintas** + o `.ch` (8 sítios), prova verde; módulo sem a diretiva e homônima sem o comando ficam intactos |
| o mesmo projeto + uma PRIVATE ligada | pela local: recusa antecipada nomeando o memvar; pela private: rollback (o módulo intocado mudou de pcode — a régua estrita da P28 pegou) |
| 3 prgs com `STATIC FUNCTION Grava` homônima; 2 incluem `#xcommand LOG <m> => Grava(<m>)`, 1 não | rename da static de f2: edita `.ch`+f2, e o rollback vem de **f1 — o módulo INOCENTE, que nem inclui a diretiva** ("symbol unexpected: GRAVA"); o estrago real seria f3, que nem é citado |
| cursor no próprio lado direito (`fn.ch:1:22`, nome de função) | motor não acha ligação de variável, edita só o `.ch`, rollback cego ("f2.hrb changed") |
| `usages` da função | lista as 3 definições, uma por módulo — mas a declaração do static file-wide de prg **não aparece** no caso das variáveis (lacuna) |

**O que as sondas provam:**

1. **O lado direito NÃO é um símbolo — é um buraco de template preenchido POR SÍTIO DE
   APLICAÇÃO.** O mesmo `nReg` do result ligou a 4 variáveis distintas num projeto; o mesmo
   `Grava` a 2 funções distintas (e f1 tem uma terceira, alheia). Cursor ali reivindica "este
   símbolo", o que em geral é mentira.
2. **A metade simples ("o programador nunca o vê") não se sustenta**: o lado direito é texto
   que ele DIGITOU, num `.ch` versionado. O que ele nunca vê é a EXPANSÃO. E "nunca tocar no
   lado direito" como política de EDIÇÃO quebra o build (medido: `W0001`, exit 1 sob `-es2`).
3. **O arrasto não vem do ponto de partida — vem do texto compartilhado.** Começando pela
   local, o conjunto é o MESMO. Proibir o cursor no lado direito não elimina a surpresa das 4
   variáveis; o relato (dry-run, locations) é o que a elimina.

**A opção (a) MORREU, e quem a matou foi a cadeia lógica do Diego + duas medições**
*(2026-08-08: "se temos o usage com escopo, temos rename")*:
- rename COMEÇANDO no lado direito (`log.ch:1:29`) produz o MESMO conjunto de 8+1 edições
  do começo pela local, prova verde. A capacidade existe, funciona e é simétrica — proibir a
  entrada removeria coisa provada em troca de nada.
- e a genealogia alcança **diretiva INDIRETA** (a que o `doc/pp.txt` do core descreve: regra
  cujo result define OUTRA regra). Medido em 2 e em 3 níveis: a regra gerada registra os
  tokens dela apontando o TEXTO ORIGINAL dentro do result da geradora (`NIVEL3` nascido na
  aplicação da linha 6 aponta a linha 1 col 50), o `usages` mostra a cadeia, e o rename do
  nível mais fundo edita a linha 1 e sai `.ppo`/`.hrb` byte-idêntico. O core JÁ rastreia; o
  contra-argumento "o programador não vê" não sobrevive a isso.

**O que sobra da P31 são itens concretos, não política de entrada:**
1. **Rename multi-ligação ganha diagnóstico**: quando o nome do result liga a mais de uma
   variável (as 4 da sonda), o envelope diz *"este nome liga N variáveis distintas"* com a
   lista — hoje o arrasto aparece só na lista de edições, sem o rótulo.
2. **As recusas que EXISTEM ganham o mapa**: memvar misturado e funções hoje recusam às
   cegas ("f2.hrb changed"); passam a nomear as ligações por módulo/escopo.
3. **O rollback do rename-function para de culpar o inocente**: tropeça em f1 (que nem
   inclui a diretiva) e cala sobre f3, o quebrado real.
4. **`usages` lista a declaração do static file-wide** (hoje falta).

Decisão do Diego: quais dos 4 entram, e em que ordem.

**A classificação das recusas** *(pergunta do Diego, 2026-08-08: "infundadas, ou deixam de
ser recusas se o core informar?"; sondado antes de responder)*:

| recusa | veredito | o que falta |
|---|---|---|
| memvar misturado (`directive-also-binds-a-memvar`) | fundada HOJE | **ferramenta**: prova por-módulo (a arquitetura da P28 fatia 3, aplicada ao motor conjunto) — o core já informa tudo |
| P29, criadores disjuntos | fundada HOJE | **ferramenta**: prova nova (pcode igual A MENOS da renumeração de símbolos — o fato é o `pcodeNormHash` do `ast-24`, entregue na fatia 0 da P32; medido: renumeração preserva o norm, edição real muda os dois) |
| variável que a diretiva possui | fundada HOJE | **ferramenta**: alpha-rename no result é provável com `-gh -l` (nome de local não existe no pcode) |
| funções ESTÁTICAS citadas no result (f1/f2/f3) | fundada HOJE | **ferramenta — a sonda seguinte DESMENTIU o "precisa do core"**: o vínculo já está gravado na tabela de símbolos do `.hrb` (`HB_FS_STATIC`), que o core produz e o `HrbParse` já lê. Virou a [P32](#p32--renomear-a-função-estática-que-uma-diretiva-chama) |
| regra builtin | física (não há arquivo) | o core PODERIA estampar a origem (`std.ch:linha`) para o RELATO; nunca vira rename — editar `std.ch` é reconstruir o Harbour |
| alcances que se CRUZAM (P29, outra metade) | física | o vínculo depende do caminho de execução em runtime; não existe fato de compilação |
| buraco de macro (`&x`) | física | runtime-only; irredutível (limites-e-alavancas) |

*(As recusas infundadas desta sessão já caíram: o campo de área de trabalho, os dois STATIC
por posição — P30 —, e a mensagem que oferecia `--func` inexistente. A do f1/f2/f3 é fundada
com MENSAGEM falsa — culpa o inocente — e está pinada como defeito.)*

**As descobertas das sondas viraram ESPECIFICAÇÃO EXECUTÁVEL em 2026-08-08** *(cobrança do
Diego: "você criou especificações executáveis para amarrar estes funcionamentos?")*: 
`rename-directive-result-binds-four-scopes` (o arrasto total pelas DUAS pontas, com a
simetria afirmada por `reflect.DeepEqual` dos dois conjuntos), 
`refuse-rename-when-directive-also-binds-a-memvar` (a recusa saiu de `unclassified` e ganhou
`directive-also-binds-a-memvar` — item 2 parcialmente pago), 
`rename-indirect-directive-heads` (o exemplo do `doc/pp.txt` com `EOC` + cadeia de TRÊS
níveis, renomeando pela genealogia posicional) e 
`refuse-rename-static-function-cited-by-directive` (o item 3 PINADO como defeito, à moda do
caso do campo de área de trabalho: quem consertar a culpa-ao-inocente fica vermelho na hora).

### P29 — dois criadores PRIVATE: a recusa é larga demais *(aberto 2026-08-08; **A FAZER**)*

**O caso.** Dois `PRIVATE` do mesmo nome, criados em funções diferentes. A ferramenta
recusa **sempre**, com `RSN_MV_MULTI_CREATOR`, dizendo *"bindings depend on the execution
path"*. Eu descrevi isso como natureza do problema — *"não existe fato de compilação que
separe os dois"*. **Estava errado, e quem apontou foi o Diego** *(2026-08-08: "o escopo dela
perdura através das chamadas de função... estou certo ou errado?")*.

**TABELA DE SONDAS** *(§1.7.1 — medida antes do mecanismo, em cópia nova de cada fixture)*

| o que se perguntou | o que se mediu |
|---|---|
| a ferramenta separa os alcances? | **JÁ SEPARA**: `usages` imprime `creator: PRIVATE in MAIN → reach USAUM` e `creator: PRIVATE in OUTRO → reach USADOIS` |
| ela usa essa separação? | **NÃO**: imprime a mesma frase e recusa igual, com alcances disjuntos ou cruzados |
| `MEMVAR`/`FIELD` criam variável? | **NÃO**: `MEMVAR x` sem `PRIVATE`/`PUBLIC` compila limpo; sem ele, o uso dá `W0001` (quebra sob `-es2`). São declaração de COMO LIGAR o nome |
| a lista `MEMVAR` aceita nome a mais? | **SIM**: `MEMVAR xCfg, xNovo` com um só usado compila limpo sob `-w3 -es2` |
| a edição do caso disjunto compila? | **SIM**: renomear a cadeia de um criador + acrescentar o nome às listas `MEMVAR` dos módulos deixa tudo limpo |
| a PROVA aceita? | **NÃO**: `verify` diz CHANGED — *"pcode of OUTRO changed"*, *"pcode of USADOIS changed"*, e essas funções **não foram tocadas** |

**Por que o pcode de função intocada muda** *(fato do core, não dedução)*: o pcode referencia
memvar por **índice na tabela de símbolos** — `HB_P_PUSHMEMVAR` lê um `USHORT` que indexa
`pSymbols` (`src/vm/hvm.c`). Um símbolo a mais renumera a tabela, e o pcode de quem não
mudou anda junto, sem que o comportamento mude.

**O diagnóstico, então, não é o que eu tinha dito.** Não falta FATO (a ferramenta já o
calcula) e não falta EDIÇÃO (ela compila limpa). **Falta PROVA** que aceite *"um símbolo a
mais, e todo o resto igual a menos da renumeração"*.

Há precedente na casa: o `reorder-params` prova por `symbols-preserved` justamente porque o
pcode dele muda de forma legítima. E a P28 já estabeleceu a régua irmã — **a prova depende
do que MUDOU**: módulo editado aceita uma troca de símbolo; módulo intocado exige
byte-identidade.

**Escopo**
- **Estreitar a recusa** para o caso em que ela é verdadeira: alcances que **se cruzam**
  (uma função alcançada por mais de um criador). Aí o vínculo depende mesmo do caminho de
  execução, e recusar é o certo.
- **Alcances DISJUNTOS passam a renomear**: a cadeia do criador escolhido, mais o nome novo
  na lista `MEMVAR` de cada módulo que passa a vê-lo.
- **Prova nova**, na linha do `symbols-preserved`: mesma quantidade de funções, pcode de cada
  função igual **a menos dos índices de símbolo**, e a tabela igual mais o símbolo novo.
  Sem isso a fatia não entrega — editar sem prova é o que esta ferramenta não faz.
  *(2026-08-08: o fato já existe — `pcodeNormHash` por função no `ast-24` (P32 fatia 0),
  e o controle da renumeração está medido. A prova vira comparação de fatos do dump.)*
- Buraco no grafo (chamada dinâmica, macro) continua recusando, com o código que já existe.

**Critério de pronto (mecânico)**: caso com dois criadores de alcance DISJUNTO renomeando um
deles e saindo `ok`, com o outro criador e a cadeia dele **byte a byte intactos**; caso com
alcances CRUZADOS recusando com `memvar-has-more-than-one-creator`; caso provando que a lista
`MEMVAR` recebeu o nome novo; execução idêntica antes/depois (o par `hbmk2` + rodar, como o
caso 74); `make test` verde.

### P28 — a diretiva que escreve um STATIC ou um MEMVAR *(aberto 2026-08-07; **✅ ENTREGUE 2026-08-08**; resto da P27)*

**O caso.** A P27 renomeia o nome que a diretiva escreve **quando ele liga a um LOCAL**.
Ligando a outra coisa, ela recusa. Eu escrevi essa recusa dizendo *"só um LOCAL pode ser
provado byte-idêntico"* — e o Diego mandou não supor. **A suposição estava errada.**

**TABELA DE SONDAS** *(§1.7.1 — medida em 2026-08-07, ANTES do mecanismo)*

| escopo | com a diretiva escrevendo o nome | **controle positivo** (mesmo escopo, SEM diretiva) |
|---|---|---|
| `local` | ✅ P27: edita os dois lados, `pcode-identical` | — |
| `static` | ❌ `verification-failed-rolled-back`, **`diagnostics[] VAZIO`** | ✅ `ok`, `proof: pcode-identical` |
| `private` | ❌ `verification FAILED ... the number of symbols/functions changed`, **vazio** | ✅ `ok`, `proof: pcode-identical` ("symbol renamed") |
| `public` | ❌ idem `private`, **vazio** | *(mesmo verbo do private — `rename-memvar`)* |
| `field` | — | **fora**: `no rename verb covers RDD fields` (área de trabalho, não símbolo do módulo) |

**O que os controles provam, e é o oposto do que eu escrevi:** `rename-static` e
`rename-memvar` **já renomeiam e já têm prova própria**. Não falta provabilidade — falta o
motor da P27 alcançar aqueles verbos. A dificuldade que o Diego supôs se confirma **só** no
`FIELD`, e ali a ferramenta já recusa em todo lugar, por outra razão.

**E há um segundo buraco, maior, na mesma medição:** os três recusam com
`diagnostics[]` **vazio**. É exatamente a lacuna que a P25 fechou para `local` — a recusa
não conta o que a ferramenta já sabe — **ainda aberta para todo o resto**. Foi o que os 5
porquês do `DiagRuleWrites` acharam: o diagnóstico estava pendurado no VERBO em vez de no
FATO, então disparava onde virou coincidência e calava onde é a causa.

**Escopo — TRÊS fatias, e a ordem saiu de ler os dois verbos por dentro**

**Fatia 1 — o relato. ✅ ENTREGUE 2026-08-07.** `DiagRuleWritesApplied()` emite a regra como
`diagnostics[]` nas recusas de `rename-static` e `rename-memvar`. O gatilho é
**APLICAÇÃO**, não menção: regra só REGISTRADA num módulo que nunca usa o comando não causou
nada ali — relatá-la assim mesmo foi o erro que matou o `DiagRuleWrites`. Um helper só para
os dois sítios, porque mudam pelo mesmo motivo; os verbos seguem tão diferentes quanto são.
Casos: `refuse-rename-static-written-by-directive` e `refuse-rename-memvar-written-by-directive`.

**Fatia 2 — o static. ✅ ENTREGUE 2026-08-08.** `StaticScan()` saiu do `rename-static` pelo
mesmo corte que produziu o `LocalScan`, e o motor escolhe o coletor pelo ESCOPO que o
compilador reportou no sítio. Não virou um coletor "genérico" para os dois: o alcance de
cada escopo é do compilador (local = a função; static = o MÓDULO), e fundi-los misturaria
dois conceitos dele num helper nosso. Por isso o static é colhido **uma vez por módulo**,
fora do laço de funções — colher por função duplicaria os sítios de um file-wide usado em
duas delas. O `RuleWritesLocal` virou `RuleWritesSymbol( hAst, hFunc, cUp )`, com `hFunc`
NIL significando "pergunte ao módulo".
Dois casos, porque são dois alcances e um não pega o outro quebrando:
`rename-static-written-by-directive` (file-wide, declarado fora de qualquer função) e
`rename-static-of-function-written-by-directive` (dentro de `Main`, com uma `LOCAL`
homônima em outra função que **não** pode ser tocada).

**E um TERCEIRO caso, achado pelo Diego perguntando "os DOIS alcances foram levados em
conta?"** — a pergunta que eu deveria ter feito sozinho. O Harbour aceita o mesmo nome como
STATIC em dois lugares do módulo (duas funções, ou file-wide mais uma função), e são
variáveis DISTINTAS que a mesma diretiva prende. A ferramenta já recusava com os fontes
intactos, mas a recusa mandava **"use `--func`"** — e o `rename` unificado não tem esse
flag. Recusa que aponta passo impossível é pior que recusa seca: o agente tenta, falha e
volta a editar texto na mão, que é o modo de falha que a ferramenta existe para matar.
Agora tem código próprio (`RSN_STATIC_AMBIGUOUS`), diz a forma do problema (a regra prende
duas variáveis, então renomear uma é o trabalho ERRADO, não um trabalho menor) e **não
oferece flag nenhuma**, porque nenhuma resolve. Caso:
`refuse-rename-static-declared-twice-written-by-directive`, que reprova qualquer `--` na
mensagem. Renomear as duas + o header é fatia própria, ainda não escrita.

**Fatia 3 — o memvar. ✅ ENTREGUE 2026-08-08, e a medição mudou o desenho.**

A pergunta era se o alcance que aquele verbo calcula continuaria valendo com o `.ch` dentro
do conjunto. A resposta veio da PROVA, não do alcance: `HrbEquivalent` aceita **um** símbolo
renomeado, mesma contagem, mesma ordem, mesmo pcode por função — e o rename conjunto é
exatamente isso. A recusa que eu media antes (*"the number of symbols/functions changed"*)
era o `.ch` ficando para trás e criando um símbolo A MAIS.

Então o memvar **não** entra no motor da P27: os sítios da diretiva entram no conjunto do
PRÓPRIO verbo. Um memvar existe no pcode; byte-identidade é impossível para ele por
construção, e levá-lo ao motor exigiria ou arrastar a análise de alcance inteira para lá, ou
inventar uma prova que nenhum dos dois verbos tem. **Um coletor (`RuleResultEdits`), duas
provas** — porque há genuinamente duas.

**E a fatia 1 virou ANDAIME, o que só ficou visível aqui.** O relato existia para contar o
que a ferramenta não sabia fazer; feitas as fatias 2 e 3, a diretiva é EDITADA e o que
sobrava chegando àquelas recusas era coincidência — a mesma armadilha do `DiagRuleWrites`,
repetida. As duas chamadas e o helper (51 linhas) saíram. O sítio da regra segue emitido em
**um** lugar, o único onde ela ainda é causa: o STATIC declarado em dois lugares, que a
regra prende e o rename não cobre.

- `FIELD` continua fora, com a recusa que já existe.
- **Cuidado medido no `public`:** o nome é visível a outros módulos e alcançável por macro
  em runtime. O `rename-memvar` já tem o portão de referência textual (`--force`,
  `RSN_TEXTUAL_FORCE`); a P28 **não** o afrouxa.

**Critério de pronto (mecânico)**: caso com `#xcommand` escrevendo um `STATIC` — rename
edita os dois lados e sai `ok`; idem para `PRIVATE`; caso `FIELD` recusando com o código que
já existe; caso provando `diagnostics[]` **não vazio** na recusa de `static`/`memvar` que a
edição conjunta não cobrir; `make test` verde.

### P27 — o nome escrito no RESULTADO de uma regra também se renomeia *(aberto 2026-08-07; **✅ ENTREGUE 2026-08-07**; destravada pela P24)*

**ENTREGUE.** As duas direções chegam ao mesmo motor (`RenameRuleWritten`), porque o
conjunto de edição é UM SÓ: os tokens do result no `.ch` + as locais que as APLICAÇÕES
daquela regra ligam, em todos os módulos. Quem diz quais locais é o core — a P24
estampou no sítio o índice da aplicação, então `occurrences[].app` responde *"esta
referência foi escrita por AQUELA aplicação"*. Homônima em função que não usa o comando
não tem `app` e fica de fora (metade negativa do caso
`rename-directive-result-from-the-header`). Prova: `.hrb -gh -l` de todos os módulos
byte-idêntico — o `.ppo` NÃO entra, porque aqui a expansão muda de propósito.

**O que mudou em relação à spec abaixo, e por quê**

1. **O `--edit-rules` MORREU** *(Diego, 2026-08-07)*. Ele não estava na spec da P27, mas
   era o portão do irmão (`rename-function`), e manter um caminho com pedágio e outro sem
   seria incoerência entregue de propósito. As três justificativas caíram, cada uma numa
   medição: não protegia o projeto (o oráculo verifica), não podia proteger outros
   projetos (**"achar um projeto vizinho é pura sorte; e se estiverem em outro
   repositório, em outro computador"** — logo qualquer varredura seria sorte lida como
   resposta), e não protegia nem *"a edição sai do arquivo que você apontou"*, porque
   **"uma ferramenta de refatoração comumente refatora uma declaração que tem uso em
   diversos outros prgs do mesmo hbp"**. O caso **74b** executa esse argumento: um `.hbp`,
   três módulos, os três editados sem cerimônia.
2. **O veto por dono do arquivo (`ProjectOwnsFile`) saiu dos três caminhos de edição de
   diretiva**, virando `DiagExternalRule` (relato com o caminho). Além de contrariar a
   régua do Diego, ele perguntava *"onde o arquivo MORA?"*, que não responde *"quem mais o
   LÊ"* — medido: header ao lado do próprio `.hbp` passava pelo guard e quebrava um
   vizinho. **Isto inverteu o caso 119(1)**, da P-AUDIT/A1, que agora afirma o contrário.
3. **A P25 virou o caso de SUCESSO da P27** (`rename-local-written-by-directive`): a
   mesma fixture, o mesmo comando, veredito `refused` → `ok`. Era o que a P27 prometia
   ("a P25 o deixa VISÍVEL; a P27 o torna EDITÁVEL").
   > **Eu relatei que o `DiagRuleWrites` tinha ficado sem cenário, e estava ERRADO** — o
   > Diego perguntou o que ele era e a sonda derrubou a minha frase. Ele é alcançável: o
   > roteamento da P27 desvia só a local que a regra LIGA; homônima em módulo que inclui o
   > header sem usar o comando segue pelo `rename-local`. **E a sonda achou defeito pior
   > que o código morto que eu supunha**: naquele caminho o aviso terminava em *"the rename
   > cannot succeed while the two disagree"* — DIAGNÓSTICO, não fato, e falso ali (nada
   > discorda; o rename caiu por `E0030`, causa que estava no `diagnostics[]` ao lado).
   > A cláusula sobreviveu porque o único cenário em que alguém a rodava era o que a P27
   > passou a RESOLVER; o que sobrou chegando lá é justo o caso sobre o qual ela mentia.
   > **E os 5 porquês (ordem do Diego: provar a necessidade antes de manter o código)
   > reprovaram o helper inteiro.** Elo 5: para `local` não sobrou nenhum caso em que a
   > diretiva seja a causa — a P27 levou todos; e para `static`/`memvar`, onde ela É a
   > causa, ele nunca foi chamado (medido: `diagnostics[]` vazio). **Raiz: o diagnóstico
   > estava pendurado no VERBO em vez de no FATO.** O `DiagRuleWrites` foi REMOVIDO (79
   > linhas), a recusa deixou de arrastar coincidência, e o fato volta onde é causal — é a
   > [P28](#p28--a-diretiva-que-escreve-um-static-ou-um-memvar). O que ficou no lugar do
   > comentário é o caso `refuse-rename-invalid-name-does-not-blame-the-directive`, que
   > reprova a volta do aviso não-causal. **Régua: aviso declara o fato dele; a causa é de
   > quem recusou.**
4. **O `(builtin)` e o `--edit-rules` saíram do `unclassified`**: `RSN_RULE_BUILTIN`
   (`stop-and-report` — não é política, é física: não há arquivo). E o sítio de regra, que
   o `rename-function` cuspia com `OutErr` cru, virou `diagnostics[]` — sob `--json` ele
   caía FORA do envelope, e a recusa dizia "sites above" sem sites acima.

**Régua do Diego que ficou desta sessão** *(vale além da P27)*: **especificação em CÓDIGO
(teste) é preferível a prosa (comentário)**, e **comentário sobre um teste apodrece — se o
histórico precisa existir, ele mora JUNTO do teste, não no fonte**. Os comentários que eu
tinha escrito no `hbrefactor.prg` com essa narrativa foram encolhidos e a história está nos
casos 74, 119 e nos três casos novos.

**Limite honesto entregue:** o nome tem de ligar a um **LOCAL**. Ligando a
memvar/private/public/field, a ferramenta **recusa nomeando o escopo** — aqueles nomes
existem no pcode e a prova byte-idêntica não se aplica.

---

*(spec original, como foi escrita antes de executar)*

**O caso.** Uma diretiva do projeto escreve um nome no código que gera:

```harbour
// log.ch
#xcommand LOG <cMsg> => nLinhas += 1 ; OutStd( <cMsg> )
//                      ^^^^^^^ escrito aqui, e ligado ao LOCAL de quem usa
```

Renomear a **cabeça** do comando já funciona (`rename-dsl`, B4, verificado rodando).
Renomear o `nLinhas` do RESULTADO recusa: *"is not a match word of any project pp rule"*.
São dois lados da mesma regra, e só um é editável.

**Por que agora, e não antes.** A P25 registrou isto como "fora de escopo" com o argumento
de que um `.ch` pode ser usado por projetos que a ferramenta não vê. **O argumento estava
errado, e contra a própria lei** *(Diego, 2026-08-07: "quando um desenvolvedor decide
refatorar um `.ch` em um projeto, a responsabilidade é dele... o hbrefactor lida com o que
está definido no `.hbp`")*: o §1.2 já diz que o **hbmk2 é a fonte de verdade sobre o que é
o projeto**, e o `rename-dsl` **já edita `.ch`** — medido, o header foi reescrito. Eu
argumentei o oposto do que a ferramenta faz.

**E a P24 destravou o fato que faltava:** o sítio agora diz de qual APLICAÇÃO veio, então
o dump responde *quais locais, de quais módulos, aquela regra liga* — que é exatamente o
conjunto de edições do rename.

**TABELA DE SONDAS** *(§1.7.1 — medida em 2026-08-07, antes do mecanismo)*

| classe de caso | o que o core/ferramenta responde HOJE | comando |
|---|---|---|
| nome no resultado de regra do **PROJETO** | `log.ch:1:34`, `log.ch:2:45`, rótulo `in rule result` | `usages app.hbp nLinhas` |
| o LOCAL que a regra liga | `use (local)` com **`app`** apontando a aplicação | `harbour -x` + `occurrences[].app` |
| regra de `.ch` do **CORE** | `ppRules[].file` = caminho ABSOLUTO no `harbour-core/include` (127 regras do `hbclass.ch`, 54 do `hboo.ch`) | dump de um `CREATE CLASS` |
| regra do projeto | `ppRules[].file` = **relativo** (`log.ch`) | dump do fixture |
| regra **embutida** no pp (`#command ?`) | `(builtin)` — **sem arquivo, sem linha** | `usages q.hbp QOut` |

**A DECISÃO SOBRE ALCANCE É DO DIEGO, e ele a deu duas vezes** *(2026-08-07: "se o
programador decidiu mudar uma biblioteca, a responsabilidade é dele. mesmo que o `.ch` seja
do projeto, ou do harbour")*. Então **não há recusa por dono do arquivo**: se o `.hbp`
alcança a regra, a ferramenta edita — inclusive um `.ch` do próprio Harbour.

O que a tabela entrega, então, não é veto: é o **fato a RELATAR**. O campo `file` separa
sozinho os três casos, e o usuário tem de ver em qual está antes de a edição acontecer —
mexer no `hbclass.ch` altera a instalação, que é compartilhada por todo projeto da máquina e
não está no git do projeto dele. **`(builtin)` continua fora, e não por política: não existe
arquivo para editar.**

**Escopo**
- `rename` a partir de um nome no **resultado** de regra: edita o `.ch` **e** os locais que
  as aplicações ligam, dentro do `.hbp`. Mesma prova do `rename-dsl`: recompila e compara.
- **A direção INVERSA no mesmo passo** — renomear o LOCAL e a ferramenta editar o `.ch`
  junto. Sondado: a ferramenta **já acha** o outro lado (é o que a P25 emite como
  `diagnostics[]`); falta EDITAR. Hoje ela recusa e reverte, dizendo onde está.
- **Regra `(builtin)` recusa** — não há arquivo. Código de recusa próprio.
- **Regra em arquivo FORA da árvore do projeto** (o `hbclass.ch` do Harbour) **é editada**,
  e a ferramenta **DIZ** que o arquivo é externo e compartilhado, com o caminho. É relato,
  não veto — o §1 manda relatar o fato e deixar o humano decidir.

**Critério de pronto (mecânico)**: caso com `#xcommand` do projeto — rename a partir do
`.ch` edita os dois lados e sai `verified`; caso a partir do LOCAL, idem; caso com regra de `.ch`
do Harbour sendo editada **com o aviso do caminho externo**; caso `(builtin)` recusando com
código próprio e fontes byte a byte intactos; `make test` verde.

### P26 — `text` e `range` do mesmo sítio NÃO COMPÕEM *(aberto 2026-08-07; **✅ ENTREGUE 2026-08-07**)*

**Achado ao reescrever um caso para falar em CÓDIGO em vez de número mágico** (ordem do
Diego, 2026-08-07: *"tudo em um teste deveria estar claro usando código"*). A asserção
passou a recortar a palavra pelo `range` — e o recorte veio errado.

**O fato, medido** (`usages nAcc --json`, fixture `usages-site-from-include`):

| sítio | `text` que o envelope traz | `text[start:end]` | linha real do arquivo `[start:end]` |
|---|---|---|---|
| `declaration (local)` | `LOCAL nAcc := 0` | `c :=` | `nAcc` |
| `use (local)` | `CMD_SOMA 5` | *fora do texto* | `CMD_SOMA` |
| `read (local)` | `? nAcc` | *fora do texto* | `nAcc` |

O `range` é **absoluto no arquivo** (correto — é a posição de edição). O `text` vem
**sem os espaços da esquerda**. Um consumidor que use os dois juntos — que é exatamente
o que uma IDE faz ao destacar o trecho dentro do preview — pinta os caracteres errados,
ou estoura o fim da string.

**Por que nenhum teste pegava:** todos comparavam número contra número (`col == 3`) e
`text` contra `text`. Nenhum compunha os dois. A régua que isto deixa é a do §3 levada a
sério — asserção que fala em CÓDIGO (*"aponta a palavra `CMD_SOMA`"*) exercita a relação
entre os campos; asserção que fala em número exercita cada campo isolado.

**A decisão é do Diego, e não é óbvia:**
- **(a) `text` passa a ser a linha CRUA.** Os dois campos compõem, e o consumidor recorta.
  Custo: muda o `text` de todo sítio indentado — muitos `outputs.json` e a prosa.
- **(b) `text` continua aparado e o contrato DECLARA que ele é só para leitura humana**,
  nunca base de coordenada. Custo zero em código, mas o consumidor tem de reabrir o
  arquivo para destacar — que é o trabalho que o campo existe para poupar.

Recomendo **(a)**: o campo nasceu para a IDE e o agente decidirem sem reabrir o arquivo,
e aparado ele não serve para isso. Mas é mudança de contrato publicado.

**ENTREGUE — saída (a), com o alcance CORTADO por um fato do próprio roadmap.**

`SrcText()` deixou de aparar: o `text` do envelope é a linha **verbatim**, e
`text[start:end]` volta a recortar a palavra. `SrcLine()` (prosa) apara por conta própria,
então a prosa não mudou uma vírgula.

**O que a exploração derrubou, e vale mais que a entrega:**

- *"uma IDE pinta `text[start:end]`"* — **FALSO** para o consumidor real deste repo. A
  extensão VSCode monta `vscode.Location(uri, range.start)` e deixa o editor abrir o
  arquivo; ela **nunca lê `text`**. O exemplo que sustentava o argumento era um consumidor
  inventado.
- *"38 expectativas mudariam"* e *"o legado não assere o preview"* — **ERRADOS**, medidos
  aplicando de verdade: tirar o aparo dos dois canais dava **67** falhas no legado.
- **O argumento que sobreviveu não é meu**: a [spec-a § 2.5.0](spec-a-oraculo-para-agentes.md)
  diz que um consumidor de máquina que precise **reabrir o arquivo** reprova o critério da
  §4. Com o `text` aparado, é exatamente o que ele precisa fazer para saber quais
  caracteres o sítio cobre. A IDE não sofre porque o editor abre o arquivo por ela; o
  agente sofre.

**Delimitador: BOA IDEIA, LUGAR ERRADO** *(Diego propôs `<text>` ou `` `text` ``)*. Medido
nas fixtures: `<` aparece 53 vezes e `>` 72 (a DSL usa `<v>` o tempo todo); backtick, zero.
Então seria backtick. Mas **dentro do valor JSON ele desloca todos os índices em 1 e desfaz
o conserto** — a string JSON já é delimitada por aspas. O delimitador pertence a quem
RENDERIZA (extensão, MCP), não ao dado.

**E a prosa não ganhou delimitador porque ela vai MORRER** *(Diego, e confirmado na
[A.1 passo 3](#a1--contrato-de-máquina-na-cli): "a prosa é arrasto → deletada; a flag
`--json` some")*. Enclausurar a prosa custaria **72 asserções do legado** para decorar um
canal condenado. O corte veio do roadmap, não de estimativa minha.

**Custo real:** 2 linhas de fonte, 7 `text` em 3 casos do casedir, 25 em 7 casos da suíte
Go — **todos derivados do FONTE** de cada caso (a linha verbatim *é* a linha do arquivo),
nunca gravados de execução. Um caso (`usages-continued-statement`) comparava o preview
aparado na mão e passou a comparar a linha do arquivo, apontando a palavra.

### P25 — a recusa não conta o que a ferramenta JÁ SABE *(aberto 2026-08-07; **EM CURSO**)*

**O sintoma, medido.** Um `LOCAL nLinhas` no `.prg` e um `#xcommand LOG <cMsg> => nLinhas
+= 1` num header. O programador vê a declaração, renomeia — é a refatoração mais natural
que existe, e nada no `.prg` lhe diz que um header também escreve aquele nome. A
ferramenta edita os tokens do módulo, recompila, o pcode muda, e reverte. Certo. Só que o
que ele recebe é:

```
status   refused
reason   verification-failed-rolled-back
detail   verification FAILED: app.hrb changed - rollback
diagnostics: []
```

**O `diagnostics` VAZIO é a lacuna.** A causa está a um comando de distância — o `usages`
do mesmo nome lista `log.ch:1:34` e `log.ch:2:45`, *"in rule result (#xcommand LOG)"* —,
mas a recusa não a menciona, e o programador não tem como saber que existe essa pergunta
a fazer. Ele conclui *"a ferramenta não conseguiu"*, quando o certo é *"o nome também é
escrito ali, e é isso que precisa mudar junto"*.

**Não é fato novo: é FATO NÃO CONTADO.** `RuleSiteHits()` já extrai exatamente essas
ocorrências (lado `match` e lado `result` de `ppRules`), e é o que o `usages` usa. Falta
chamá-la no caminho da recusa e emitir o resultado como `diagnostics[]`.

**Por que agora, e por que importa mais para o agente:** o §1.6 diz que a recusa tem de
ser legível para o agente **RELATAR**, não contornar — e uma recusa que não nomeia a causa
empurra o LLM de volta para a substituição de texto, que é o modo de falha que esta
ferramenta existe para eliminar.

**Escopo**
- Helper `DiagRuleWrites( hAst, cName, hProj )`: reusa `RuleSiteHits()` e emite um
  `diagnostics[]` por ocorrência, com `location` (arquivo, linha, coluna) e o código
  `name-also-written-by-directive`.
- Chamado quando um `rename` **recusa por verificação/compilação** e o nome tem
  ocorrência em regra. Só na recusa: no sucesso seria ruído.
- **Não muda o veredito** — a recusa continua sendo a mesma, pelo mesmo motivo. Muda só
  o que ela CONTA.

**Critério de pronto (mecânico)**: caso na suíte com `#xcommand` escrevendo um local, o
rename recusando com `diagnostics[]` **não vazio** apontando o `.ch` com linha e coluna;
o `reason` e o `exit` **inalterados**; `make test` verde.

**Fora de escopo AQUI, e virou a [P27](#p27--o-nome-escrito-no-resultado-de-uma-regra-também-se-renomeia):**
renomear o nome escrito no RESULTADO da regra. A P25 o deixa VISÍVEL; a P27 o torna
EDITÁVEL. *(O argumento com que eu descartei a P27 — "um `.ch` pode ser de outro projeto" —
estava errado e contra o §1.2; ver lá.)*

### P24 — o sítio que veio de DIRETIVA não tem onde ser apontado, e são 40% deles *(aberto 2026-07-28; **✅ ENTREGUE 2026-08-07, `ast-23`**)*

**O que foi entregue.** O token que uma regra escreve **plainly no seu resultado** (o
`nAcc` de `#xcommand CMD_SOMA <v> => nAcc += <v>`) não vinha de marcador nenhum, então
nunca teve `from`-item — e ficava sem qualquer ligação com a diretiva que o escreveu. O
pp passa a estampá-lo com o índice da aplicação corrente, e o dump publica isso em dois
lugares: no token (`app`) e **no próprio sítio**, que é o que o consumidor precisa (o
sítio não expõe qual token é).

A ordem já era favorável e foi verificada, não suposta: `hb_pp_patternReplace()` chama
`hb_pp_trackApply()` **antes** de expandir o resultado, então `iDrvApp` na hora do clone
é o **desta** aplicação.

Sítio sem `col` mas com `app` passa a sair na posição da **cabeça da aplicação**
(`ppApplications[app].tokens[0]`, que já trazia linha/coluna/tamanho) — o lugar que o
programador de fato editaria. Na ferramenta, os três laços passaram a usar **um helper
só** (`SitePos()`), que era dívida da P21.

**Régua mantida:** o índice vem do core, nunca *"a aplicação que está na mesma linha"* —
duas diretivas numa linha tornariam isso adivinhação.

**Impacto zero conferido:** a estampa é guardada por `fTrackPos`, que só liga sob `-x`
(`cmdcheck.c`). `make pcode-identity`: **889/889 `.hrb` byte-idênticos, 0 divergentes**.

**Nota de numeração:** esta fase reservava o `ast-22`, consumido pela fase X (procedência
de ARQUIVO) que entregou antes. São eixos diferentes: a X pergunta *se um dump ainda
corresponde ao fonte*; a P24, *que diretiva escreveu este nome*.

**O que falta.** Um sítio cujo nome foi escrito num `.ch` sai sem posição: o token
tem `prov:"i"`, e `hb_compAstToken()` faz `if( ! fMain ) iCol = -1` — a coluna de
outro arquivo não é coluna deste. Correto para o compilador; para uma ferramenta de
refatoração é a resposta à pergunta mais útil sobre aquele sítio, e **medido no
`tbrowse.prg` do core são 40,3% dos sítios** (2.220 com `col` × 1.498 sem), porque
código Harbour real se constrói sobre DSL.

**Sonda feita (2026-07-27/28), e ela mudou o desenho.** A primeira leitura supunha
que a cadeia `token → from[].app → ppApplications[app]` já estava publicada. **Não
está**: o `from[]` só nasce para artefato de operação do pp — colagem, stringify,
clone (`hb_pp_fromAdd`, ppcore.c:783/808, `cOp` ∈ `c/p/s/d/D/m`). O `nAcc` que a
regra copia do próprio resultado é token COMUM: sai `{"line":1,"col":null,
"prov":"i","text":"nAcc"}`, **sem `from`**. Medido no fixture `usages-site-from-include`.

**Mas o fato existe e está a uma linha de distância**: `pState->iDrvApp`
(ppcore.c:1680) é o índice da aplicação corrente, posto assim que
`hb_pp_trackApply()` registra o `ppApplications[]` — é dele que as entradas de
derivação já se servem. O que falta é estampá-lo nos tokens de resultado COMUNS, não
descobri-lo.

**Escopo**
- **pp**: estampar cada token de resultado de uma aplicação com o índice dela,
  na mesma tabela lateral por identidade de token que o `pFrom` já usa
  (`hb_pp_posFind`) — nunca por texto. API pública nova no feitio das que existem
  (`hb_pp_tokenAppGet`), seguindo §1.2: **NUNCA mudar a saída de um comando/consulta
  existente**, sempre um canal novo.
- **compast**: publicar `"app": N` no token do canal `tokens[]`. Schema
  `ast-22 → ast-23` — **o `ast-22` foi consumido pela fase X** (procedência de ARQUIVO),
  que entregou primeiro; são eixos diferentes e não se bloqueiam.
  Nada muda em `col`/`tokLine`: sítio sem token no módulo continua
  sem posição, e é o consumidor que decide o que mostrar.
- **ferramenta**: sítio sem `col` cujo token tem `app` sai na posição da CABEÇA da
  aplicação (`ppApplications[app].tokens[0]`, que já traz `line`/`col`/`len`) — o
  lugar que o programador de fato escreveu e onde uma edição precisaria tocar. Sem
  `app`, segue de largura zero.
- **régua que não afrouxa**: nada de "a aplicação que está na mesma linha do sítio" —
  duas diretivas numa linha (`CMD_A 1 ; CMD_B 2`) tornam isso adivinhação. É o
  índice ou é nada.

**Critério de pronto (mecânico)**: `usages-site-from-include` verde (uso em `6:3..11`,
a entrada do `.ch` com `text`); um caso com **DUAS aplicações na mesma linha** provando
que cada sítio vai para a sua (o caso que a régua acima existe para travar);
`grep '"app"' `no dump do fixture com resultado; `lexdiff` 0; `make test` verde.

**Fora de escopo** (some junto se alguém confundir): publicar a coluna do token no
`.ch`. A pergunta que a ferramenta responde é *"onde eu edito"*, e a resposta é a
aplicação no `.prg` — o `.ch` já sai como entrada própria do relato.

### P21 — o `col` do sítio vem do NÓ, não de contagem: a P20 entregou INFERÊNCIA *(aberto 2026-07-27; **MECANISMO ENTREGUE 2026-07-27 `ast-21` — 3 DECISÕES DO DIEGO ABERTAS, ver § abaixo**)*

> **O mecanismo explicado do zero**: [posicao-do-sitio.md](posicao-do-sitio.md).
> Aqui fica o registro da fase; lá, o porquê de cada elo.

**O que foi entregue (core + ferramenta):** a contagem morreu e a
posição do sítio passa a vir do PARSER. O mecanismo não é nenhuma das duas saídas que
esta fase listou — a sonda achou uma terceira, e ela é a que o bison existe para dar:

- **`%locations` com `HB_COMP_YYLTYPE` = índice do token** (`hbcompdf.h`). O lexer
  carimba cada símbolo que entrega (`hb_compAstTokMark`), o bison carrega os carimbos
  na pilha de localizações **em passo com os valores semânticos**, e a ação lê `@N`.
  **Nenhum `$N` mudou de tipo** — era esse o custo que assustava na saída "estender o
  `YYSTYPE` do identificador", e ele simplesmente não existe por este caminho.
  `YYLLOC_DEFAULT` vira UMA atribuição; a pilha cresce 8 bytes por símbolo.
- **`HB_AST_AT( expr, @N )`** em 13 sítios da gramática entrega o token ao nó.
- **`HB_EXPR_USE` marca o nó que está sendo gerado** (`hb_compAstExprUse`), e o
  registro do sítio lê o token do nó marcado. Com `-x` desligado é um teste de flag
  já em cache e a mesma chamada indireta de sempre.
- **Onde a geração lê o nome de OUTRO nó** — as otimizações de operador
  (`x := x + y` → `x += y`) e a chamada otimizada, que leem o nome direto do filho —
  o sítio diz de quem ele é (`hb_compAstVarFind`, `HB_AST_SITE_BEGIN`). Sem isso o
  fato saía **ausente**, não errado: foi assim que a captura por codeblock apareceu.
- **`hb_compAstSiteCol()` DELETADO**, e com ele a janela para trás nos três
  recordadores. Sem token: **fato ausente**.
- **Ferramenta**: a prosa passou a usar a linha do SÍTIO (`tokLine`), que era a
  lacuna nomeada aqui — ela dizia `c.prg:7` enquanto o `--json` dizia 6. E o
  **fallback "primeiro token da linha" foi removido** dos três laços: sem `col`,
  range de largura zero, nunca um homônimo da mesma linha carimbado de `confirmed`.

**Medido (as três provas desta fase, todas compilando sob `-w3 -es2`):**

| repro | ast-20 dizia | ast-21 diz | verdade |
|---|---|---|---|
| `nTotal := 0 + Eval( {\| x \| nTotal += x }, 1 ) + nTotal` | use 3, ref 30, read 51, write **51** | use 30, ref 30, read 51, write 3 | ✅ |
| `o:Description := o:Description + "!"` | **5, 5** (leitura nunca relatada) | 5 e 22 | ✅ |
| `FOR i := 1 TO 3` / `nSoma += i` / `NEXT` | `tokLine` 7 `col` **15** (sítio alheio) | `line` 8, `tokLine` 6, `col` 7 | ✅ |
| `Dobro( Dobro( 2 ) ) + Dobro( 3 )` | 8, 15, 30 (por contagem) | 8, 15, 30 (por fato) | ✅ |

`make test`: legado **999/2**, `lexdiff` **100 concordantes / 0 divergências**, Go
**18/20**. Os 4 vermelhos são as três decisões abaixo — nenhum é defeito de mecanismo.

#### As três decisões do Diego — TOMADAS em 2026-07-27

**(1) `nTotal := nTotal + nTotal` — a expectativa da P20 era FABRICADA.** O
compilador otimiza `var := var <op> exp` para `var <op>= exp`
(`hb_compExprUseAssign`, HB_EA_REDUCE) e **libera o nó do operando do meio**. Sobram
**3 registros para 3 tokens**, e eles não são 1:1: `use`+`ref` descrevem o alvo
(col 3, o mesmo token, como na captura por codeblock) e `read` a ponta direita
(col 22). **O token do meio (col 13) não tem sítio nenhum** — e nunca teve; a P20
lhe deu uma coluna por contar 1º/2º/3º. Provado com nomes distintos: `nTotal := nA +
nB` sai read 13 / read 18 / write 3, tudo exato; `nTotal := nB + nTotal` (que não
otimiza) sai 13/18/3.
**DECIDIDO — estender o core** (*"perder uma ocorrência escrita num
find-all-references é regressão de produto"*): `hb_compAstFoldedRead()` registra a
leitura do operando ANTES de o reduce liberar o nó. A linha passa a sair
`read 13 / use 3 / ref 3 / read 22` — os **três tokens escritos cobertos**, com o
alvo em dois registros no mesmo token (a mesma forma da captura por codeblock). O
caso foi reescrito à mão para esse contrato.

**(2) Dois units do `run.sh` afirmam a PROSA VELHA** (2456 e 2927), e o nome do
segundo descreve o defeito como se fosse contrato: *"guaranteed no site da última
linha física"*. Eles esperam `q1.prg:93` e o preview `.T. }` — a última linha física
de um statement continuado. A prosa agora aponta a linha ESCRITA, igual ao `--json`.
São teste PRÉ-EXISTENTE (§3 do CLAUDE.md).
**DECIDIDO — re-baselinar os dois**, e o vizinho deles reforça: a asserção de
`run.sh:2910` já cobrava do `annotate` a **linha ESCRITA** (*"89 - a linha ESCRITA,
não a do declLine"*). A prosa do `usages` era a única peça fora de passo.

**(3) O sítio vindo de INCLUDE — a "decisão pendente" desta fase, agora com número.**
O caso `usages-site-from-include` pede o uso em `6:3..11` (o token `CMD_SOMA` da
aplicação). Hoje sai `6:0..0`. **O fato NÃO está publicado**: o token `nAcc` do `.ch`
sai `prov:"i"`, sem `col` (o core descarta coluna de outro arquivo) e **sem `from`**,
então não há como ligá-lo à aplicação. A cadeia honesta existe e é curta —
token → `from[].app` → `ppApplications[app].tokens[0]`, que JÁ traz `line/col/len`
— e a sonda de 2026-07-28 mostrou que **nem esse elo existe**: `from[]` só nasce para
artefato de operação do pp, e o token comum copiado do resultado da regra não tem
nenhum. O fato está em `pState->iDrvApp`, a uma estampa de distância.
**DECIDIDO — abrir a fase agora**: virou a
**[P24](#p24--o-sítio-que-veio-de-diretiva-não-tem-onde-ser-apontado-e-são-40-deles)**
(`ast-23`), com escopo e critério escritos. `usages-site-from-include` fica vermelho
até lá, e é o único vermelho da P21.

**Achado na revisão do próprio intervalo da P20.** A entrega dela reconstrói a coluna
**contando**: `hb_compAstSiteCol()` casa o K-ésimo registro de um nome numa linha com o
K-ésimo token daquele nome na mesma linha. Não existe vínculo entre um e outro — a ordem
dos registros é a de **redução do parser**, a dos tokens é a de **escrita**. É §1.2 gatilho
3 (*"se não é X então é Y"* sem fato que separe), e a ironia é que a própria P20 escreveu
que essa contagem *"erraria"* antes de implementá-la.

**As três provas, medidas (todas compilam limpo sob `-w3 -es2`):**

| repro | verdade | o dump `ast-20` |
|---|---|---|
| `nTotal := 0 + Eval( {\| x \| nTotal += x }, 1 ) + nTotal` | write 3, use/ref 30, read 51 | use **3**, ref 30, read 51, write **51** |
| `o:Description := o:Description + "!"` | escrita 5, leitura 22 | **5, 5** |
| `FOR i := 1 TO 3` / `nSoma += i` / `NEXT` | o `use` do NEXT não tem token | `tokLine` 7 `col` **15** — o `i` do `nSoma += i` |

Dois de quatro sítios errados no primeiro; a leitura nunca relatada no segundo (o nome
manjado `_X` entra na contagem como outro símbolo); no terceiro, o incremento implícito do
`FOR` recebendo a posição de um sítio alheio, e duas locations idênticas no relato. **Os
três saem `certainty: "confirmed"`** — a ferramenta afirmando com a mesma confiança o que
provou e o que contou.

**O incremento do `FOR` NÃO é "fato ausente"** — e classificá-lo assim, como a primeira
leitura fez, era observar a saída quebrada em vez de perguntar ao compilador. A gramática
reusa o MESMO nó da variável do cabeçalho (`harbour.y`: `hb_compExprNewPreInc( $2 )`, onde
`$2` é o `i` de `FOR i := ...`), e o canal `statements[]` do dump já publica isso:
`{"et": "PREINC", "line": 8, "left": {"et": "VARIABLE", "line": 6, ...}}`. A posição
verdadeira do incremento é o token do cabeçalho — **6:7** —, e o `line` 8 continua correto
como "onde o compilador estava". Dois sítios num token só é a mesma forma da captura por
codeblock, e é verdade. `make test` seguiu 1014/0: nenhuma fixture da P20 tem registro fora da ordem
de escrita.

**E o fallback agrava:** esgotada a contagem, `hb_compAstWriteSitePos()` cai em
`hb_compAstNamePos()` (janela de 16 tokens para trás), que devolve o ÚLTIMO token daquele
nome já consumido — foi de lá que saiu o `col 51` do write e o `col 15` do NEXT. Logo
[ast-schema.md](ast-schema.md) § `col` e `tokLine` afirma falso em dois pontos: *"a âncora na
linha limita o estrago"* e *"Fato ausente ≠ fato errado"*. O fato sai **errado**, não ausente.

**O fato existe, e não é contagem** — mas ele está mais fundo do que a primeira leitura
sugeriu, e a diferença importa:

- **Sondado e DESCARTADO:** o `nBirthTok` do nó de expressão (`hb_compAstNodeBorn`,
  compast.c:404) **não é o token do nome** — é o contador no nascimento do nó, deslocado
  pelo lookahead do parser. Medido em `FOR i := 1 TO 3` / `nSoma += i`: o nó `VARIABLE I`
  nasce com `tok` 12 (`:=`, sem coluna) enquanto o `i` é o token 11; `VARIABLE NSOMA` nasce
  com 17 (`+=`) e o nome é o 16; e a leitura `i` nasce com 18, que *é* o nome. Ora +1, ora
  +0. Ler o `nBirthTok` e procurar o nome perto dele é a mesma inferência com raio menor.
- **O fato:** quem conhece o índice exato é o LEXER — `hb_comp_tokenGet()`
  (complex.c:517) registra cada token no instante em que o compilador o puxa. Quando o
  lexer entrega um IDENTIFIER ao parser, o índice daquele token é exato e conhecido. **O
  trabalho é fazer esse índice VIAJAR** do lexer até o nó, e do nó até o registro do sítio
  — não reconstruí-lo depois.

**Escopo**
- **Sonda primeiro** (§1.1), e ela ainda não terminou: por onde a posição do identificador
  viaja até o nó. `YYSTYPE` de identificador é `char *` INTERNADO (compartilhado por todas
  as ocorrências do nome), então pendurar a posição nele não serve. As duas saídas a
  avaliar: estender o `YYSTYPE` do identificador (mexe em `harbour.y` e obriga o ritual dos
  três arquivos do parser, §2) ou o lexer manter o índice do último IDENTIFIER entregue,
  consumido por `hb_compAstNodeBorn`.
- Core: `hb_compAstUse`/`CallAdd`/`SendAdd` recebem a posição pela cadeia acima.
  **Deletar `hb_compAstSiteCol()`** e o `hb_compAstNamePos()` dos três recorders.
  Onde a cadeia não alcança: **fato AUSENTE**, nunca a janela para trás. Schema
  `ast-20 → ast-21`.
- Ferramenta: um helper só (`SiteLine`/`SiteCols`) consumido pelos três laços **e pela
  prosa** — hoje o idioma está copiado em três sítios, e foi por isso que a prosa ficou
  para trás na P20 (ela segue imprimindo `hItem["line"]`). Sem `col`, **não** cair no
  "primeiro token da linha" carimbado de `confirmed`.
- Docs: corrigir as duas afirmações falsas do ast-schema.md e o *"erraria"* da P20.

**Critério de pronto (mecânico)**: os três casos verdes
(`usages-write-and-capture-on-one-line`, `usages-send-write-and-read-on-one-line`, e o do
`FOR`/`NEXT`); `grep hb_compAstSiteCol` no core sem resultado; a prosa e o JSON dando a
mesma linha e a mesma coluna para o statement continuado; `lexdiff` 0; `make test` verde.

**Antes de escrever mais expected: a TABELA DE CLASSES DE SÍTIO.** Cada classe é uma
pergunta ao compilador — *que posição ele tem para este sítio, e por quê* — respondida com
sonda, ANTES de o expected existir. Sem ela, o expected do terceiro caso seria escrito da
saída, que é o vício que esta fase existe para matar.

| classe | exemplo | posição esperada | verificado |
|---|---|---|---|
| leitura/escrita comum | `nSoma += i` | o token do nome | ✅ (casos da P20) |
| captura por codeblock (`use`+`ref`) | `{\| x \| nTotal += x }` | um token, DOIS sítios | ✅ caso escrito |
| send-escrita (`_X`) + leitura | `o:X := o:X + "!"` | tokens distintos | ✅ caso escrito |
| incremento implícito do `FOR` | `FOR i := 1 TO 3` … `NEXT` | o `i` do CABEÇALHO | ✅ provado na gramática + `statements[]` |
| statement continuado com `;` | `cMsg + ;` | token na linha anterior | ✅ (P20) |
| leitura da variável de macro | `? &cNome` | o token `&cNome` (10:5) | ✅ sondado — **e é um 4º defeito** |
| símbolo de expansão de diretiva | `CMD_SOMA 5` → `nAcc += 5` | **ausente** — `prov != 's'` | ✅ sondado: o dump omite `col` e `tokLine`, correto |
| sítio cujo token vem de INCLUDE | `METHOD` de `hbclass.ch` | **decisão pendente** | ✅ medido: **40% dos sítios** |
| checagem `-kt` (`hb_compAstUseChk`) | `LOCAL x AS NUMERIC` | ? | ⬜ a sondar |

**Sonda da variável de macro (o 4º defeito, medido 2026-07-27):** `LOCAL cNome := "nAcc"` na
linha 6 e `? &cNome` na linha 10. O pp entrega **`&cNome` como UM token só**, `prov='s'`,
coluna 5 — não existe token cujo texto seja `cNome` naquela linha. A janela para trás procura
por `cNome`, não acha, e devolve a posição da DECLARAÇÃO: `usages cNome` responde **três
sítios todos em 6:9**, e **a linha 10 desaparece** do find-all-references. Não é fato ausente
(a posição existe, em 10:5): é fato errado, e é o mais visível dos quatro porque some com uma
linha inteira. *(Não confundir com a P18, que é o símbolo DENTRO da string do macro — esse sim
não tem posição.)*

**Sonda da expansão de diretiva:** `#xcommand CMD_SOMA <v> => nAcc += <v>` em `k.ch` linha 1,
usado em `k.prg` linha 8. O token `nAcc` resultante sai **`prov='i'`, `line: 1`** — a linha do
`.ch` — e **sem coluna**, porque `hb_compAstToken()` faz `if( ! fMain ) iCol = -1`. Ou seja, a
classe correta é **`include`**, não "sintetizado": o token foi ESCRITO, só que noutro arquivo.
*(E repare na assimetria que fica: a LINHA de outro arquivo é preservada, a COLUNA é
descartada — um consumidor que leia `line: 1` sem saber disso acha que é a linha 1 do `.prg`.)*

**Sonda da procedência, no corpus do core (`tbrowse.prg`, 17.517 tokens, 3.718 sítios):**
identificadores por procedência — **3.958 do fonte, 1.859 de include, 220 sintetizados**; e
os sítios: **2.220 com `col` (59,7%) × 1.498 sem (40,3%)**. Em código Harbour real, que se
constrói sobre DSL, o sítio sem posição no módulo **não é canto — é 40% da resposta**
(§1.7/2). E o core **descarta um fato** ali: `hb_compAstToken()` faz `if( ! fMain ) iCol = -1`,
jogando fora a posição que o token TEM no `.ch`. Para o compilador é defensável; para uma
ferramenta de refatoração é a resposta à pergunta mais útil sobre aquele sítio — *"este uso
nasce de uma diretiva, não está no seu arquivo, e você não o edita aqui"*.

**Decisão pendente do Diego, e ela só vale para as classes AUSENTES** (as três últimas —
o `FOR` saiu da lista): sem coluna, o que o `usages` relata? `certainty` é sobre a
**referência**, não sobre a posição. Recomendação: **range de largura zero** (`start ==
end`), que nenhum sítio com token pode ter e que o [`LocAdd`](../src/hbrefactor.prg) já
produz quando não recebe coluna — sinal contratual, sem campo novo e sem `cli-3`.

### P20 — `occurrences[]`, `calls[]` e `sends[]` dão LINHA e não COLUNA, e o `usages` aponta o lugar errado *(aberto 2026-07-27; **⚠ ENTREGUE 2026-07-27 `ast-20`, 4 casos — mas por INFERÊNCIA; ver [P21](#p21--o-col-do-sítio-vem-do-nó-não-de-contagem-a-p20-entregou-inferência)**)*

> **Entregue no mesmo dia, por ordem do Diego** (*"a lacuna do core tem que ser resolvida
> agora no quente"*), e **nos TRÊS canais de sítio** — a varredura que ele mandou fazer em
> seguida (*"procure se deixou passar algo parecido"*) achou a lacuna idêntica em
> `calls[]` e `sends[]`, e a de `calls` é a que mais aparece em código real.
>
> No CORE (`src/compiler/compast.c`): `hb_compAstSiteCol()` casa o K-ésimo sítio de um nome
> numa linha com o K-ésimo token de fonte daquele nome na MESMA linha, e os três emissores
> passam a escrever `col` (0-based, OPCIONAL — ausente, nunca adivinhado, quando o fluxo de
> tokens não carrega o nome). Ele também desfaz o `_X` que o próprio compilador cria para
> `o:x := v`, então o par escrita/leitura do mesmo membro numa linha resolve certo. Schema
> `ast-19 → ast-20`. Na FERRAMENTA: `AstSchema()` acompanha e os três laços do `usages`
> consomem o `col` por `hb_HGetDef`, caindo no caminho antigo quando o fato falta.
>
> | sonda | antes | agora |
> |---|---|---|
> | `n := n + n` | 3, 3, 3 | **3, 13, 22** |
> | `Dobro( Dobro( 2 ) ) + Dobro( 3 )` | 8, 8, 8 | **8, 15, 30** |
> | `? o:Description, o:Description` | 7, 7 | **7, 22** |
>
> **E um TERCEIRO defeito, de outra natureza, achado na mesma varredura: STATEMENT
> CONTINUADO.** Ali não faltava a coluna — a **linha estava errada**. O `line` de um sítio é
> a linha em que o compilador estava, e num statement continuado com `;` isso é a ÚLTIMA
> linha física; o sítio está numa anterior. O uso de `cMsg` em `OutStd( "x" + ; / cMsg + ; /
> "y" )` saía na linha do `"y" )`, coluna 0, com o texto de outra linha. **Nenhum teste via.**
>
> Resolvido sem mexer no significado de `line` (que consumidores usam para correlacionar
> canais): os três recorders passam a **capturar a posição do token no momento do REGISTRO**,
> pela mesma janela para trás que as `declarations` já usavam, e o dump emite `tokLine` **só
> quando ela difere** de `line`. Ausência de `tokLine` significa "é a mesma", nunca "não sei".
> Medido: o sítio continuado sai em **44:11** com o texto `cMsg + ;` (era 45:0 com `"y" )`).
>
> Quatro casos travam os três canais e as duas naturezas de defeito
> (`usages-many-sites-on-one-line`, `usages-nested-calls-on-one-line`,
> `usages-two-sends-on-one-line`, `usages-continued-statement`). `make test` 1014/0,
> `lexdiff` 0 divergências, caso 122 casando `ast-20 == ast-20`. Controle negativo rodado:
> com o `col` ignorado, o caso reprova nomeando as colunas erradas.

**Achado ao migrar o `unit_9`** — apareceu porque o formato de caso compara o envelope
INTEIRO; o teste legado usava `envloc` (*"ache isto na lista"*), que não podia vê-lo.

**O buraco:** cada registro de `occurrences[]` traz `sym`/`scope`/`access`/`block` e **`line`
— nunca `col`** ([docs/ast-schema.md](ast-schema.md) § occurrences). Com N registros na mesma
linha, a ferramenta não tem como dizer a QUAL token cada um pertence, e resolve todos pelo
primeiro token do nome naquela linha.

**Repro (compila limpo sob `-w3 -es2`):**

```
PROCEDURE Main()
   LOCAL nTotal
   nTotal := 1
   nTotal := nTotal + nTotal
   ? nTotal
   RETURN
```

Os três tokens da 4ª linha estão nas colunas **3, 13 e 22** (0-based). O dump traz três
registros (`use`, `ref`, `read`), todos com `line` e sem `col`, e o `usages` relata os três
em **3, 3, 3** — dois sítios apontando para o lugar errado. Quem consome (IDE, agente) pula
para a coluna errada, ou vê "três usos no mesmo ponto".

**E a ferramenta NÃO pode se virar sozinha:** casar o N-ésimo registro com o N-ésimo token é
inferência, e **erraria** — medido: a ordem dos registros é `use, ref, read` enquanto a dos
tokens é *alvo-de-atribuição, leitura, leitura*. §1.2, gatilho 3 (*"se não é X então é Y"*
sem fato que separe). **LACUNA REAL → extensão de core.**

**O `rename` NÃO é afetado, e a razão importa:** ele não mapeia registro→token — edita
**todos** os tokens daquele nome na linha e a recompilação prova (`editCount` 6,
`pcode-identical` no repro acima). Só o relato posicional depende do fato que falta.
*(Não confundir com a [P18](#), que é o símbolo emitido pelo macro-unwrap: lá falta posição
no token; aqui o token TEM posição e o que falta é o vínculo do registro com ele.)*

**Critério de pronto (mecânico)**: `occurrences[]` ganha `col` apontando o token daquele
registro (campo NOVO — o schema sobe de versão, e `AstSchema()` acompanha); o `usages` do
repro passa a relatar 3, 13, 22; caso novo em `tests-go/suite/` com a fixture do repro,
provando as três colunas distintas; o caso `usages-local-scope-aware` continua verde
(lá a linha tem UM token, então as colunas não mudam); `lexdiff` 0; `make test` verde.

### P19 — o `#pragma` muda a SEMÂNTICA de uma região, e o dump não conta *(aberto 2026-07-15; **A RESOLVER**)*

**Achado do estudo de `harbour/tests/pragma.prg`** (a superfície `#pragma`, indicada pelo Diego).
O `#pragma` **não é configuração do build**: ele muda o **compilador no meio do arquivo**. A
partir da linha em que aparece, o **mesmo texto-fonte** passa a gerar pcode **diferente** — e nada
no código denuncia isso, só a linha do pragma lá atrás. Cadeia no fonte:
`src/pp/ppcore.c:3779` (o `SHORTCUT` vira o switch `"z"`) → `src/compiler/ppcomp.c:211` (`z+` **tira**
o flag `HB_COMPFLAG_SHORTCUTS`, ou seja liga a avaliação dos dois lados do `.AND.`).

**Consequência, VERIFICADA** (`tests/ppc-pragma/pg.prg`, roda e afirma): com `#pragma Shortcut=On`,
`.F. .AND. Efeito()` **CHAMA** `Efeito()` (efeito colateral acontece); com `Shortcut=Off`, não. O
código é idêntico letra por letra — e o `.ppo` entrega os **dois `IF` com o mesmo texto** (módulo o
nome do local): a diferença de comportamento **não está no texto** que o compilador recebe, está no
switch. **O `.ppt` é o único oráculo que enxerga o pragma** (uma linha de trace por sítio); o **dump
não exporta pragma nenhum** (`grep pragma` no `.ast.json` = 0; os hits de `Shortcut` são só os nomes
de local).

**Consequência para o refatorador:** a ferramenta **não sabe** que uma região do arquivo compila com
outra semântica. Mover código entre regiões — o `extract-function` joga a função nova no **fim** do
arquivo — pode mudar o pcode do código movido, **em silêncio**.

**Classificação: LACUNA REAL** (o fato não está em oráculo consumível — só no `.ppt`, que a
ferramenta não lê) → **experimento de core** (o pp **sabe** o estado do switch por região; ele só não
conta ao dump).
**Critério de pronto (mecânico)**: o dump exporta as regiões de switch de compilação (posição da
linha do pragma + switch + valor); o `extract-function`/`move` **recusa com motivo** quando origem e
destino caem em regiões de switch divergentes; `lexdiff` 0 e `make test` verde.

### P18 — o símbolo DENTRO do macro chega SEM POSIÇÃO *(aberto 2026-07-13; **A RESOLVER**)*

**Achado do estudo de `harbour/tests/pp.prg`** (o teste que os autores do pp escreveram para
o pp — indicação do Diego). Diante de um **macro puro**, o `<"z">`/`<(z)>` **não estringificam**:
o pp **desfaz o `&`** e emite o identificador como **código** (`ppcore.c:5250-5262`, `value + 1`,
derivação registrada como **`clone`**). É a semântica Clipper (`USE &cArquivo` tem de virar a
variável). **Logo o nome dentro do macro é SÍMBOLO DE VERDADE** — o compilador o lê, e
`occurrences[]` o registra.

**O buraco:** o recheio consumido (`&cAlvo`) **tem posição** (linha, col, len); o símbolo
**emitido não tem** (`col: null`, `prov: "n"`), e o `at` da derivação é **0** — aponta o `&`,
não o nome. **Verificado:** o `usages` acerta (relata o *read*), mas o `rename` edita **só a
declaração**, o `.hrb` muda e o verificador reverte — **recusa falsa num rename que seria
byte-a-byte legítimo**.

**E a ferramenta NÃO pode se virar sozinha:** deduzir *"pule 1 caractere (2 se terminar em
ponto)"* é **réplica de gramática do core** (§1.2, gatilho 2). O core **acabou de calcular**
`value + 1` — e não conta a ninguém. **LACUNA REAL → experimento de core.**
*(Cuidado com a intuição fácil: **isto NÃO é a parede do macro**. Não há macro em runtime — o
pp o desfez em tempo de compilação. Tratar todo `&` como opaco é heurística por aparência.)*

**Critério de pronto (mecânico)**: o token emitido pelo macro-unwrap chega com `line`/`col`
apontando o **NOME** (não o `&`) e `prov: "s"`, e o `at` da derivação bate; o `rename` do
símbolo passa a editar `&cAlvo` → `&cNovo` e **verifica byte-idêntico**; a guarda
`corpus_strfam` (que hoje assere a LACUNA) inverte de sinal; `lexdiff` 0; `make test` verde.

### P17 — a COMPILAÇÃO CONDICIONAL esconde CÓDIGO, e a ferramenta diz "verified" sobre o que não olhou *(aberto 2026-07-13; **ampliado 2026-07-23**; **A RESOLVER — o mais grave em aberto**)*

**Achado da medição de USO** (direção do Diego: estudar o pp no fonte real do Harbour). O core
declara diretiva **dentro do próprio `.prg`** em **152 dos 419 módulos** do corpus (36%), com
**1.640 comandos inventados** e 6.528 aplicações. E o padrão campeão — `rddtst.prg`, a DSL de
teste do RDD, **1.881 usos** — declara **DUAS regras rivais com a MESMA cabeça**, uma em cada
ramo de um `#ifdef`.

**O dump só enxerga o ramo ATIVO.** As diretivas do ramo desligado não existem em canal nenhum
(nem `.ppo`, nem `.ppt`, nem dump) — o pp as pula e não deixa rastro.

**Consequência, VERIFICADA (repro mínimo, Harbour puro):**

```harbour
#ifdef MODO_RASCUNHO
   #xcommand PINTA <x> => pt_Rascunho( <x> )   // <-- INVISÍVEL a esta compilação
#else
   #xcommand PINTA <x> => pt_Final( <x> )
#endif
PROCEDURE Main()
   PINTA 7
```

`rename PINTA -> COLORE` edita a diretiva do `#else` **e o uso**, deixa o ramo `#ifdef` com
`PINTA`, e **anuncia sucesso**: *"verified: 1 application site(s) + 1 directive occurrence(s);
.ppo and .hrb byte-identical"*. E então:

```
$ harbour m.prg -DMODO_RASCUNHO
m.prg(9) Error E0030  Syntax error "syntax error at '7'"
```

**A ferramenta escreveu uma árvore quebrada e disse que estava tudo certo.** É a promessa
central do produto sendo violada — e em silêncio, porque a rede de verificação (`.ppo`/`.hrb`
byte-idênticos) é sobre a **configuração que ela viu**, e a outra configuração é **outro
programa**.

**Classificação: LACUNA REAL** (o fato não está em oráculo nenhum) → **experimento de core**.
O pp **sabe** que pulou aquelas linhas (`iCondCompile`); ele só não conta.

**A resposta NÃO é editar os dois ramos** — o ramo desligado é **não-verificável** nesta
compilação, e o §1 é explícito: não se edita o que não se pode provar.

---

#### ACHADO AMPLIADO (2026-07-23) — não é sobre diretiva; é sobre QUALQUER NOME

*(Levantado ao abrir a fase; o Diego mandou **marcar como achado importante** antes de decidir
o desenho. Regra de lacuna do P-DOC: **PROVE, MARQUE e SIGA**.)*

O enquadramento acima ("esconde diretiva") é onde o problema **apareceu**, não o que ele é. O
mecanismo é o mesmo para código comum, e o modo de falha é idêntico — **segundo repro,
executado no toolchain corrente**:

```harbour
PROCEDURE Main()
#ifdef MODO_RASCUNHO
   Registra( 1 )        // <-- INVISÍVEL a esta compilação
#else
   ? "final"
#endif
   Registra( 2 )
   RETURN
PROCEDURE Registra( n )
   ? n
   RETURN
```

```
$ hbrefactor rename n.hbp n.prg:13:11 Anota
rename-function: Registra -> Anota
verified: 2 edit(s); symbol tables renamed as expected, pcode byte-identical    <-- exit 0

$ hbmk2 n.hbp -DMODO_RASCUNHO
hbmk2: Error: Referenced, missing, but unknown function(s): REGISTRA()
```

**O que os dois repros têm em comum não é a diretiva — é a palavra `verified` sobre um
programa que a ferramenta nunca olhou.** Ela não falha: ela **afirma sucesso** fora do alcance
do que verificou. Qualquer desenho que feche só o caso da cabeça de DSL deixa este de pé.

**A VARREDURA do core (§1.3 — registrada aqui porque recusa exige varredura ANTES):**
- `include/hbpp.h` — a struct de estado expõe `iCondCompile`/`iCondCount`/`pCondStack`, mas
  **nenhum dos nove callbacks públicos** (`open`, `close`, `error`, `disp`, `dump`, `inline`,
  `switch`, `inc`, `msg`) reporta região pulada. Não há acessor nem hook.
- `harbour --help` inteiro — só `-d<id>[=<val>]`; nada que peça ou emita relato de ramo pulado.
- **`.ppt` (`-p+`): NADA** sobre o ramo desligado (probado, não lembrado) — some até do trace,
  que é o oráculo mais verboso. `.ppo`: só o ramo ativo. Dump: `ppRules[]` lista **só** a regra
  do ramo vivo.
- `ChangeLog.txt` — nada sobre expor compilação condicional.

**O PONTO DE FISGADA (e por que isto NÃO é computação nova):** em `hb_pp_preprocessToken`
(`src/pp/ppcore.c`) a linha pulada **já chega tokenizada** e é descartada — no ramo de
diretiva (`else if( pState->iCondCompile )`, comentado *"conditional compilation - other
preprocessing and output disabled"*) e no de linha comum (`hb_pp_tokenListFreeCmd` sobre a
`pTokenList`). **O core quebra o ramo desligado em tokens e joga fora.** Pedir que ele conte
é o padrão do §1.2, não trabalho novo.

**As três formas do fato (trade-off medido pelo que o canal PERMITE DECIDIR):**

| fato exportado | a ferramenta decide por | custo |
|---|---|---|
| **(a) todo identificador pulado** (palavra + posição) | **identidade de nome** — zero casamento de texto | aviso/recusa **precisos** (só quando é o SEU nome); canal maior |
| (b) só cabeça de diretiva (parseada pelo pp, regra não ativada) | identidade de cabeça | cirúrgico, mas deixa o repro do `Registra` de pé |
| (c) só as faixas de linha puladas | **nada** — decidir exigiria ler o TEXTO daquelas linhas (gatilho 1) | canal mínimo, mas dispara em **36% dos módulos**, sempre: vira ruído |

**Nota sobre a (a), que é a recomendação:** a palavra num ramo desligado é **texto cru, não
preprocessado** — pode nem ser símbolo (poderia ser cabeça de DSL que viraria outra coisa).
Logo o fato serve para **RELATAR/RECUSAR, jamais para EDITAR**: a ferramenta nunca "conserta o
outro ramo".

**CONSIDERADO E POSTO DE LADO — rename multi-configuração** *(o Diego perguntou o custo, e ele
condena a ideia)*: seria compilar e verificar o projeto **uma vez por configuração**, ou seja
**linear no número de `-D`** — dobrar a espera que já é a maior queixa da ferramenta (fase V:
`usages` 12-15 s em 43 módulos). Pior que o tempo: **não existe fato que enumere as
configurações de um projeto** — os `-D` vêm do `.hbp`, da linha de comando, do hábito da
equipe. A ferramenta só poderia prometer *"provei as que você nomeou"*, o que é
**incompleto por natureza**. Volta como fase própria se a demanda aparecer.

**A DIREÇÃO DO DIEGO (2026-07-23):** *"rename somente no branch vivo, seguindo o que o
compilador vê"* — a edição **não muda**; o que muda é o **VEREDITO**. A ferramenta continua
agindo sobre uma configuração só e passa a dizer a verdade sobre o **alcance** do que fez.

#### O EXPERIMENTO que fechou o desenho *(2026-07-23, autorizado pelo Diego: "tenta aí vamos ver o que acontece"; revertido depois de medir — não está na árvore)*

**A hipótese testada, do próprio Diego:** *"se peço um rename, o nome velho não deveria mais
existir"* — um pós-teste de COMPLETUDE, sem tocar no core. Implementado como
`UnseenNameHits`: ocorrências do nome velho **no texto** MENOS as posições que o compilador
reportou como token (`col+1` aponta o início do nome, verificado, tanto em identificador
quanto em string). O que resta é o ponto cego. Ligado ao portão de **referências textuais que
já existe** (o mesmo `aWarn` + `Refuse` + escape `--force` do `rename-function`).

**Funcionou como detector.** Pegou os dois repros, ficou mudo no caso legítimo (função de
biblioteca sem chamador), e **achou um caso REAL no corpus que eu não conhecia**:
`work/xhb/xhbole.prg:248` — o `FUNCTION CreateObject` do OLE, dentro do ramo **Windows** de
`#ifndef __PLATFORM__WINDOWS` (linhas 48-260). Renomear no Linux deixa a implementação Windows
com o nome velho, e o build Windows quebra calado. **O P17 está no corpus.**

**E MORREU como recusa, por MEDIÇÃO.** 20 renames reais em `work/xhb`, 13 avisos:

| o que o aviso apontava | n |
|---|---|
| **código real em ramo pulado** (`xhbole.prg` 248 e 254) | **2** |
| comentário (`*`, `//`, `/* */` com código comentado) | 9 |
| nome dentro de string maior (`" Arguments: ("`) | 2 |

E a suíte deu o veredito final: **3 casos vermelhos**, os três pela MESMA causa — o
`fixshadow` recusou o rename porque **o comentário de cabeçalho da própria fixture** cita
`Dobra`. Uma ferramenta que recusa renomear uma função porque um comentário a menciona é
inutilizável.

**A LIÇÃO, e ela CONTRADIZ o que eu tinha escrito acima:** eu havia concluído que a mudança no
core viraria *opcional*. **Errado.** Para quem só lê texto, um comentário e um bloco `#ifdef`
desligado são **a mesma coisa** — linhas que não entraram na compilação. A diferença não está
no texto, então nenhuma esperteza textual a alcança. **Só o compilador sabe separar**, e é por
isso que o fato do core é o que faz a coisa funcionar, não o polimento dela.

#### O DESENHO (o que implementar)

**Fatia 1 — o core conta o que pulou** (um hook, no ponto de fisgada já identificado em
`hb_pp_preprocessToken`, sob o mesmo portão de rastreio de posição do resto):
- a **região**: arquivo, linha de abertura e de fechamento, e o **nome testado** no
  `#if[n]def` (é o que permite a mensagem dizer *"reponha `-DVERSAO_DEMO`"*);
- os **identificadores dentro dela** — que o pp **já tokeniza e descarta**. Isto é o que
  elimina a busca de texto do lado da ferramenta: ela compara **nome com nome**, como no
  `macrovars` do `ast-18`. *(Alternativa mais barata: só a região, e a ferramenta busca texto
  **dentro dela**. Funciona e mata os 9 falsos positivos — mas deixa uma busca de texto na
  ferramenta, e por isso não é a preferida.)*
- schema `ast-18 → ast-19` nos DOIS repos no mesmo passo; expansão byte-idêntica.

**Fatia 2 — o verificador para de afirmar fora do alcance**:
- o veredito declara o **escopo**: em vez de `verified:` seco, dizer que a prova vale para a
  configuração compilada e que N linhas do módulo ficaram fora dela;
- o aviso por nome, **preciso** (só o que caiu em região pulada de verdade);
- **helper COMPARTILHADO**: o experimento mostrou o rot na prática — ligado só ao
  `rename-function`, o caso da diretiva (`rename-dsl`, outro verbo, outro `verified:`) passou
  batido. Há ~12 pontos que imprimem `verified:`; a checagem entra **uma vez** e cada verbo
  chama.
- comentário e string ficam **fora**: para eles o mecanismo certo já existe (o portão de
  referências textuais, que só relata o que o compilador VIU).

**A decisão aviso × recusa fica para DEPOIS do fato existir**, e se decide medindo de novo —
com o aviso preciso, recusar volta a ser viável. O experimento mostrou que decidir isso antes
seria palpite.

**Critério de pronto (mecânico)**:
1. ✅ o dump exporta as regiões puladas (arquivo, faixa de linhas, nome testado) e os
   identificadores dentro delas; `.hrb` byte-idêntico sem os switches;
2. ✅ **teste em formato fixture-esperada** *(ordem do Diego, 2026-07-23)* — o `.prg` DEPOIS
   do rename comparado **byte a byte** com o esperado, escrito ANTES do código;
3. ✅ o caso real do corpus (`xhbole.prg`) produz aviso **nomeando `__PLATFORM__WINDOWS`**;
4. ✅ **nenhum aviso novo** por comentário ou string — as fixtures que o experimento textual
   derrubou seguem verdes sem re-baseline;
5. ✅ régua executável: verbo de rename que **não** chame o helper compartilhado reprova a
   suíte ([tests/regua-escopo.sh](../tests/regua-escopo.sh));
6. ✅ `make test` verde e `make ppcorpus` verde.

**ESTADO (2026-07-24) — fatias 1 e 2 ENTREGUES; DUAS pontas abertas.**

- **Fatia 1 ✅** — o core exporta `ppSkipped[]` (região: arquivo, `from`/`to`, o define
  testado; mais os identificadores que o pp já tokenizava e descartava). Hooks em
  `hb_pp_preprocessToken` (os dois ramos: linha de diretiva e linha comum), pilha de nomes em
  passo com a `pCondStack`, API pública aditiva `hb_pp_trackSkip*`. Schema `ast-18 → ast-19`
  nos dois repos no mesmo passo. **Impacto zero re-medido contra a base CORRETA: 889/889, 0
  divergentes** (ver a dívida da base, abaixo).
- **Fatia 2 ✅** — `SkippedNameHits`/`SayScope`/`ScopeTag` consomem o fato **casando NOME com
  NOME**; `rename-function` e `rename-dsl` avisam e o `verified:` sai **qualificado**:

  ```
  warning: cond.prg:17: 'AvisaLimite' also occurs here, in code this build did not compile
  (excluded by #ifdef VERSAO_DEMO - rebuild with -DVERSAO_DEMO to see it) - it was NOT renamed
  warning: the proof below covers THIS configuration only; the other one is a different
  program and was never compiled here
  verified: 1 edit(s); symbol tables renamed as expected, pcode byte-identical (this configuration only)
  ```

  **Aviso, nunca recusa** (exit 0): a edição provada está certa — o que faltava era o veredito
  parar de afirmar além do alcance. Módulo sem ramo desligado **não ganha aviso nenhum**.

**A RÉGUA pegou o meu próprio rot, e é a prova de que ela era necessária.** Escrita ANTES de
tapar os buracos, ela acusou que eu tinha ligado **2 verbos de 6** — faltavam `rename-static`,
`rename-memvar` e `rename-rule-marker`. Todos ligados; a régua roda na suíte e reprova verbo
novo sem o aviso. *(Um STATIC é local ao arquivo, então o alcance declarado é o do arquivo
dele — não o do projeto.)*

**O `xhbole.prg` do corpus fecha o item 3, com a saída real:**

```
warning: xhbole.prg:248: 'CreateObject' also occurs here, in code this build did not compile
(excluded by #ifdef __PLATFORM__WINDOWS - rebuild with -D__PLATFORM__WINDOWS to see it) - it was NOT renamed
```

**Dois defeitos meus que o probe do corpus expôs, ambos consertados:**
- o **`--dry-run` não avisava** (o retorno antecipado ficava antes do ponto onde liguei o
  aviso) — e dry-run é JUSTAMENTE quando se quer saber o alcance, antes de mexer;
- a frase *"the proof below covers THIS configuration"* **mentia no dry-run**, onde não há
  prova nenhuma abaixo. Trocada por uma que é verdadeira nos dois modos.

## Dívidas e limites conhecidos

### P15 — o rename através do `#<x>`: um BUG e uma decisão *(aberto 2026-07-13; **A RESOLVER**)*

**(1) BUG — VERIFICADO, sem decisão pendente.** Num `MENU TO nEscolha` (Harbour puro, zero
include), o `usages --at` no sítio da diretiva devolve **1 resultado** e chama o `nEscolha` de
*"marker name (no identifiable owner)"* — **perde a declaração e a leitura do LOCAL**. O
`rename` daí edita só o sítio da DSL; o verificador vê a contagem de símbolos mudar e reverte
(fonte intacto, mas **recusa falsa por resolução errada**). Causa:
[src/hbrefactor.prg:2106](../src/hbrefactor.prg#L2106) — `generates` *"vence QUALQUER binding
homônimo"*, regra escrita para o local que a **expansão fabrica** e que não separa esse caso do
local que a diretiva apenas **referencia** (gatilho §1.2/3: *"se não é X, então é Y"* sem fato
que separe). **O fato que separa JÁ ESTÁ NO DUMP**, em dois eixos, os dois verificados: (i) o
recheio só é símbolo se a derivação tiver **`clone`** (`from[].op`) — só-`stringify` é DADO, e
esse eixo a ferramenta **já respeita** (renomear o local não toca um `LAVRA nLastro` homônimo:
guarda `corpus_strdump`); (ii) o dono do símbolo sai de `declarations[].nameLine`/`nameCol`, que
**coincide** com o recheio no local FABRICADO pela expansão e **não coincide** no local do
programador — e é este eixo que falta. Identidade posicional contra `ppApplications[]`, zero
texto. É **consumo**, não core.
**Critério de pronto (mecânico)**: caso novo na suíte com `MENU TO` do `std.ch` — `usages` no
sítio da DSL lista **as 3** posições do local; o `rename` a partir do sítio da DSL resolve
`rename-local` (não `rename-pp-marker`); o caso do local FABRICADO (`<n> => LOCAL <n>`) segue
resolvendo o marker, byte-idêntico; `make test` verde.

**(2) DECISÃO DE PRODUTO — do Diego, NÃO implementar antes da ordem.** Resolvido o bug, o
rename edita as 3 posições e o `.hrb` **muda de verdade**: a string derivada é outra. E ela é
**viva em runtime** — o `__MenuTo` (`src/rtl/menuto.prg`) faz `__mvPublic( cVariable )` (cria um
memvar com aquele NOME) e `ReadVar( Upper( cVariable ) )`, que qualquer bloco de `SET KEY` pode
ler. Logo **não existe rename preservador** aqui, e a reversão do verificador está **certa**.
A pergunta é: rename cuja mudança de comportamento é **derivada, prevista e exibida** (a
ferramenta já imprime `predicted string: "nEscolha" -> "nOpcao"`) é **recusa honesta** ou
**opt-in explícito**? O §1 do CLAUDE.md manda relatar e nunca editar o não-verificável — mas
isto **não é** não-verificável: a derivação é FATO do ast-12.

## Rename de DATA/VAR member — fatia 2

A fatia 1 entregou (caso 110): `rename` sobre `VAR nSaldo`/`::nSaldo` edita declaração +
getter + setter, mapeia `NOME→novo` E `_NOME→_novo`, e recusa homônimo entre classes. **Falta:
`ACCESS`/`ASSIGN` (getter/setter explícitos), DATA herdada de superclasse, e o `resolve-at` de
`::membro` escopando a classe** (rename a partir do site de USO). Spec:
[spec-rename-data.md](spec-rename-data.md).

## T — CASO DECLARATIVO: a suíte migra de `grep` em saída para FIXTURE ESPERADA *(ordem do Diego, 2026-07-24; **harness ENTREGUE, migração ABERTA**)*

**O diagnóstico, MEDIDO** (`tests/run.sh` no dia da ordem): 4.692 linhas, 123 casos,
**1.006 asserções — 637 delas (63%) são `grep -q` em texto de saída**, contra apenas 83
comparações byte a byte.

**A ordem do Diego:** *"acho que é o run que tem que melhorar. usar fixtures expected para
cada teste é a solução"* — dita duas vezes; eu tratei a primeira como observação sobre UM
teste, e era sobre a arquitetura.

**As duas cicatrizes que nasceram na mesma hora, e nenhuma era sobre a ferramenta:**
- um `grep` que passava por **VACUIDADE** — o padrão (`^verified: [^(]*$`) nunca casaria com
  a saída real (`1 edit(s)` tem parêntese), então o check era verde sem provar nada;
- a régua do caso 64 quebrando porque a fixture usava `Conta`, **português comum no fonte**.

**O limite de fundo:** `grep` prova que UM pedaço da saída existe. Ele **nunca** prova o que a
ferramenta NÃO fez ou NÃO disse — e é exatamente isso que este produto promete.

**O formato** (contrato e porquê em [tests/casedir.sh](../tests/casedir.sh)):

```
tests/cases/<nome>/
   before/     o projeto ANTES (.prg, .ch, .hbp)
   cmd         a linha do hbrefactor, SEM o binário
   after/      o projeto ESPERADO depois (byte a byte)
   exit        (opcional) exit esperado; default 0
   out         (opcional) a saída esperada (stdout+stderr), byte a byte
```

Três provas por caso, e a terceira é a que o grep nunca deu: exit, fontes byte a byte, e a
**saída INTEIRA** — aviso a mais reprova. Caso **sem `after/`** é de recusa/relato: o
`before/` inteiro tem de voltar intacto. Falha mostra **DIFF**, não *"FAIL: um grep não
casou"*.

É a generalização do que **já está provado** no `tests/site/` (as quatro portas), não um
formato inventado.

**✅ ENTREGUE (2026-07-24):** o harness (`tests/casedir.sh`, sourced pelo `run.sh`) e o
**caso 128 nascido nele** — o primeiro. Provado nos DOIS sentidos: verde no estado certo, e
**vermelho com diff** ao sabotar UMA palavra da saída esperada. `make test` 1022/0 e
**`JOBS=1` byte-idêntico** (obrigatório: a mudança tocou o runner).

**A migração dos 122 antigos fica ABERTA, por lotes.** Estimativa honesta: **~85%** cabem no
formato; o resto continua bash por natureza (o caso 122 confere schema contra o compilador,
outros medem carga de projeto, e a régua do caso 64 é sobre o FONTE DA FERRAMENTA, não sobre
o caso).

**Custo conhecido, a decidir quando a migração começar:** comparar saída byte a byte é rígido
nos dois sentidos — mexer numa mensagem quebra dezenas de casos de uma vez. É virtude (o
alcance real da mudança fica visível) e é atrito (ruído quando a mudança é deliberada). Pede
um `make test-accept` para re-baselinar — que é **faca de dois gumes** e por isso não entrou
junto com o harness: aceitar cegamente é o modo de falha que este formato existe para matar.

**Critério de pronto (mecânico) da migração**: nenhum caso migrado perde asserção (conferência
site a site do que o `grep` cobria e o `cmp` não cobre); `make test` verde e `JOBS=1`
byte-idêntico a cada lote.

## Dívidas e limites conhecidos

- **Dívida da SITE-EX:** as seções profundas da `site/index.html` (rename de DATA, genealogia
  de regra, tempo de vida de diretiva, sequestro por abreviação) ainda têm transcript **colado
  à mão** — corretos hoje, mas **FORA do portão** do `make site-check`, e portanto sujeitos ao
  apodrecimento que a fase existiu para matar. Migrá-los para `tests/site/`.
- ~~**Limite conhecido (B5.1):** dois alvos com módulos de mesmo nome-base colidiriam no
  `ReadAst`; "só afeta análise, não a posse".~~ **FECHADO por RECUSA (2026-07-13, caso 124)** —
  e a linha acima era **complacente e errada**: medido, a ferramenta não "degradava a análise",
  ela **mentia** (`MAIN -> ALFACALC [external]`, com **exit 0**, porque o dump de `subA/util.prg`
  era sobrescrito pelo de `subB/util.prg`). O guard agora vive no `LoadProject` — que já tem a
  lista canônica de fontes de TODOS os alvos —, **cobre todo verbo de uma vez**, e recusa
  nomeando os dois caminhos e o remédio.
  **A recusa é DEFINITIVA, não provisória** *(decisão do Diego, 2026-07-13)*: suportar o caso
  exigiria nome de artefato derivado do CAMINHO no harbour/hbmk2, e **isso não faz sentido —
  o alcance da ferramenta é o alcance do toolchain.** *(A conclusão da P-AUDIT — "o basename é
  único por FATO do builder" — vale só para alvo ÚNICO: lá o link falha. Um `.hbp` multi-alvo
  com workdir por alvo **builda**, e é por essa porta que a colisão entrava.)*

- > ⚠️ **RETRATAÇÃO (2026-07-13).** Escrevi aqui um "bug novo": *o `-rebuild` não desce para
  > os sub-projetos de um container, então o `LoadProject` recusa projeto bom, de forma
  > intermitente.* **NÃO REPRODUZ.** Re-sondado de forma determinística (tudo limpo →
  > pós-build → pós-build repetido), o `-rebuild` imprime as duas linhas de comando em
  > **todos** os estados. O que eu vi (*"Target up to date"*, zero comandos) aconteceu num
  > diretório **sujo de builds que haviam FALHADO** durante a própria sonda — e eu construí
  > mecanismo e manchete em cima de ruído, sem repetir o experimento no limpo. É o **§3.2 das
  > cicatrizes** de novo (*medir o que eu acho, não o que roda*), agora dentro de uma sessão
  > cujo assunto era exatamente isso. **O bug não existe até que alguém o reproduza.**

- **✅ O CANAL do `LoadProject` — CONSERTADO NO CORE (2026-07-13; suíte 990/0, ZERO drift).**
  *(Régua do Diego: **para projeto, o hbmk2 é SEMPRE a fonte de verdade** — build, onde estão
  os arquivos, includes. E o corolário, que é a regra e não a exceção: **necessidade
  identificada → o CORE passa a responder**.)*
  **O que estava errado:** a ferramenta **não perguntava** nada ao hbmk2 — ela **raspava o
  efeito colateral de um build** (`-traceonly` → a linha *"Harbour compiler command"*). Essa
  linha é montada a partir de `l_aPRG_TO_DO` (hbmk2.prg:6201): os fontes **a (re)compilar**,
  não os fontes do ALVO — em modo incremental com o alvo em dia ela **nem sai**. Daí a muleta
  do `-rebuild`, que forçava **recompilar o projeto inteiro só para descobrir de que ele é
  feito**. E ainda exigia o `CmdTokens`, uma tokenização de shell (aspas, parênteses)
  replicada na ferramenta. *Gatilho 6: o canal barato funcionava, então ninguém perguntou se
  era o correto.*
  **A varredura (§1.3), antes de estender:** `hbmk2 --help` inteiro — `--hbinfo[=nested]` dá
  JSON por alvo, mas só de **configuração de build** (`targetname`/`targettype`/`outputname`),
  **nem fontes, nem includes, nem flags**; a API de plugin já fora descartada na B5.1 (expõe
  escrita, não a lista resolvida). **O canal de consulta não existia.**
  **O core passou a responder — comando NOVO `--hbproject[=nested]`** (ordem do Diego: *"se
  mudar a saída de algum comando, crie um comando novo"* — o `--hbinfo` fica **byte-idêntico**).
  Devolve **um bloco JSON por alvo** com o conteúdo **resolvido** (`.hbp`/`.hbc`/`.hbm`, `-i`,
  `${macros}`, filtros `{...}` já expandidos): `sources` (`.prg` **e** `.hbx` — o hbmk2 os põe
  no mesmo array de entradas, hbmk2.prg:3748), `incpaths`, `prgflags`. **Responde ANTES de
  qualquer build** (`RETURN _EXIT_OK`) — a pergunta *"de que este projeto é feito?"* deixou de
  depender do estado do diretório de build, e responde **até para projeto que não compila**
  (medido no `gtwvg`).
  **Armadilha achada ao integrar:** emitir só o `aOPTPRG` **não basta** — o compilador também
  recebe `-n1`/`-n2`, os `-u+` dos headers do `.hbc`, `-j`/`-gd` e as flags de plataforma. Com
  um subconjunto, o consumidor compilaria o alvo **diferente de como o hbmk2 compila** (59
  falhas na suíte, todas nos verbos que editam-e-verificam: sem `-n2` o pcode muda). O
  `prgflags` monta agora **a lista exata que o compilador recebe**.
  **Na ferramenta:** o `LoadProject` consome o JSON; o **`CmdTokens` MORREU** (réplica a menos);
  o `-rebuild` sai da consulta. **Zero drift** — as 990 asserções, incluindo o projeto com
  `-inc`/`.hbc`/`.hbx` (caso 29), passam sem re-baseline. **Commits (core + ferramenta)
  pendentes de autorização por-commit do Diego; `NEWS.md` do core e `CHANGELOG.md` a escrever.**
- **B5 — critério vivo da extensão:** Diego usa no dia a dia; sem regressão. **Todo comando
  novo do CLI chega à `extension.js` na fase que o entrega** (regra no CLAUDE.md).

## H — HIGIENE DE DIRETÓRIOS TEMPORÁRIOS *(pista do Diego, 2026-07-14; **H.1 e H.2 ENTREGUES 2026-07-14 — suíte 990/0, sem re-baseline**)*

**O problema, medido:** a ferramenta espalha `hbrefactor_<rand>` e `hbrefactor-snap-<md5>`
**soltos** dentro de `hb_DirTemp()` (`/tmp`), sem teto comum — milhares de dirs acumulados,
limpeza só com glob perigoso. (O scratchpad do Claude Code — `/tmp/claude-*/…/` — encheu em
paralelo, 1.7 G numa sessão morta, mas isso é comportamento do harness, não da ferramenta;
entra só como alvo de medição na H.2.) **Decisão do Diego:** raiz única + aviso determinístico
sob controle dele — **nada de auto-limpeza** (ação silenciosa é o que ele recusa).

### Fase H.1 — Raiz única sob `$TMPDIR/hbrefactor/{work,snap}`

**Escopo**
- Nova `STATIC FUNCTION WorkRoot()` → `hb_DirSepAdd( hb_DirTemp() ) + "hbrefactor"`, com
  `hb_DirBuild` uma vez.
- `WorkDir()` (o chokepoint do efêmero, hoje em `src/hbrefactor.prg` ~L360) passa a criar sob
  `WorkRoot() + sep + "work" + sep + <rand>` — preservando o laço anti-colisão do `hb_RandomInt`.
- `SnapDir()` (`src/hbrefactor.prg:903`) passa a devolver `WorkRoot() + sep + "snap" + sep +
  hb_MD5( cwd + spec )`.
- **Nenhum outro site**: os subdirs (`ktwork` L9349, a sonda de regra L3056) já descendem de
  `WorkDir()`/`cTmp` — descem junto de graça.
- **Contrato preservado**: o `dump` continua imprimindo `dumps em: <path>` (`src/hbrefactor.prg:862`)
  — só o *valor* muda, e a suíte lê esse valor da stdout, não uma constante.

**Critério de pronto (mecânico)**
- `make test` verde **sem re-baseline**: a suíte é agnóstica ao valor do caminho — os casos
  capturam o path via `sed -n 's/^dumps em: //p'` (`tests/run.sh:1091,1815,2372,…`), não há
  normalizador para tocar.
- Após um `dump` + `snapshot` num projeto do corpus: `ls "${TMPDIR:-/tmp}/hbrefactor"` mostra
  **só** `work/` e `snap/`, e **zero** `hbrefactor_*`/`hbrefactor-snap-*` solto em `$TMPDIR`.
- Round-trip intacto: `snapshot` → editar quebrando o build → `verify --rollback` restaura byte
  a byte (o `SnapDir()` é o mesmo dos dois lados, então escrita e leitura continuam alinhadas).
- Sem superfície de CLI nova → **extensão não afetada** (nada a propagar para `extension.js`).

### Fase H.2 — `make tmp-usage`: aviso determinístico de limite (NUNCA apaga)

**Escopo**
- `tools/tmp-usage.sh` + target `tmp-usage` no Makefile (a família de `tools/*.sh` de ops do
  Diego; mensagens em PT, como as demais — não é superfície de produto).
- Mede `du -s` de **dois alvos, reportados em separado**: (a) `${TMPDIR:-/tmp}/hbrefactor` e
  (b) o scratchpad do Claude Code deste projeto (`/tmp/claude-*/…hbrefactor*/`).
- Limite default **500 M**, override por env `HBREFACTOR_TMP_WARN_MB`.
- Acima do limite: imprime o tamanho, a divisão `work` × `snap`, e **o comando exato de limpeza
  para colar** — distinguindo o `rm -rf …/hbrefactor/work` (sempre seguro) do
  `rm -rf …/hbrefactor` (inclui o `snap`, que é o buffer de `--rollback`: aviso no texto).
- Abaixo: uma linha `OK`. **Nunca deleta.** Exit code: `0` abaixo, `!=0` acima (composável).
- Gatilho **só manual** (`make tmp-usage`) — sem hook, sem gatilho passivo.

**Critério de pronto (mecânico)**
- Com `$TMPDIR/hbrefactor` acima de 500 M, `make tmp-usage` sai `!=0`, imprime os comandos, e
  `ls`/`git status` confirmam que **nada foi apagado**.
- Vazio ou abaixo do limite → sai `0` com a linha `OK`.
- `HBREFACTOR_TMP_WARN_MB=1 make tmp-usage` dispara o aviso (prova do override).

**Ao commitar** (fora do escopo de código, via `/update-manual`): entrada de `CHANGELOG.md` no
registro do programador — *onde a ferramenta passa a escrever seus temporários e como limpar* —,
já que o local dos `.ast.json`/snapshots muda de forma visível.

---

# PORTÕES FECHADOS / EM ESPERA

## D — Evidência de execução — **PORTÃO FECHADO NA FORMA PROPOSTA (Diego, 2026-07-08)**

A forma proposta (camada `observed` anotando sites `possible` para priorizar conferência
manual) é **TRIAGEM — e triagem não é produto** (REGRA DO FATO). A spec fica como registro
dos fatos re-auditados (o funil real é `hb_objGetMethod`, classes.c:1802):
[spec-d-evidencia-execucao.md](spec-d-evidencia-execucao.md). **Evidência de execução só
volta se tiver consumo 100% fato** (ex.: alimentar cheques impostos) — decisão do Diego.
**Canal candidato levantado depois** (o profiler do VM, `__SetProfiler`): **P15** — ele passa
por ESTE portão, não por um novo.

## B8 — Macros — **EM ESPERA (rebaixada pela M-cov, 2026-07-08)**

A M-cov achou **zero receptor por macro** no corpus e o Diego despriorizou macros. **Spec
pronta na gaveta; executa quando a fricção real pedir**:
[spec-b8-macros.md](spec-b8-macros.md) (fatias, dialética do pipe, venenos, critério de
matar). Adendo verificado: a AST de toda macro existe completa em runtime (macro.y:257; gate
único em vm/macro.c:798) — o dump de macro em runtime é o gêmeo do funil `hb_vmSend`, e viaja
com a alavanca D, não com esta fase.

## B6 — PR upstream — **BLOQUEADA (só quando o Diego mandar)**

Mensagem com consumidor real; 1 arquivo novo + ganchos opt-in; prova de zero impacto; build
limpo (corrigir o `-Wtype-limits` de compast.c:658 — tirar o `iType >= 0`); regen bison 3.8.2
documentado; split opcional em 2 PRs; ChangeLog via `bin/commit.hb`; uncrustify.

**O que NÃO vai no PR** (e é pequeno, e é **nosso**): `CLAUDE.md`, `.gitignore`, `NEWS.md`, o
banner do `README.md` e o diretório `site/` (a proposta é a EMBALAGEM do PR, não conteúdo
dele — e já vive publicada no [gh-pages do fork](https://diegopego.github.io/harbour-core/)).
Fora isso, o branch é o trabalho de AST: `compast.c` (novo), `ppcore.c` (a maior intrusão),
`hbmain.c`, `harbour.y`, `classes.c`, headers, mais os `.yyc`/`.yyh` do bison.
**A limpeza é executada só quando o Diego for abrir o PR** (ordem dele, 2026-07-12).

> ⚠️ **A CICATRIZ QUE GOVERNA ESTA FASE:** eu acusei o branch de carregar "6 commits alheios"
> — **ERRADO: são do UPSTREAM.** Comparei contra o `master` LOCAL, 7 commits atrasado. **Base
> errada → achado errado, e publicado.** Ao medir o branch, a base é **`upstream/master`**
> (`git fetch upstream` primeiro), nunca o `master` local.

**Prova de impacto zero — com SCRIPT** (`tools/pcode-identity.sh`): era medida à mão, e por
isso os números da proposta envelheceram sem ninguém notar (afirmava `1085/1085` e `112/112`,
irreproduzíveis). Medido em **2026-07-12: 889/889 módulos com pcode byte-idêntico, ZERO
divergências** (switches desligados, remendado vs `master`). A afirmação se sustenta; a
contagem é que era fantasia. **Rodar o script antes de citar — nunca a contagem de memória.**

---

# Backlog (por valor)

0. **Manutenção de doc de USUÁRIO em atraso (2026-07-12)**: o `docs/manual.md` está com
   baseline em `hbrefactor@437a6a6` — várias entregas atrás; a `site/index.html` deriva dele.
   Os DOIS CHANGELOGs estão em dia (têm ponteiro próprio); o manual não. Rodar a
   `/update-manual` em modo catch-up — **o delta do manual exige o OK do Diego antes de
   aplicar** (invariante 1 da skill). Não é bloqueante para nenhuma fase.

0b. **Higiene: o compilador deixa lixo no repo (2026-07-12)**: cada `make test` deixa um
   `sh1.c` na RAIZ (o `harbour` grava o `.c` no **CWD**, não ao lado do fonte — a mesma
   armadilha do `.d` do `-gd`). Conserto: mandar a saída para um tmp (`-o<dir>`) no site que
   roda o compilador a partir da raiz. Ecoa *"ferramenta do core: PROBE, nunca memória"*.

1. **Dedup pré/pós-decremento**: não-fazer mantido (v2).

2. **Projetos grandes de produção** (quando o Diego liberar): dogfooding final — só depois de
   suíte + hbhttpd verdes. **Recalibrado (Diego, 2026-07-10, regra no CLAUDE.md)**: antes de
   qualquer produção/bravo, a maturação acontece em corpus do CORE ampliado (copiar mais
   pastas pertinentes de `harbour-core/harbour` para `work/`); o bravo é só exploração até a
   ferramenta estar sólida no código do core.
