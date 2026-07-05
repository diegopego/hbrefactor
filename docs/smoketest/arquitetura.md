# Tarefa 3 — Decisão de arquitetura

Baseada nas evidências de [inventario-ecossistema.md](inventario-ecossistema.md) e [armadilhas-shx.md](armadilhas-shx.md). Responde à diretiva **"Premissa a QUESTIONAR"** do inventário: a inclinação inicial era "modificar o compilador em si"; abaixo ela é avaliada criticamente contra as alternativas, e a resposta não é a premissa pura.

---

## Decisão 1 — Fundação do motor de análise

### Avaliação crítica das opções

**(a) Projeto standalone consumindo saídas existentes do compilador — insuficiente sozinho, mas é o modelo certo de consumo.**

As saídas que existem hoje quase bastam — e isso foi uma surpresa do levantamento:

- Com `-gh -b`, o pcode carrega `HB_P_LOCALNAME`/`HB_P_STATICNAME` (slot→nome; `$HB_ROOT/include/hbpcode.h:102,185`, emitidos em `hbmain.c:583,3725`) e marcadores `HB_P_LINE`. Desmontando o HRB, dá para derivar as ocorrências de locais/statics (cada `PUSHLOCAL/POPLOCAL/PUSHLOCALREF n` entre dois `HB_P_LINE`) **sem tocar no compilador**.
- Porém esse caminho tem um defeito **estrutural para uma ferramenta que promete soundness**: o pcode é pós-otimização. A eliminação de código morto (`hbdead.c`) remove referências em ramos eliminados — uma ocorrência que some da desmontagem é um site de rename **silenciosamente perdido**. Também não distingue os casos que a tabela S/H/X exige distinguir (função com `HB_P_MACRO*`, campo vs memvar em contexto ambíguo já resolvido, etc.) sem reimplementar metade da semântica.
- Veredito: ótimo como **protótipo/fallback** (de-risking se o patch upstream demorar), errado como fundação definitiva. E (a) com parser próprio em vez de desmontagem é pior ainda: reimplementar escopo+pp por aproximação é exatamente o remendo que este projeto recusa.

**(b) Estender/modificar o compilador — correta, mas só na forma mínima.**

A premissa original ("modificar o compilador em si") estava certa pela metade:

- **Certa**: o compilador é o único componente que resolve escopo e pré-processador de verdade, e o ponto de enxerto é um só (`hb_compVariableFind()`, `hbmain.c:685`) mais os geradores de chamada. O **gravador de ocorrências** (flag novo → acumula símbolo/escopo/função/arquivo/linha → dump JSON no fim) segue o precedente interno do compi18n, roda **durante o parse — antes da eliminação de código morto**, não muda gramática nem pcode, e é pequeno e aditivo: perfil ideal de PR upstream.
- **Errada se levada além disso**: construir o motor de refatoração *dentro* do compilador acoplaria a ferramenta ao ciclo de release do harbour-core (lento e conservador), inflaria o PR a ponto de inviabilizá-lo, e poria lógica de edição de texto onde ela não pertence. O compilador deve **informar**, não **editar**.
- Risco real a administrar: até o merge upstream, a ferramenta depende de um Harbour com o patch (o branch já criado no harbour-core). Mitigações: o patch é aditivo (zero impacto sem o flag); o fallback (a) via `-gh -b` cobre o essencial se necessário; o formato do dump nasce versionado.

**(c) Escrita parcialmente no próprio Harbour — sim, e não é opcional por gosto.**

Não é alternativa às outras: é a dimensão "linguagem". A evidência do inventário torna Harbour a escolha natural para a ferramenta: `hb_compileFromBuf()` (verificação em memória), biblioteca do pp e lexer (`__pp_*`, colunas), `hb_hrbLoad` (auto-teste), JSON no core. Bônus não técnico: a ferramenta vira vitrine da própria linguagem e dogfooding — ela poderá refatorar o próprio código.

### Decisão

**Híbrido (a)+(b)+(c), com papéis estritos:**

- **hbrefactor** (repo próprio, escrito em Harbour) é o produto: análise textual, aplicação de edições, confirmações, verificação.
- O **harbour-core** recebe apenas o gravador de ocorrências (branch → PR upstream), consumido pelo hbrefactor como oráculo.
- Reuso conforme a régua da diretiva: biblioteca do pp **sim** (é a base certa para tokenização/coluna); flags existentes **sim** (`-p` para diagnóstico, `-gh -l` para verificação, `-gh -b` como fallback); hbpp binário **não** (nada exclusivo); hbformat **não** como fundação (só formatador pós-edição, opcional).

## Decisão 2 — Forma de entrega

