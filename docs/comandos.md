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
- Colisões recusadas: nome novo já definido/referenciado no projeto, regra
  de pp, reservada.
- **Verificação estrutural de HRB** (leitor mínimo do formato de
  `src/vm/runner.c`): tabela de símbolos igual exceto as entradas
  renomeadas (scope/tipo preservados), **pcode byte-idêntico**, módulos não
  tocados byte-idênticos; rollback automático. Idempotência A→B→A coberta
  por teste.

## Planejados (ordem do [roadmap](roadmap.md))

### `rename-param <hbp> <arquivo> <função> <velho> <novo>` — Fase 2 (curto)
Parâmetro é local: o motor da Fase 0 já cobre; falta apenas fixture dedicada
e mensagem específica. **S**.

### `reorder-params <hbp> <função> <nova-ordem>` — Fase 2
Reordena parâmetros atualizando todos os call sites (via `calls` do dump +
parsing da lista de argumentos com balanceamento). **H** nos casos: chamada
com menos argumentos (NIL implícito muda de posição), `PCount()` no corpo,
`hb_ExecFromArray`/`Do()` com array. Critério: testes de comportamento
(o pcode muda legitimamente).

### `extract-function <hbp> <arquivo> <linhas> <nome>` — Fase 3
Extrai seleção para `STATIC FUNCTION` nova; parâmetros/retorno inferidos das
ocorrências por linha do dump (variáveis usadas dentro × fora da seleção).
Recusas: `RETURN`/`EXIT`/`LOOP` cruzando a borda, `PRIVATE` criada dentro e
usada fora, macro na seleção sem confirmação.

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
