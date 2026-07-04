# Tarefa 4 — Roadmap incremental com critérios de pronto

> **Status (2026-07-04): Fases 0-3 CONCLUÍDAS — `make test` 58/58 verde.**
> Fase 3 (`extract-function` v1) fechou o roadmap original: data flow pelo
> dump, estrutura pelo `.ppo`, recusas conservadoras, verificação com
> rollback. A régua da arquitetura foi respeitada sem novo patch: a estrutura
> não foi "adivinhada" do fonte — foi lida do texto pós-pp, que é o que o
> compilador vê. Se os limites v1 (uma saída, sem EXIT para fora, etc.)
> apertarem no uso real, o próximo degrau é o dump estrutural (v3).
> Status anterior:
> (Fase 2: `rename-param` e `reorder-params` com recusa de aridade menor e
> prova de comportamento idêntico por execução no caso 14.)
> Status anterior:
> (`rename-local`, `usages`, `rename-function` com comparador estrutural de
> HRB, política H de strings com `--force`, statics por módulo, idempotência).
> Pendências da Fase 1 anotadas: `.hbx`/`DYNAMIC` não varridos; sends de
> método e `Eval` não aparecem em `calls` (v3 do dump).
> Pipeline completo funcionando: dump `-x` → linhas do oráculo → tokenizer
> (coluna) → checagem pp por contagem de tokens (linha reescrita é aceita
> somente se o identificador passou intacto pela regra) → edição → verificação
> `-gh -l` byte-idêntica por módulo com **rollback automático** (provado no
> caso 7: símbolo consumido por marker de stringify muda o pcode → restaura
> byte-exato). Fixtures são mini-projetos de 2 `.prg` + `.ch` + `.hbp`.
> Pendências anotadas: warning para referências textuais fora do oráculo
> (strings/stringify não renomeados), lexer do pp no lugar do tokenizer
> próprio (v2), fixture de parâmetro renomeado.

Fases do hbrefactor, cada uma com escopo, entregáveis e **critério de "pronto" mecânico** (verificável por comando, não por opinião). Fundamenta-se em [inventario-ecossistema.md](inventario-ecossistema.md), [armadilhas-shx.md](armadilhas-shx.md) e [arquitetura.md](arquitetura.md).

Regra transversal (da memória do projeto): fluxos definidos vivem em **Makefile** no repo hbrefactor (testes, fixtures, verificação); hbmk2 direto é só experimentação.

---

## Roadmap v2 — Fases 4-9 (planejado em 2026-07-04)

Responsável pela ferramenta: Claude (planejamento, implementação, verificação);
decisões de produto e autorizações (commits sensíveis, PR upstream): Diego.
Regra de manutenção: **este documento é vivo** — toda fase concluída ganha
status aqui, e nenhuma fase começa sem escopo e critério de pronto escritos.

### Fase 4 — Dogfooding em projeto real (EM ANDAMENTO)

> **Status 2026-07-04**: rodada 1 (a ferramenta sobre si mesma) concluída —
> ver [dogfooding.md](dogfooding.md). Fricção real encontrada e corrigida:
> renames em statements continuados por `;` recusavam (`StmtEdits` resolve o
> statement inteiro; caso 24). Auto-refatoração aplicada: `hHit`→`aHit` em 4
> funções, verificação byte-idêntica. `make test` 85/85. **Pendente: rodada 2
> num projeto de produção — aguarda o Diego apontar o projeto.**

**Por que primeiro**: todas as decisões restantes (o que dói, o que falta,
quais recusas são conservadoras demais) devem vir de fricção real, não de
especulação — a régua do projeto desde o inventário. Os fixtures provam
correção; só uso real prova utilidade.

**Escopo**: usar a ferramenta num projeto Harbour real do Diego (e no próprio
hbrefactor via `.hbp` dele — a ferramenta refatorando a si mesma): `usages`,
`unused-locals`, `call-graph`, `find-dynamic-calls` primeiro (leitura, sem
risco), depois renames reais com verificação.
**Entregáveis**: relatório de fricções (docs/dogfooding.md); correções de
robustez que surgirem (projetos grandes, includes complexos, `.hbp` com
flags/macros — ex.: o `-w3`/`-es2` que o Diego já pôs no fixture);
ajuste de recusas que se mostrarem falso-positivas.
**Critério de pronto**: ≥1 rename e ≥1 relatório executados num projeto de
produção com verificação verde, e as fricções encontradas viram itens das
fases seguintes ou correções feitas.

### Fase 5 — Completar a cobertura do oráculo ✅ (2026-07-04)

