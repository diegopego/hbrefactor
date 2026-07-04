# Tarefa 4 — Roadmap incremental com critérios de pronto

> **Status (2026-07-04): Fases 0, 1 e 2 CONCLUÍDAS — `make test` 49/49 verde**
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
