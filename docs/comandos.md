# Catálogo de comandos do hbrefactor

Superfície da ferramenta: o que existe, o que vem, e a classificação de risco
de cada operação segundo a [tabela S/H/X](armadilhas-shx.md). Regra geral:
operações **de leitura** não exigem verificação; operações **de escrita** só
se completam se a verificação mecânica passar (`-gh -l` byte-idêntico quando a
transformação não deve mudar pcode; build completo + testes nas demais), com
rollback automático em caso de falha.

## Implementados

### `rename-local <hbp> <arquivo> <função> <velho> <novo>` — Fase 0 ✅
Rename de variável `LOCAL` (inclui parâmetros e capturas *detached* em
codeblock). Território **S**. Verificação: `.hrb` de **todos** os módulos do
projeto byte-idêntico + rollback. Opções: `--dry-run`, `--json <out>`
(LSP WorkspaceEdit). Recusas: colisão com declaração existente, palavra
reservada, colisão com regra de pp, sombreamento por parâmetro de bloco
homônimo, linha onde o símbolo é consumido/gerado por regra de pp.

### `usages <hbp> <nome> [--func <função>]` — ✅
"Encontrar todos os usos" de **variável ou função** no projeto inteiro
(read-only, sem risco). Lista, com a linha de código como contexto:
- **definition** — função/procedure com esse nome (com `static`/`kind`);
- **declaration** — declarações de variável (escopo, se é parâmetro);
- **read/write/ref/use** — cada referência de variável com escopo resolvido
  (incl. `detached`/codeblock);
- **call** — cada chamada de função/DO/referência de símbolo de função.

Fonte de verdade: dump `-x` de todos os módulos (patch v2 gravou `calls` via
`hb_compGenPushFunCall`/`hb_compGenPushSymbol`). Limitações herdadas do dump:
`Eval()` e sends de método são otimizados como mensagem (não aparecem como
call — v3); usos do nome **em strings** (`Do("F")`, macros) não aparecem — na
Fase 1 o `usages` ganha uma seção "possíveis referências textuais" via
varredura de literais.

### `rename-function <hbp> <velho> <novo> [--file <f>] [--force]` — Fase 1 ✅
Rename de `FUNCTION`/`PROCEDURE`/`STATIC FUNCTION` em todos os módulos do
projeto. Implementado:
- **STATIC** (S): edição restrita ao módulo definidor (inalcançável por nome
  fora dele — testado); `--file` desambigua statics homônimas.
- **Pública** (S+H): definição e chamadas vêm do oráculo (`calls` do dump);
  referências **textuais** — strings contendo o nome, `HB_FUNC(NOME)` em
  BEGINDUMP, tokens fora do oráculo (`REQUEST`, `EXTERNAL`, homônimos) — são
  listadas como warnings e **nunca editadas**; sem `--force` a operação é
  recusada.

**Política de strings (decisão de projeto, 2026-07-04)**: strings são
*dados* — seu significado não é verificável por recompilação, então a
ferramenta **nunca as edita**, nem por opt-in (uma flag "renomeie strings
iguais ao nome" foi considerada e rejeitada como remendo: adivinharia
intenção e exigiria enfraquecer o comparador de pcode). O que a ferramenta
faz é **relatar com precisão** para a decisão humana: warning distinto para
string **exatamente igual** ao nome ("likely a call by name" — `Do()`,
tabelas de dispatch) vs. string que apenas **contém** o nome (rótulo,
mensagem); e o `usages` lista os matches exatos como "possible reference in
string".
- Colisões recusadas: nome novo já definido/referenciado no projeto, regra
  de pp, reservada.
- **Verificação estrutural de HRB** (leitor mínimo do formato de
  `src/vm/runner.c`): tabela de símbolos igual exceto as entradas
  renomeadas (scope/tipo preservados), **pcode byte-idêntico**, módulos não
  tocados byte-idênticos; rollback automático. Idempotência A→B→A coberta
  por teste.

### `rename-param <hbp> <arquivo> <função> <velho> <novo>` — Fase 2 ✅
Parâmetro é local: mesmo motor (e mesmas garantias byte-idênticas) da Fase 0,
com validação de que o alvo é de fato parâmetro. **S**.

### `reorder-params <hbp> <função> <nome1,nome2,...> [--file] [--force]` — Fase 2 ✅
Reordena os parâmetros declarados e permuta os argumentos de **todos** os
call sites compilados (parser de lista com balanceamento de
parênteses/colchetes/chaves e strings). Implementado:
- **Recusa** (sem override): call site com aridade ≠ nº de parâmetros
  ("implicit NIL would move"), chamada multi-linha (continuação `;`),
  variádicas; nova ordem deve ser permutação exata dos nomes declarados.
- **`--force`** só para strings contendo o nome (nunca editadas).
- Nota: `PCount()` no corpo **não** é risco em reorder puro — a quantidade
  passada em cada site não muda.