- (a) ✅ variáveis com alias no dump: `M->`/`MEMVAR->` → `memvar`,
  `FIELD->`/`alias->` → `field`, hooks em `GenPush/PopAliasedVar` (caso 25).
- (b) **decidido não-fazer**: dedup das duplicatas de pré/pós-decremento no
  compilador exigiria contexto que o `hb_compVariableFind` não tem; o
  consumidor já trata a lista por linha como conjunto e o `StmtEdits` renomeia
  por token — as duplicatas não têm efeito prático. Reabrir só se o uso real
  mostrar dano (ex.: contagens erradas no `usages` incomodarem).
- (c) ✅ coluna real no `usages --json` (caso 26).
- (d) ✅ `.hbx`/`DYNAMIC` no `rename-function` (entradas `-hbx=`/`.hbx` do
  `.hbp`; caso 27); `REQUEST`/`EXTERNAL` em fonte já eram cobertos pela
  varredura fora-do-oráculo.
- (e) ✅ projeto como lista de `.prg` sem `.hbp` (caso 28).
- Fricção da rodada 1 incorporada: `StmtEdits` para statements continuados.
Critério cumprido: casos 24-28; schema inalterado (2 — sem campo novo);
`.hrb` sem `-x` byte-idêntico re-verificado.

### Fase 6 — `rename-define` (o rename que falta)

**Escopo**: renomear símbolo de `#define`/`#[x]command`/`#[x]translate` do
projeto (`.ch` compartilhado incluso): usos encontrados por replay com a
biblioteca do pp (`__pp_AddRule`/`__pp_Process`), abreviação dBase de
`#command` tratada com conservadorismo (H).
**Critério forte disponível**: rename consistente (regra + usos) produz
expansão idêntica → `.ppo` normalizado e `.hrb` **byte-idênticos** — mesmo
padrão-ouro da Fase 0.

### Fase 7 — `inline-local`

**Escopo**: substituir local de atribuição única pela expressão (dual do
extract): S quando a expressão é pura e usada uma vez; H/recusa com chamadas
de função (ordem de efeitos) — dados do dump (`used`, access) + ppo.
**Critério**: fixtures de comportamento (execução idêntica) + recusas.

### Fase 8 — Extensão madura

**Escopo**: conforme fricção da Fase 4 — keybindings padrão (F2/Shift+F12),
preview de edições (`--dry-run --json` → diff virtual), code action para
extract na seleção, empacotamento `.vsix`.
**Critério**: Diego usa no dia a dia sem abrir terminal para os fluxos comuns.

### Fase 9 — Upstream do `-x` (bloqueada: só quando o Diego mandar)

Checklist pronto: ChangeLog via `bin/commit.hb`; `uncrustify -c
bin/harbour.ucf` (instalar uncrustify); avisar no PR que `harbour.yyc/yyh`
foram regenerados com bison 3.8.2 (upstream: 3.0.2) e oferecer regen pelos
mantenedores; texto do PR com evidências do inventário e o hbrefactor como
consumidor real.

---

## Backlog detalhado (itens das fases acima, consolidado em 2026-07-04)

**Patch `-x` no harbour-core (dump v3)** — melhorias no oráculo:
1. `PRIVATE x := init` / `PUBLIC`: declaração e escrita inicial não aparecem (caminho RTVAR não instrumentado) — pré-requisito para qualquer comando sobre memvars.
2. Variáveis com alias (`FIELD->x`, `M->x`) — caminho `GenPushAliasedVar`.
3. Sends de método e `Eval` em `calls` (hoje otimizados como mensagem, invisíveis) — melhora `usages`/`call-graph` e habilita rename de método no futuro.
4. Dedup das duplicatas de pré/pós-decremento em fallback (cosmético; consumidor já trata por linha).

**Ferramenta (hbrefactor)**:
5. `rename-function`: varrer `.hbx`/`DYNAMIC`/`REQUEST`/`EXTERNAL` e (opcional) arquivos de projeto além dos `.prg`.
6. `extract-function`: permitir `EXIT`/`LOOP` quando o loop inteiro está dentro da seleção (hoje já permitido) e `RETURN` quando a seleção é o rabo da função (hoje recusado — avaliar).
7. Lexer do pp (`hb_pp_lexNew`) no lugar do tokenizer próprio, expondo-o ao .prg (exigiria patch pequeno no core: wrapper `__pp_lex*`) — elimina divergências residuais de tokenização.
8. `usages --json` com coluna real (via tokenizer) em vez de character 0.
9. Projetos sem `.hbp` (lista explícita/glob) e fidelidade ao parsing do hbmk2 (macros/plataformas em `.hbp`/`.hbc`).

