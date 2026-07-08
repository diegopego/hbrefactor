# Suíte de testes paralela — design (forma, requisitos, tecnologia)

Documento de design da Fase B-infra (ver [roadmap.md](roadmap.md)). Aqui fica o
racional completo — a análise das *formas* de paralelizar e das tecnologias que as
implementam. A spec executável (escopo + critério de pronto) vive no roadmap.

> **Etapa 1 ✅ ENTREGUE (2026-07-07)** — pool bash no próprio `run.sh`
> (R1-R7 todos atendidos; registro completo no
> [arquivo de fases](roadmap-fases-entregues.md)). Números medidos:
> sequencial 109 s → paralelo 11-14 s em 20 cores (**~8×**), saída
> byte-idêntica nos dois modos, 10/10 rodadas sem flake. Nota: quando
> escrito, este doc citava ~34 casos/125 checks; na entrega a suíte tinha
> 80 unidades/555 checks — a forma escolhida escalou sem ajuste. A
> Etapa 2 (runner em Harbour via `hb_processOpen`) segue como futuro.

## Contexto

`tests/run.sh` roda **~34 casos / 125 checks** estritamente em sequência. O custo é
dominado por invocações do compilador (`harbour`/`hbmk2`) que cada caso dispara para
gerar o `.ast.json` e verificar; os casos **14/16/31** ainda compilam+linkam+**executam**
dois binários cada (as pontas longas). A máquina tem **20 cores** ociosos → paralelizar
corta o wall-time.

Dois fatos do código moldam a forma (não são opinião):

1. `fresh()` ([../tests/run.sh](../tests/run.sh)) já dá a **cada caso um diretório
   próprio** `tests/tmp/caseN` — isolamento de fontes por caso **já existe**.
2. A ferramenta grava o scratch da AST em `hb_DirTemp() + "hbrefactor_" + timestamp` com
   **resolução de 1 s, sem PID/aleatório** ([../src/hbrefactor.prg](../src/hbrefactor.prg),
   `WorkDir()`). Duas invocações no mesmo segundo caem no **mesmo diretório e se
   sobrescrevem**. **Nenhuma forma paralela é sequer _correta_ enquanto esse scratch não
   for isolado** — vale para qualquer tecnologia.

## Forma escolhida

> **Pool dinâmico de processos, grão por-caso, teto ~`nproc`, cada caso com working dir _e_
> scratch isolados, resultado por artefato com tally no join.**

Justificativa por eixo (o único com juízo real é o B; os demais decorrem de fatos):

- **A · Granularidade → por-caso.** Fronteira de isolamento já existe. Mais fino
  (por-invocação/por-assert) esbarra em dependências intra-caso (A→B→A, `rename`→`usages`).
  Mais grosso (buckets) só ajudaria se partida de processo dominasse — o compilador domina.
- **B · Escalonamento → pool dinâmico, teto ~`nproc`.** Durações heterogêneas (14/16/31 são
  as longas) tornam a partição estática desbalanceada; a fila dinâmica auto-balanceia e dá o
  melhor wall-time.
- **C · Mecanismo → processo.** Thread só ganha com memória compartilhada (inexistente aqui);
  distribuído/socket é escala errada para uma caixa de 20 cores.
- **D · Isolamento → porta de corretude.** Fontes já isoladas; scratch da ferramenta **não**.
- **E · Agregação → artefato por caso + tally no join.** Contador em memória não sobrevive à
  fronteira de processo; artefato por caso ainda mata a intercalação de saída.

## Requisitos

Alteração de código autorizada onde for necessária para habilitar o paralelismo.

- **R1 — Isolar o scratch da ferramenta (código).** Corrigir `WorkDir()`
  ([../src/hbrefactor.prg](../src/hbrefactor.prg)) para nome **único** (PID +
  contador/aleatório, não só timestamp de 1 s). Protege também qualquer uso concorrente real
  (editor/LSP disparando invocações). Pré-requisito absoluto.
- **R2 — `TMPDIR` por caso (harness).** O runner exporta `TMPDIR=tests/tmp/caseN` para cada
  caso (`hb_DirTemp()` respeita `TMPDIR`). Cinto-e-suspensório com R1; sozinho já isola a
  suíte mesmo sem R1, mas R1 é a correção robusta.
- **R3 — Grão por-caso, cada caso auto-contido.** Reestruturar `run.sh` para que cada caso
  seja uma unidade invocável isoladamente (função/rotina), sem depender de estado global.
- **R4 — Pool dinâmico com teto.** Teto configurável, default ~`nproc`; workers puxam o
  próximo caso ao liberar. Teto é _knob_ de tuning (oversubscription é branda: cada caso é
  serial internamente).
- **R5 — Resultado por artefato + tally no join.** Cada caso grava exit code + saída
  capturada num artefato próprio (elimina a intercalação); o join soma pass/fail. Some com
  os contadores globais `PASS`/`FAIL` do `run.sh`.
- **R6 — Paridade de semântica.** O conjunto pass/fail paralelo deve ser **idêntico** ao
  sequencial. Preservar os números/mensagens dos casos que a suíte já checa.