| Opção | Prós | Contras |
|---|---|---|
| (A) CLI standalone | Testável, scriptável, agnóstica de editor, mínima | UX no VSCode limitada a tasks/terminal |
| (B) Extensão VSCode + LSP completo | F2, preview, code actions nativos | Maior investimento inicial; LSP inteiro (parsing incremental, sync de documentos) antes de existir valor; arrisca acoplar o motor ao editor |
| (C) Núcleo CLI/biblioteca + extensão VSCode fina | Núcleo testável fora do editor; extensão só orquestra; evolui para (B) sem retrabalho | Duas peças para versionar |

**Decisão: (C), começando só pelo CLI.** As fases 0–1 entregam o CLI (`hbrefactor rename ...`) com saída JSON no formato do **`WorkspaceEdit` do LSP** desde o primeiro dia — esse contrato é a ponte: a extensão fina (fase 2+) só traduz comando→CLI→`workspace.applyEdit`, e um eventual servidor LSP futuro reusa o mesmo núcleo e o mesmo formato. O modo interativo de confirmação (casos H da tabela S/H/X) nasce no CLI (lista de sites com aceitar/recusar) e vira UI de preview na extensão.

## Arquitetura resultante (visão de blocos)

```
┌─ VSCode (extensão fina, fase 2+) ─┐
│   comando → CLI → applyEdit       │
└───────────────┬───────────────────┘
                │ JSON (LSP WorkspaceEdit + relatório S/H/X)
┌───────────────▼───────────────────┐      ┌─ harbour-core (branch → PR) ─┐
│ hbrefactor (Harbour, repo próprio)│      │ gravador de ocorrências      │
│  - orquestração e política S/H/X  │◄─────┤ (flag novo no compilador:    │
│  - lexer pp: coluna no fonte      │ dump │  símbolo, escopo, função,    │
│  - varredura de strings/dumps C   │ JSON │  arquivo, linha)             │
│  - editor de texto + confirmações │      └──────────────────────────────┘
│  - verificação: hb_compileFromBuf │
│    / harbour -gh -l + cmp         │
└───────────────────────────────────┘
```

## Requisito de escala: projetos multi-arquivo definidos por `.hbp`/`.hbc`

Projetos Harbour reais podem ser grandes: dezenas ou centenas de `.prg`, headers `.ch` compartilhados, e a composição do projeto definida por arquivos `.hbp` (fontes, flags, dependências) e `.hbc` (configuração de libs/include paths, referenciados pelo `.hbp`). A ferramenta **deve operar no nível do projeto**, não do arquivo isolado:

- **Descoberta do conjunto de arquivos**: o `.hbp` (e os `.hbc` que ele referencia) é a fonte de verdade de quais `.prg` fazem parte do projeto — a mesma semântica que o hbmk2 usa. Um rename de símbolo público percorre *todos* os fontes do projeto, e o relatório S/H/X é consolidado por projeto.
- **Include paths**: os `-i`/`incpaths` de `.hbp`/`.hbc` alimentam o replay do pré-processador (biblioteca do pp) e as chamadas de verificação (`harbour -I...`) — sem eles, `#include`/`#define` do projeto não resolvem e a análise fica errada.
- **Headers `.ch`**: renomear um símbolo definido em `.ch` compartilhado (constante `#define`, `#command`) afeta todos os `.prg` que o incluem — o grafo de inclusão faz parte da análise (caso H da S/H/X §4).
- **Escala**: o pipeline (dump de ocorrências por arquivo + verificação `-gh -l` por arquivo) é paralelizável e incremental por natureza — só os arquivos tocados precisam re-verificar byte a byte; o build completo fica para a confirmação final.

## Riscos em aberto

1. **Aceitação upstream do patch** — mitigada pelo perfil (aditivo, pequeno, precedente compi18n) e pelo fallback `-gh -b`; até lá, o branch local basta para o desenvolvimento.
2. **Formato do dump** — versionar desde o início (`"schema": 1`); é a interface entre os dois repos.
3. **Arquivos com BEGINDUMP** — verificação exige build completo (não só `-gh -l`); o CLI precisa detectar e trocar de estratégia de verificação por arquivo (já mapeado na S/H/X §5).
4. **Projetos sem `.hbp`/`.hbc`** — o caminho principal é ler o `.hbp` (e `.hbc` referenciados); para projetos fora desse padrão, alternativa por lista explícita/glob antes da fase multi-arquivo.
5. **Fidelidade ao parsing do hbmk2** — `.hbp`/`.hbc` têm sintaxe própria (macros, plataformas condicionais); a leitura deve cobrir o subconjunto comum e, em caso de dúvida, delegar ao próprio hbmk2 (`-trace`/`--hbmake`?) ou pedir lista explícita — verificar na Fase 1 qual mecanismo o hbmk2 expõe para enumerar fontes resolvidos.