**Candidatos do catálogo** (ver [comandos.md](comandos.md)): `rename-static-var` (S, quase pronto), `rename-define` (H, replay via biblioteca pp), `inline-local` (S/H), `find-dynamic-calls` (leitura).

**Extensão VSCode**: refinamentos conforme uso real (keybindings padrão, preview via `--dry-run --json`, code actions).

**Upstream**: PR do `-x` para o harbour-core — **adiado por decisão do Diego**; quando for a hora: entrada no ChangeLog via `bin/commit.hb`, formatação `uncrustify -c bin/harbour.ucf` (uncrustify não está instalado nesta máquina), texto do PR com as evidências do inventário.

---

## Fase 0 — Smoke test: rename de `LOCAL` em uma função

**Por que esta fase**: opera 100% em território **S** da tabela S/H/X (macro não enxerga LOCAL — testado; escopo resolvido com exatidão pelo compilador). O sucesso ou fracasso mede o *pipeline*, não heurísticas.

**Escopo**: `hbrefactor rename --local <projeto.hbp> <arquivo> <função> <nome-antigo> <nome-novo>`. A transformação em si é local a uma função, mas **a unidade de operação é o projeto desde o dia zero**: requisito firme — os fixtures são mini-projetos `.hbp` com **no mínimo dois `.prg`** (e um `.ch` compartilhado), nunca um arquivo solto. É isso que prova que a ferramenta lida com as complexidades de projeto (descoberta via `.hbp`, include paths, dump por módulo, verificação por módulo) e não apenas com refatoração de arquivo único. Cobre parâmetros (são locais) e locais capturadas por codeblock (*detached*).

**Entregáveis**:
1. **Patch v1 no harbour-core** (branch existente): gravador de ocorrências — flag novo que, durante o parse, acumula `{símbolo, escopo resolvido, função contêiner, arquivo, linha}` para variáveis e despeja JSON (`"schema": 1`). Enxerto em `hb_compVariableFind()` + geradores; molde do compi18n.
2. **Núcleo hbrefactor** (Harbour): lê o dump; localiza a coluna re-tokenizando a linha original com o lexer do pp (`spaces + len`); aplica edição textual; recusa com mensagem clara os casos fora do escopo da fase (linha transformada pelo pp → detectada via diff `.prg`×`.ppo`; função contendo `HB_P_MACRO*` → aviso, prossegue pois LOCAL é S).
3. **Suíte de fixtures** (Makefile: `make test`): shadowing (mesmo nome em funções distintas), parâmetro, captura em codeblock, homônimo FIELD/MEMVAR declarado, nome novo colidindo com reservada (`nIL`!) ou com local existente → recusa.

**Critério de pronto (o mais forte de todas as fases)**: nomes de locais **não existem no pcode** sem `-b` — portanto `harbour -gh -l` de **cada módulo do projeto** deve ser **byte-idêntico** (`cmp`) antes/depois. Cada fixture (mini-projeto ≥2 `.prg` + `.ch` + `.hbp`) exige: (a) texto de saída esperado exato no arquivo tocado; (b) `.hrb` de **todos** os módulos idênticos byte a byte — o que prova também que a ferramenta **não tocou** os arquivos que não devia; (c) o projeto inteiro compila via `.hbp` sem warning novo (`-w3`).

## Fase 1 — Rename de função/procedure em projeto multi-arquivo

**Escopo**: rename de `FUNCTION`/`PROCEDURE` (públicas e `STATIC`) em projeto definido por `.hbp`/`.hbc` (requisito de escala da arquitetura). Primeira fronteira **H**: nomes em strings.

**Entregáveis**:
1. **Patch v2**: dump estende a chamadas/declarações de funções e métodos (o schema v1 já nasce com esses campos previstos).
2. Leitura de `.hbp` + `.hbc` referenciados (fontes, incpaths, defines); investigar aqui o mecanismo do hbmk2 para enumerar fontes resolvidos (risco 5 da arquitetura).
3. Mecanismo de **confirmação** no CLI (nasce aqui, vale para tudo que é H): varredura de literais string case-insensitive, `HB_FUNC(NOME)`/`HB_FUNC_EXTERN` em blocos BEGINDUMP, `.hbx`/`DYNAMIC`/`REQUEST`; lista de sites aceitar/recusar; saída JSON WorkspaceEdit + relatório S/H/X.
4. `STATIC FUNCTION` tratada como S (inalcançável por macro/`Do()` — testado).