- **R7 — `make test` continua a porta de entrada.** Paralelo é o modo padrão; `JOBS=1` força
  sequencial para depurar um caso.

## Tecnologia — prós e contras

A forma acima é agnóstica; falta apenas **qual tecnologia** a implementa. O campo colapsa em
**três viáveis** — as outras estão dominadas (ver ao fim). Todas implementam a *mesma* forma
(pool dinâmico por-caso); diferem em dependência, esforço/risco e ergonomia.

### Opção 1 — Bash pool (`xargs -P` / `wait -n`)
- **Prós**: **zero dependência nova** (findutils sempre presente) → máxima portabilidade;
  **drift ~zero** — mantém os 125 asserts como estão, só embrulha cada caso numa função e
  troca o despacho; **menor esforço** e menor risco para um projeto que já funciona; headless
  em CI.
- **Contras**: você **coda à mão** a agregação (arquivos de resultado + tally) e o `TMPDIR`
  por caso; **relatório de falha cru** (grep/diff), sem introspecção de assert; é retrofit.

### Opção 2 — pytest + pytest-xdist
- **Prós**: `-n auto` usa os 20 cores e entrega **agregação, isolamento e saída-limpa de
  graça**; **melhor diagnóstico de falha**; `tmp_path` + `monkeypatch.setenv("TMPDIR")`
  isolam por teste; JUnit XML para CI; Python **já é dependência** da suíte hoje (casos 18/26
  + `occ_ast_diff.py`).
- **Contras**: **reescrever os 125 asserts** em Python → **risco de drift** (mitigável
  rodando as duas suítes até baterem); **mantém/centraliza o Python** — dependência
  estrangeira num projeto de identidade toolchain-Harbour; os diferenciais do pytest rendem
  menos aqui, onde cada caso é "spawn um binário e grep a saída".

### Opção 3 — Harbour `hb_processOpen` (dogfooding)
- **Prós**: **toolchain única** — depende só do Harbour que você já precisa para buildar a
  ferramenta, e ainda **remove o Python** (via `hb_jsonDecode` nos casos 18/26); paralelismo
  **trivial e verificado** — `hb_processOpen` (em `src/rtl/hbprocfn.c` do harbour-core) já dá
  spawn assíncrono + **um pipe por caso** + PID + exit; o scheduler é um laço de ~40 linhas
  (não é framework do zero); **dogfooding real** para uma ferramenta de refatoração Harbour.
- **Contras**: **reescrever os 125 asserts** em `.prg` → mesmo **risco de drift** da Opção 2;
  **relatório de falha você constrói** — modesto para asserts exit-code+grep+filecmp, mas é
  código a escrever; menos gente lê um harness Harbour bespoke do que bash/pytest.

### Comparação rápida

| Critério | Bash pool | pytest+xdist | Harbour pool |
|---|---|---|---|
| Dependência nova | nenhuma ✓✓ | pytest/xdist via pip ~ | nenhuma; remove Python ✓✓✓ |
| Esforço / risco de drift | baixo / ~zero ✓✓ | alto / médio ~ | alto / médio ~ |
| Paralelismo pronto | teto sim; resto na mão ~ | tudo de graça ✓✓ | spawn+pipe+exit nativos; tally você faz ✓ |
| Diagnóstico de falha | cru ~ | o melhor ✓✓ | você constrói ~ |
| Dogfood / self-contained | ✓ | ~ | ✓✓✓ |
| CI headless | ✓✓ | ✓✓ | ✓✓ |

**Dominadas (não recomendadas), com o porquê**: GNU parallel (= bash pool + `--joblog`, mas
vira dependência dura); `make -j` (perde o tally granular, verboso); bats-core (o `--jobs`
usa GNU parallel por baixo — não escapa da dep — e é reescrita comparável); `prove`/TAP
(dep Perl + emitir TAP); Harbour com threads `-mt`, C embarcado ou sockets (nenhum vence o
`hb_processOpen` e cada um custa build/portabilidade/escala-errada); tmux (não é scheduler,
quebra headless).

## Decisão — caminho em duas etapas (menor arrependimento)

- **Etapa 1 — Bash pool agora.** Entrega o paralelismo já, com drift ~zero (mantém os 125
  asserts) e zero dependência nova, e força a correção do `WorkDir` (R1), que beneficia
  qualquer destino.
- **Etapa 2 — Migrar para Harbour pool depois.** Quando o roadmap reescrever o `run.sh`,
  migra o runner para `hb_processOpen` (toolchain única + dogfood + remoção do Python), sem
  mudar a *forma* — só a tecnologia que a implementa.

A Etapa 2 herda toda a forma e requisitos da Etapa 1; a paridade (R6) e a ausência de
flakiness protegem a migração byte-a-byte.

## Verificação (end-to-end)

1. **Baseline**: cronometrar `make test` sequencial atual → wall-time de referência.
2. **Corretude/paridade**: rodar a forma paralela e `diff` do pass/fail por caso contra o
   sequencial — exigir igualdade.
3. **Sem flakiness**: rodar a suíte paralela 10× seguidas sem falha intermitente.
4. **Ganho**: comparar wall-time paralelo vs baseline.