- Verificação: recompila tudo; tabela de símbolos e conjunto de funções
  imutáveis (o pcode muda legitimamente — ordem de push); módulos não
  tocados byte-idênticos; rollback automático. O critério de comportamento
  (saída do programa idêntica) é exercido na suíte (caso 14).

### `extract-function <hbp> <arquivo> <ini>-<fim> <nome>` — Fase 3 ✅
Extrai um intervalo de statements completos para `STATIC FUNCTION`/`PROCEDURE`
nova no fim do módulo, substituindo a seleção pela chamada. Implementado:
- **Data flow pelo oráculo**: ocorrências por linha (read/write/ref) decidem
  parâmetros (grafia original recuperada do fonte), variável de saída
  (≤1 modificada-e-usada-depois → `RETURN`; write-first vira LOCAL da nova
  função) e locais que se movem com o código.
- **Estrutura pelo `.ppo`**: balanceador de IF/ENDIF, DO WHILE/ENDDO,
  FOR/NEXT, DO CASE/ENDCASE, SWITCH, BEGIN SEQUENCE/END sobre o texto
  pós-pp (imune a `#command` que expande para controle), com pilha tipada e
  `END` genérico.
- **Recusas**: estrutura aberta cruzando a borda; `RETURN`; `EXIT`/`LOOP`/
  `BREAK` que saltariam para fora; `ELSE`/`CASE`/`RECOVER` órfãos; seleção
  cortando statement continuado por `;`; macro `&` na seleção; `PRIVATE`/
  `PUBLIC`/`PARAMETERS`/`FIELD` declarados dentro; >1 variável de saída;
  local declarada dentro e usada depois.
- **Verificação**: recompila tudo; módulo editado deve preservar todos os
  símbolos/funções (por nome) + exatamente a nova função; demais módulos
  byte-idênticos; rollback automático. Comportamento provado na suíte
  (caso 16: saída do programa idêntica).

## Planejados (ordem do [roadmap](roadmap.md))

### `unused-locals <hbp>` — ✅
Relatório de locais nunca usadas (`W0003`) e atribuídas-mas-nunca-lidas
(`W0032`), **delegado ao próprio compilador** (`harbour -w3 -s` por módulo).
Nota de arquitetura: o dump `-x` não enxerga locais nunca usadas — o
otimizador as elimina antes do save; os warnings são emitidos antes e são
exatamente o relatório desejado. Reuso da análise do oráculo, não
reimplementação.

### `call-graph <hbp> [<função>]` — ✅
Quem chama quem, a partir dos `calls` do dump: arestas únicas
`arquivo: CHAMADOR -> CHAMADO [módulo-onde-definido | external]`; com
argumento, filtra para chamadores+chamados da função. Mesmas cegueiras
documentadas do `calls` (Eval/sends de método).

### `rename-static <hbp> <arquivo> <velho> <novo> [--func]` — ✅
Rename de variável `STATIC`, de função ou **file-wide** (a declaração
file-wide vive na pseudo-função `fileDecl` do dump; as ocorrências carregam
`filewide: true`). Território **S**: statics são invisíveis ao macro e seus
nomes não existem no pcode — verificação **byte-idêntica** em todos os
módulos, como na Fase 0. Recusa conservadora: nome novo já declarado em
qualquer escopo do módulo. Fato aprendido no fixture: `STATIC` file-wide
precisa vir antes de qualquer código executável do módulo (E0004).

### `find-dynamic-calls <hbp>` — ✅
Auditoria dos pontos cegos: strings cujo conteúdo é identificador **e**
coincide com função do projeto (possível `Do()`/dispatch por nome, com o
módulo onde a função vive) + funções que usam macro `&` (nomes dinâmicos
possíveis). É o mapa de onde os renames de função merecem revisão humana.

## Candidatos (aceitos em princípio, sem fase definida)

| Comando | Base já existente | Risco |
|---|---|---|
| `rename-define` (símbolo de `#define`/`#command`) | replay com biblioteca do pp | H |
| `inline-local` (substituir var de uso único pela expressão) | `used` no dump | S/H |

## Integração VSCode — ✅ ([vscode/](../vscode/))

Extensão **fina** implementada (`vscode/extension.js`, sem build step): coleta
argumentos (palavra sob o cursor, função acima do cursor, seleção), invoca o
CLI e mostra resultados — **quem aplica, verifica e faz rollback é sempre o
CLI**. Comandos: Usages (painel de referências nativo via `usages --json` em
`Location[]`), Rename local/param, Rename function (oferece `--force` após
mostrar os avisos de referências textuais), Reorder parameters, Extract
selection. Configuração: `hbrefactor.binPath`, `hbrefactor.hbBin` (HB_BIN),
`hbrefactor.project`. Instalação e atalhos: [vscode/README.md](../vscode/README.md).
