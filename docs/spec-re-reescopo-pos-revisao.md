# Fase RE — Re-escopo pós-revisão externa (plano vinculante)

Status: **FASE ATIVA — PRIORIDADE 1 (portão aberto pelo Diego,
2026-07-09: seguir o plano da revisão e documentá-lo para garantir a
execução).** Este documento É o plano; o roadmap aponta para cá.

**Como este plano se impõe** (mecanismo, não intenção):

1. Cada item RE.n tem critério de pronto EXECUTÁVEL; item fecha só com
   a evidência colada aqui (mesma sessão — regra do CLAUDE.md).
2. **Guarda de fase**: enquanto RE.1-RE.4 não fecharem, nenhum trabalho
   novo sobre B7/B7b, `guaranteed`, ClassGraph/dispatch ou fatia 2 da
   B9 (materialização) fora dos itens desta fase. Quem retomar a sessão
   começa por AQUI (o roadmap manda para cá no topo das ativas).
3. Decisões de produto embutidas ficam marcadas como **[PORTÃO Diego]**
   — o item não executa sem elas.

## Origem — as três rodadas da revisão externa (registro)

Instrumento (réguas R1/R2 do dono, glossário, delimitação do objeto):
[revisao-codex-zero-inferencia.md](revisao-codex-zero-inferencia.md).
Rodadas via Codex CLI em 2026-07-09, estado revisado: harbour-core
`c1927dfcac` (delta `master..HEAD`, 12 commits/16 arquivos — só o
delta está em julgamento), hbrefactor `6584aa8`/`590a4a5`:

| Rodada | Modelo | O que leu | Entrega |
|---|---|---|---|
| 1 — forma | gpt-5.4-mini | o instrumento + conferência pontual dos trechos citados | 6 achados de forma — aplicados no commit `590a4a5` |
| 2 — mérito | gpt-5.5 | leituras dirigidas pelas Q1-Q5 (amostral) | vereditos Q1-Q5 |
| 3 — auditoria | gpt-5.5 | o delta do harbour + as regiões críticas da ferramenta | achados A1-A5 (abaixo) + veredito por área |

Honestidade de escopo: nenhuma rodada leu 100% do experimento
(estimativa: 20-30% nas rodadas 1-2; a rodada 3 cobriu o delta do core
por inteiro e a ferramenta por amostragem dirigida). O peso do veredito
é de ARQUITETURA com evidência pontual de código, não de auditoria
linha a linha; a suíte não foi executada pelo revisor (sandbox
somente-leitura).

## O veredito convergente

