# Fase 4 — Dogfooding (relatório vivo)

## Rodada 1: a ferramenta sobre si mesma (2026-07-04)

Projeto: `hbrefactor.hbp` (o próprio fonte, ~2.300 linhas em 1 módulo).

### Relatórios read-only

| Comando | Resultado | Observação |
|---|---|---|
| `usages ... TokenScan` | 12 resultados (1 definição + 11 chamadas) em **0,12s** | performance ok para fonte grande |
| `unused-locals` | 0 findings | esperado: o fonte compila `-w3 -es2` limpo |
| `call-graph ... TokenScan` | todos os chamadores corretos | — |
| `find-dynamic-calls` | 1 finding: string `"usages"` casa com a função `USAGES` | **falso positivo por design** — é o nome do subcomando CLI, não chamada dinâmica; confirma que o relatório é para julgamento humano |

### Fricção real encontrada (e corrigida): statements continuados por `;`

`rename-local ... RenameFunction hHit aHit` **recusava** com "line 370 is
rewritten by the preprocessor". Diagnóstico com evidência (`cont.prg` de
laboratório): num statement continuado, o oráculo e o `.ppo` apontam a
**última linha física** (o `currLine` do codegen), mas os tokens estão nas
linhas anteriores — o pp-check via a linha final "diferente" do ppo (que ali
está vazio) e recusava. A rede de segurança funcionou (recusa, não edição
errada), mas recusar todo statement multi-linha seria inviável em código real.

**Correção**: `StmtEdits()` — resolve a linha do oráculo para o statement
inteiro (anda para trás enquanto a linha anterior termina em `;`), junta o
texto limpo, compara com o ppo da linha final e coleta os tokens de todas as
linhas físicas. Compartilhado por `rename-local`, `rename-function` e
`rename-static`; a varredura fora-do-oráculo do `rename-function` também
ficou continuation-aware (`LineCovered`). Regressão: caso 24 (token na linha
do meio da continuação, verificação byte-idêntica).

### Auto-refatoração aplicada (a ferramenta editando o próprio fonte)

`hHit` (prefixo húngaro de hash) iterava **arrays** de hits/edições em quatro
funções — renomeado para `aHit` pela própria ferramenta, com verificação
byte-idêntica em cada uma: `RenameLocal`, `ReorderParams`, `RenameStatic` e —
após a correção acima — `RenameFunction` (que era exatamente o caso
continuado). Suíte 85/85 verde com o fonte auto-editado.

### Pendências desta rodada

- `reorder-params` mantém a recusa para chamadas multi-linha (o
  `ParseParenSpan` é por linha) — avaliar extensão para statements
  continuados se o uso real pedir.
- **Rodada 2 (pendente): projeto de produção do Diego** — precisa que ele
  aponte um `.hbp`/diretório; começar pelos relatórios read-only, depois um
  rename real. Critério de pronto da Fase 4 depende desta rodada.
