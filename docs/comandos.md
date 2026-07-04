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

## Candidatos (aceitos em princípio, sem fase definida)

| Comando | Base já existente | Risco |
|---|---|---|
| `rename-static-var` | dump já traz `scope: static` + filewide | S |
| `rename-define` (símbolo de `#define`/`#command`) | replay com biblioteca do pp | H |
| `inline-local` (substituir var de uso único pela expressão) | `used` no dump | S/H |
| `unused-locals` (relatório de locais nunca lidas) | `iUsed`/access no dump | leitura |
| `call-graph` (quem chama quem no projeto) | `calls` do dump | leitura |
| `find-dynamic-calls` (relatório de `Do("...")`/macros para auditoria) | varredura de strings + `usesMacro` | leitura |

## Integração VSCode (Fase 2+ da entrega)

Todos os comandos de escrita emitem `--json` no formato **LSP WorkspaceEdit**;
`usages` ganhará `--json` no formato `Location[]`. A extensão fina traduz:
F2 → `rename-*`, Shift+F12 → `usages`, code action → `extract-function`.