As rodadas 2 e 3 convergem ENTRE SI e com o julgamento interno
registrado em 2026-07-08 (pendência 3 da sessão — "manter renames
verificados + usages honesto; a linha semântica não compensa no teto
medido"):

- **Manter como estão**: dump `-x` (factual, gating correto),
  rastreamento de PP (a parte mais aderente a R2), renames/extract/
  reorder verificados por recompilação, `usages` factual.
- **`-kt` é R1-legítimo** (é "estender o core para o fato existir"),
  mas fatia 1 + consumo OVERCLAIMAM: `guaranteed` sai para sites que o
  cheque não cobre (A1/A2).
- **B7/B7b são inferência nos termos de R1** — rótulo honesto não
  salva como produto; rebaixar para SUGERIDORA/materializadora de
  anotações (o destino que o CLAUDE.md já previa).
- **Veredito de viabilidade (Q5)**: "a linha atual, como produto
  amplo, não compensa. Re-escopada, compensa." Produto mínimo
  defensável: dump factual + PP genérico + refatorações verificadas +
  `guaranteed` real por `-kt`.

## Achados da auditoria (rodada 3) — verificar no fonte ANTES de agir

Disciplina do repo: achado externo é HIPÓTESE até confirmação com
arquivo:linha (e probe executável quando couber). Status vive aqui.

- **A1 — `guaranteed` falso para símbolos que `-kt` não checa.**
  Alegação: o core só emite prólogo para parâmetros de assinatura
  (harbour.y:331) e pós-atribuição só para `HB_VS_LOCAL_VAR`
  (hbmain.c:2873); ficam fora `PARAMETERS`, parâmetros de codeblock e
  escrita em local detached dentro de bloco — mas `B7KtMark`
  (hbrefactor.prg:6409) marca QUALQUER anotação de módulo `kt` e o
  veredito sai `guaranteed` (hbrefactor.prg:7709). Quebra R1.
  Status: **CONFIRMADO (RE.1, 2026-07-09)** — probes executáveis em
  scratchpad/re1 (probe_re1.prg, probe2.prg, probe3.prg), protocolo da
  suíte (`-w3 -es2 -kt`, build hbmk2 `-prgflag=-kt`, execução):
  - Core emite cheque SÓ em (a) prólogo de parâmetro de assinatura —
    harbour.y:332/334 são os ÚNICOS call sites de
    `hb_compChkTypeParams` (grep no delta) — e (b) pós-store direto em
    local de função nomeada — hbmain.c:2871-2875 exige
    `HB_VS_LOCAL_VAR` E `functions.pLast->szName`.
  - probe_re1 (execução): controle A0 dispara (`declared type check
    failed: expected N, got C @ MAIN:NGUARD`); param de bloco anotado,
    escrita em local dentro de bloco e `PARAMETERS x AS` deixam kind
    errado passar EM SILÊNCIO. No pcode (`-gc2`) o módulo inteiro tem
    UMA chamada `__HB_CHKTYPE` (o controle).
  - **Gap EXTRA não alegado pela auditoria**: escrita por `@ref` em
    local anotado também não é checada (probe3: o pop acontece no
    parâmetro do callee, sem a anotação do caller — `local virou C`).
  - Consumidor overclaima DE FATO: probe2 (local anotado cuja única
    escrita vive num codeblock) sai no usages como `guaranteed send
    (receiver AS CLASS CONTA imposed by -kt checks)` ENQUANTO a
    execução prova receptor PEDRA (`Message not found
    (PEDRA:CREDITA)`). A premissa "toda escrita é checada" do caso 87
    (multi-write) é FALSA quando há escrita em bloco ou por @ref.
  - Alcance REAL do overclaim hoje (fatos que escopam o RE.2): só o
    LOCAL anotado atinge `guaranteed` indevido (escrita em bloco e/ou
    @ref). Param de bloco `AS CLASS` NUNCA vira guaranteed — a
    gramática descarta o nome da classe nesse caminho (harbour.y:1024
    repassa só `cVarType`; o dump carrega `type:'S'` sem `class` e
    DeclType degrada a NIL, hbrefactor.prg:5936). `PARAMETERS` não
    vira guaranteed — occurrence com scope memvar barra antes
    (hbrefactor.prg:5995). Mas `B7KtMark` (6409) segue keyed à FLAG DE
    MÓDULO, não à cobertura do site — o conserto é o RE.2.
- **A2 — `PARAMETERS x AS ...` está no canal e não é imposto.**
  Alegação: gramática aceita via `MemvarList` (harbour.y:1113 +
  AsType:1229); `hb_compChkTypeParams()` não passa por esse caminho.
  Status: **CONFIRMADO (RE.1, 2026-07-09)** — gramática aceita
  (`PARAMETERS` → `MemvarList` com `AsType`, harbour.y:1113/1229);
  `hb_compChkTypeParams` só roda na regra de assinatura
  (harbour.y:332/334) e o pós-store de memvar gera `POPMEMVAR` sem
  cheque (hbmain.c:2904). A anotação ENTRA no canal: o dump do probe
  traz `COMPARAMS {sym:'NQUANTO', scope:'private', param:true,
  type:'N'}` em módulo `kt:true`; em execução o kind errado passa em
  silêncio (probe_re1: `A2 PARAMETERS: NAO checou`). O consumidor
  atual NÃO overclaima aqui (gate memvar, hbrefactor.prg:5995) — o
  furo é de CONTRATO do canal: anotação não imposta viaja num módulo
  marcado `kt`; entra na matriz de cobertura do RE.2/RE.5.
- **A3 — B7/B7b são inferência** (uniões: hbrefactor.prg:6500/7213/
  6690/6993). Status: **ACEITO SEM VERIFICAÇÃO ADICIONAL** — é o que a
  própria documentação diz; a consequência é o RE.3.
- **A4 — a ferramenta é class-keyed onde o core é genérico**
  (ClassGraph:7509, dispatch:7553, síntese `METHOD ... CLASS`:2777).
  Status: **ACEITO COM CONTEXTO** — a síntese hbclass é exclusiva da
  forma hbclass por portão (Q7 da revisão de generalidade); o resto é
  objeto do RE.3/RE.6.
- **A5 — `pPosTbl` não é limpo em `hb_pp_reset()`** (ppcore.c:6665;
  só no destrutor, ppcore.c:2909) — risco de proveniência fantasma
  entre módulos por reuso de ponteiro com mesmo `value/len`.
  Status: **CONFIRMADO estruturalmente (RE.1, 2026-07-09)** —
  `hb_pp_reset()` (ppcore.c:6665) limpa regras, tracking e a tabela de
  DERIVAÇÃO (`hb_pp_drvTblFree`), mas não toca `pPosTbl`; o único free
  é no destrutor `hb_pp_stateFree` (ppcore.c:2909-2912). O reset roda
  POR MÓDULO no loop de compilação (hbmain.c:4403) e o guard de
  identidade de `hb_pp_posFind` compara só ponteiro `value` + `len`
  (ppcore.c:598) — o próprio comentário do código admite o reuso de
  ponteiro; entre módulos a entrada velha sobrevive e um token
  reciclado com mesmo `value/len` herdaria posição do módulo anterior.
  Probe determinístico não cabe (depende do allocator reciclar os DOIS
  ponteiros); a confirmação estrutural basta e o RE.4 (limpar no
  reset) fica justificado. Nota: `pDrvTbl` tem o MESMO guard
  (ppcore.c:694) mas É limpo no reset — o furo é só do `pPosTbl`.
- **A6 (NOVO, achado pelos probes do RE.1) — segfault do COMPILADOR
  com `AS CLASS` em parâmetro de codeblock quando o módulo conhece
  classes.** Repro mínimo (scratchpad/re1/mini2.prg): `CREATE CLASS
  Conta` + `{| oX AS CLASS Conta | ... }` no mesmo módulo → SIGSEGV
  (exit 139). Mecanismo: o caminho de bloco só repassa a LETRA do tipo
  (harbour.y:1024, `hb_compExprCBVarAdd` recebe `cVarType` e descarta
  `szFromClass`); `hb_compVariableAdd` então chama
  `hb_compClassFind( NULL )` (hbmain.c:476) e o
  `strcmp( pClass->szName, NULL )` (hbmain.c:1083) estoura quando a
  lista de classes NÃO está vazia. **Bug do upstream** (o harbour de
  estoque em `/usr/local/bin` crasha igual sob `-w3`); o delta AMPLIA
  a exposição porque `-x`/`-kt` mantêm a lista de classes viva em
  qualquer nível de warning (mini2 com `-kt` ou `-x` sem `-w3` também
  crasha; sem classe no módulo não crasha, mas W0025 imprime
  `Class '(null)'` e degrada o tipo para 'O'). Consequências: (a)
  fixture de RE.2/RE.5 com param de bloco `AS CLASS` + classe no
  módulo derruba o compilador — desviar; (b) conserto no core é
  candidato natural a intercalar com o RE.4 **[PORTÃO Diego]**.
  Status: **CONFIRMADO com repro executável**.

## O plano (ordem de execução; critérios executáveis)

**RE.1 — Verificar A1, A2 e A5 no fonte. — FECHADO (2026-07-09)**
Critério: cada um confirmado ou refutado com arquivo:linha e, para
A1/A2, probe executável (fixture `-kt` com `PARAMETERS x AS`,
parâmetro de bloco anotado e escrita em detached — o cheque dispara ou
não dispara?); refutado = registrar aqui e fechar. Resultado atualiza
o status acima na mesma sessão.
Resultado: A1, A2 e A5 **CONFIRMADOS** (evidência arquivo:linha e
saída dos probes coladas nos status acima; probes em scratchpad/re1,
harbour-core `c1927dfcac`). A verificação produziu dois fatos ALÉM da
alegação: o gap de `@ref` (quarta lacuna de cobertura do `-kt`) e o
A6 (segfault upstream com `AS CLASS` em param de bloco). Matriz de
cobertura REAL da fatia 1 (insumo direto do RE.2):

| Site com anotação | Cheque emitido? | `guaranteed` hoje? |
|---|---|---|
| parâmetro de assinatura | SIM (prólogo, harbour.y:332/334) | sim — correto |
| local, escrita direta no corpo | SIM (pós-store, hbmain.c:2871-2875) | sim — correto |
| local, escrita dentro de bloco | NÃO | **sim — overclaim (probe2)** |
| local, escrita via `@ref` | NÃO (probe3) | **sim — overclaim (sem gate de refs)** |
| parâmetro de codeblock | NÃO | não (dump perde a classe; val-kinds não usam kt) |
| `PARAMETERS x AS` | NÃO | não (gate memvar) — furo é do canal, não do usages |

**RE.2 — `guaranteed` honesto (consumidor; curto prazo). — FECHADO
(2026-07-09)**
Escopo: restringir a marca `kt` (`B7KtMark`) aos sites que o `-kt` da
fatia 1 COBRE de fato (conforme RE.1): parâmetro de assinatura e local
anotado com escrita coberta; anotação não coberta degrada para o canal
`declared` (a promessa continua, sem o selo de invariante).
Critério: casos de suíte novos (fixkt estendido) provando que
`PARAMETERS AS`/param de bloco/detached **não** saem `guaranteed`;
caso 87 intacto nos sites cobertos; suíte verde byte-idêntica
paralelo × JOBS=1.
Resultado: `B7KtCovered` (hbrefactor.prg) implementa a matriz do RE.1
sobre fatos do dump — a marca `kt` exige AUSÊNCIA de occurrence
`access:"ref"` e de `access:"write"` com `block:true` para o símbolo;
o site de param de bloco perdeu a marca (o binding do Eval não é
checado). Prova: fixkt estendido com t3.prg (4 sites não cobertos) e
caso 88 — escrita só em codeblock e escrita via `@ref` saem
`confirmed send (receiver declared AS CLASS CONTA)` SEM selo;
`PARAMETERS AS` sai `possible` (gate memvar); param de bloco anotado
sai `excluded ... codeblock` pelo canal declared; t1.prg:72
(multi-write DIRETO) e t2.prg:17 (assinatura) seguem `guaranteed`
(caso 87 intacto, asserts inalterados). Suíte 622/0, saída
byte-idêntica paralelo × JOBS=1 (cmp). Nota de fato: caso de suíte
para param de bloco `AS CLASS` é INESCREVÍVEL hoje — classe no módulo
segfaulta o compilador (A6) e classe fora do módulo cai em W0025 +
`-es2`; coberto com value-kind.

**RE.3 — B7/B7b fora do veredito de produto. — FECHADO (2026-07-09)**
Escopo: `confirmed`/`excluded` derivados de inferência (cadeia de
construção, união de call sites/retornos/Evals, ClassGraph "as
written") deixam de ser veredito de produto; a máquina vira camada
SUGERIDORA — insumo do comando de materialização (fatia 2 da B9), não
resposta do `usages`.
**[PORTÃO Diego — ABERTO 2026-07-09]**: forma **(a)** — some do
`usages` e só existe no materializador; decisão adicional do mesmo
portão: o `possible` NOMEADO por inferência ("one of X or Y", "may
dispatch through written parents", sufixos "via construction chain")
some junto — degrade pleno.
Critério: nenhum `confirmed`/`excluded` do `usages` de produto deriva
de B7/B7b/ClassGraph (prova: casos 84/85/86 re-baselined para o novo
contrato); M-cov re-rodada (`tests/mcov2.sh`) e o retrato honesto
pós-rebaixamento registrado no limites-e-alavancas.md; suíte verde.
Resultado: o `usages` não constrói `hInter` (a máquina B7/B7b fica
DORMENTE no fonte, entrada `B7Ctx` — o W0034 do build é o marcador
honesto até a fatia 2 consumi-la); `SendVerdict` reescrito só-fato,
com defesa de contrato (tipo com traço `via`/`clsset` degrada para
possible) e SEM o bloco de dispatch por grafo (helpers
`ResolveDispatchMsg`/`DispatchHijackers`/`ClassDescendants`
removidos); sites de DECLARAÇÃO seguem decidindo por members (fato do
canal declarado — "homônimos por declaração" do "O que NÃO muda").
Alcance REAL foi além dos casos 84/85/86: os vereditos por grafo
as-written (B4f-2/Q4) também derivam de ClassGraph e saíram — casos
39/61/63/66/67/68/69/72/75 re-baselinados. **Consequência de produto
notável: o furo dos homônimos (caso 66, o caso original do Diego)
degradou nos SENDS** — a exclusão exigia mundo fechado sobre parents
as-written; declarações homônimas seguem excluded. Retrato M-cov 3
(limites-e-alavancas.md): confirmed 1.715→545 (8,7%, 100% canal
declarado), 1.170 sites degradados para possible pleno. `--json`:
possible pós-RE.3 entra nas Location[] (Json66/Json72 re-baselinados).
Specs B7/B7b e ast-schema §TypeOf com banner de rebaixamento. Suíte
622/0 byte-idêntica paralelo × JOBS=1.
Adendo (decisão do Diego, mesma data): as EXPECTATIVAS dos testes
re-baselinados ficam SUSPENSAS, não mortas — catálogo versionado em
[testes-suspensos-re3.md](testes-suspensos-re3.md) com o rótulo antigo
verbatim e a rota de FATO de cada site (materializador+kt / RE.5 /
RE.6; re-ligar inferência NÃO é rota). Os itens [FATIA-2] do catálogo
são semente do critério de aceite da fatia 2 da B9.

**RE.4 — Hardening `pPosTbl` (core; independente, pode intercalar). —
FECHADO (2026-07-09; harbour-core `ef0abe3688`, autorizado)**
Escopo: limpar `pPosTbl` em `hb_pp_reset()` (se A5 confirmar).
Critério: zero impacto sem `-x` (byte-idêntico, protocolo padrão);
`make lexdiff` limpo; suíte 616+/0. Commit no harbour-core só com
autorização do Diego.
Resultado: `hb_pp_posTblFree()` no estilo do `hb_pp_drvTblFree`,
chamado em `hb_pp_reset()` (junto das tabelas de tracking/derivação) e
no destrutor (que perdeu o free inline). Provas: 460/460 `.hrb`
byte-idênticos base × fix (corpus work/tests, 230 programas × `-w0` e
`-w3`, sem `-x`, relink forçado dos DOIS binários); `make lexdiff`
0 divergências reais; suíte 622/0 byte-idêntica paralelo × JOBS=1.

**RE.5 — [GAVETA — PORTÃO Diego] cobertura completa do `-kt`.**
Estender a emissão no core (`PARAMETERS`, params de bloco, detached)
E/OU matriz explícita "o que é imposto" no dump. RE.2 remove a
urgência (o consumidor para de overclaimar); esta fatia devolve
alcance. Abrir só com escopo+critério escritos, depois de RE.1-RE.3.
**EXECUTADO (2026-07-10; portão aberto pelo Diego, K1-K4):
[spec-re5-cobertura-kt.md](spec-re5-cobertura-kt.md)** — A6 morto,
prólogo de bloco, pós-store detached, fato `chk` no dump (ast-8) com
`B7KtCovered` leitor; K5 medido (zero receptores-objeto → FORA com
registro), K6 FORA. Caso 88 = matriz por FATO; suíte 700/0.

**RE.6 — [PORTÃO DE ESCOPO ABERTO pelo Diego, 2026-07-10; rota A
escolhida; spec em RASCUNHO no portão de EXECUÇÃO] contratos genéricos
de diretiva.** A resposta de Q3 da revisão: invariantes genéricas por
construto de diretiva (papéis de marker, relações owner/member/
generated-symbol no dump), sem "classe" como modelo universal. A perna
concreta é o parentesco: **[spec-re6-parentesco-declarado.md](spec-re6-parentesco-declarado.md)**
— `_HB_SUPER` (parentesco DECLARADO como fato do core, irmão de
`_HB_CLASS`/`_HB_MEMBER`; hbclass primeiro cliente) reconquista a
exclusão de SEND da Rota C do
[testes-suspensos-re3.md](testes-suspensos-re3.md) (furo dos homônimos,
caso 66) sobre arestas de FATO, degrade honesto, rótulo novo. Decisões
D1-D6 aguardam o portão de execução do Diego.

## O que NÃO muda nesta fase

Dump `-x` e rastreamento de PP (vereditos "manter"); renames/extract/
reorder verificados; camadas `confirmed`/`excluded` por FATO
não-inferido (tipo declarado do próprio símbolo, homônimos por
declaração, exclusão por conjunto nomeado); o contrato de degradar
honesto. A fatia 1 da B9 fica commitada como está — RE.2 corrige o
CONSUMO dela, não o core (RE.5 é que mexeria no core, sob portão).