**Critério de pronto**: nomes de função **aparecem** na tabela de símbolos do `.hrb` — o critério vira comparação estrutural: `.hrb` de cada arquivo idêntico byte a byte **exceto** as entradas de símbolo esperadas (comparador de HRB faz parte da entrega); build completo do projeto-fixture via Makefile passa; rename A→B seguido de B→A restaura os fontes byte a byte (idempotência); fixtures H exigem que *sem* confirmação nada seja tocado.

## Fase 2 — Reordenar/renomear parâmetros com atualização de call sites

**Escopo**: renomear parâmetro (= Fase 0, é local) e **reordenar** parâmetros atualizando todos os call sites do projeto.

**Entregáveis**: parsing da lista de argumentos no call site (lexer do pp + balanceamento de parênteses — sem regex); política explícita para: chamadas com menos argumentos que parâmetros (NIL implícito — reordenar pode **mudar semântica** → H, confirmação com preview por site), `PCount()`/`hb_PCount` no corpo (H: a função inspeciona aridade), `hb_ExecFromArray`/`Do()` com array de args (H), chamada via macro (recusa/confirmação).

**Critério de pronto**: aqui o `.hrb` **legitimamente muda** (ordem de push de argumentos) — o critério migra para: fixtures com **testes de comportamento** (executar antes/depois via `hbmk2` + comparar saída), build completo limpo, idempotência da transformação inversa, e relatório obrigatório dos sites H com decisão registrada.

## Fase 3 — Extração de função + interação profunda com o pp

**Escopo**: extrair seleção para `STATIC FUNCTION` nova; inferência de parâmetros/retorno a partir das locais usadas dentro/fora da seleção (o dump por linha dá exatamente isso); tratamento dos casos pp da S/H/X §4 (rename de símbolo de `#define`/`#command` com replay via biblioteca do pp).

**Recusas explícitas** (X nesta fase): seleção contendo `RETURN`/`EXIT`/`LOOP` que atravessa a borda, `PRIVATE` criada na seleção e usada fora, macro `&` dentro da seleção sem confirmação.

**Critério de pronto**: build completo + fixtures de comportamento (como Fase 2) + caso-teste canônico: extrair, compilar, saída do programa idêntica; o texto extraído re-formatado com `hbformat` sem divergência adicional.

---

## Incremental vs. construir tudo de uma vez — resposta

**Começar pela Fase 0. A investigação reforçou essa inclinação em vez de enfraquecê-la**, por quatro razões técnicas:

1. **A fundação ficou barata — logo não há o que "construir de uma vez".** O que a Tarefa 1 revelou (pp linkável com lexer pronto, compilador como biblioteca testado, `-gh -l` como verificador) elimina justamente os componentes caros que justificariam um big-bang (parser próprio, motor de verificação). O que resta de difícil não é infraestrutura: são as **heurísticas H** — e heurística se ganha caso a caso, com fixtures, não de uma vez.
2. **A Fase 0 valida a interface entre os dois repos com o menor patch possível.** O contrato dump-JSON é a peça arriscada da arquitetura (risco 2). Prová-lo com um consumidor real e um patch mínimo maximiza a chance do PR upstream — um patch grande "para todas as fases" sem consumidor é o perfil que o core recusa.
3. **O critério de pronto da Fase 0 é o mais forte que existirá** (byte-idêntico): se o pipeline inteiro — dump → coluna via lexer → edição → recompilação → `cmp` — passa nesse padrão, os elos estão provados antes de entrarmos em território onde o critério é necessariamente mais fraco (Fases 2-3).
4. **Refatoração errada é pior que nenhuma** (princípio inegociável do plano): o custo de um big-bang não é só desperdício — é entregar casos H mal calibrados junto com os S, minando a confiança na ferramenta no primeiro erro silencioso.

**Concessão ao "pensar grande"** (o que se projeta agora, mesmo implementando depois): o **schema do dump** já nasce com os campos das Fases 1-2 (funções, métodos, chamadas) para o patch do compilador não churnar a cada fase — mudar o patch upstream é caro; mudar o hbrefactor é barato. Idem o formato WorkspaceEdit, estável desde o dia 1.

---

## Sequência imediata (Fase 0 destrinchada)

1. Desenhar o schema JSON do dump (v1 com campos reservados p/ Fase 1) — documento curto neste repo.
2. Patch v1 no branch do harbour-core + rebuild do compilador (`make` no core, conforme fluxo do projeto).
3. Núcleo hbrefactor mínimo (dump → plano de edição → aplicar) + Makefile com `make test`.
4. Fixtures da Fase 0 verdes com o critério byte-idêntico.
5. Só então: decisão de submeter o PR upstream (com autorização explícita para qualquer commit).
