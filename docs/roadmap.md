# Roadmap — hbrefactor sobre AST do compilador (v3 enxuto, 2026-07-07)

Responsável pela ferramenta: Claude (planejamento, implementação,
verificação); decisões de produto e autorizações (commits, PR upstream):
Diego. Regra de manutenção: **este documento é vivo** — fase futura só
começa com escopo e critério de pronto escritos; fase concluída ganha UMA
linha no índice de entregues e o registro completo vai para o arquivo.
Fluxos definidos vivem em **Makefile**; hbmk2 direto é só experimentação.

Histórico: [roadmap-v2-arquivado.md](roadmap-v2-arquivado.md) (smoke
test), **[roadmap-fases-entregues.md](roadmap-fases-entregues.md)**
(narrativa integral das fases B0-B4f-3, congelada na limpeza de
2026-07-07). Mapa permanente do alcançável:
[limites-e-alavancas.md](limites-e-alavancas.md).

> **bravo-experimento: FORA DO ESCOPO (ordem do Diego, 2026-07-05).**
> Corpus de validação: fixtures da suíte + work/hbhttpd. Projetos grandes
> de produção só quando o Diego liberar.

## O NORTE (ordem do Diego, 2026-07-07 — regra durável no CLAUDE.md)

O Harbour inteiro se apoia em diretivas de pp para criar açúcar sintático.
O hbrefactor refatora **QUALQUER construto criado por diretiva** — do
core ou inventado pelo programador no próprio aplicativo — sem ajuste
por-caso. **Classes/hbclass são SÓ UM CASO**, jamais o alvo do desenho.
Fato faltante → fato de compilação ou relato honesto; ajeito é
inaceitável. Régua executável: casos 64 e 72-74.

**AVISO (Diego, 2026-07-07)**: commits das eras B4e/B4f-2/extensão foram
feitos com enquadramento hbclass-cêntrico — há código, specs e testes a
revisar. O instrumento é
**[revisao-generalidade.md](revisao-generalidade.md)** (achados V1-V7
verificados + checklist Q1-Q7 executável). É a frente prioritária.

## Fundação (provada no smoke test + B0/B1; não re-derivar)

Compilador como oráculo (ganchos de 1 linha gated, `.hrb` byte-idêntico
sem `-x`); editor ≠ verificador (recompilar, comparar, rollback); hbmk2
como resolvedor de projeto; fixtures como contrato de comportamento;
réplica sintática na ferramenta é proibida (a fonte da verdade é o
compilador). Dump por módulo `.ast.json` (schema atual **ast-4**), specs
de consumo em [ast-schema.md](ast-schema.md) — LER antes de mexer.

## Fases entregues (registro completo no [arquivo](roadmap-fases-entregues.md))

| Fase | Entrega (1 linha) |
|------|-------------------|
| B0+B1 (2026-07-05) | Mecanismo `-x` no core + fundação da ferramenta; lexdiff 0 divergências reais; occ↔ast paridade total |
| B2 (2026-07-05) | 11 comandos re-assentados na AST (renames, extract, reorder, usages `--json`); run.sh novo |
| B3 (2026-07-05) | reorder multi-linha; `inline-local` com pureza pela árvore do compilador |
| B4 (2026-07-06) | `ppRules`/`ppApplications` (ast-2); `rename-dsl`; usages de palavra de DSL; lifting; S1-S5 |
| B4b (2026-07-06) | memvars: mapa de visibilidade no usages; `rename-memvar` fecho-fechado; WorkDir atômico (R1) |
| B4c (2026-07-06) | rename-method por âncoras de forma — **MORTAS na B4d** (registro histórico) |
| B4d (2026-07-06) | Rastro de derivação `from` (ast-3); `rename-pp-marker` genérico; G1-G7; âncoras por forma removidas |
| B4e (2026-07-06) | Comandos cientes de construtos (P0-P3, extract-para-método) — **generalidade só provada em hbclass: ver revisão Q1-Q3/Q7** |
| B4f (2026-07-06) | Canal de tipos da linguagem (ast-4); camadas confirmed/excluded/possible no usages |
| B4f-2 (2026-07-07) | Resolução de dispatch (`ResolveDispatch`); homônimos; declarações vinculadas à dona; extensão v0.5.0 — **`ClassParentsSeq`/methodQuery: ver revisão Q4/Q5** |
| B4f-3 (2026-07-07) | PROVA da generalidade: DSLs inventadas com homônimos, comandos embrulhando classes, cstruct real, escrita `o:x`, construtos não-classe (casos 72-74; suíte 467/0) |
| Auditoria (2026-07-05) | Gramática duplicada morta (`NameAccepted` via compilador-biblioteca; `CoreFunction` via harbour.hbx) |

Réplicas conservadoras remanescentes (da auditoria, não urgentes):
`StrDelimsOk` (delimitadores de string — ideal: span original no dump);
cheque textual de continuação `;` em 2 pontos (falso positivo só recusa).

## Fases ATIVAS (por prioridade)

### R — Revisão de generalidade (A FRENTE PRIORITÁRIA)

**Escopo e checklist**: [revisao-generalidade.md](revisao-generalidade.md).
Q4 primeiro (pai falso no ClassGraph é o único candidato a resposta
ERRADA); depois Q1-Q3/Q7 (prova adversarial dos comandos B4e em DSL
inventada NÃO-espelho, ou conserto, ou recusa honesta); Q5 (matar o
regex da extensão: `resolve-at` por fato no CLI) e Q6 (rótulo do dono no
vocabulário da regra raiz).
**Critério**: todas as Q fechadas com caso na suíte; régua do caso 64
assertada; `make test` verde; ast-schema atualizado onde a resposta for
teto honesto.

### B4g — a diretiva como fonte de primeira classe (schema ast-5)

**Spec executável (escrita 2026-07-07, aguarda portão dos probes)**:
[spec-b4g-diretiva-fonte.md](spec-b4g-diretiva-fonte.md). `ppRules[]`
ganha `match[]`/`result[]` (token a token: papel, tipo de marker,
posição byte-exata; snapshot no registro via `hb_pp_trackRule`, gated
`fTrackPos`, zero impacto sem `-x`). Ferramenta: usages nomeando sites
DENTRO de regra; caso 74 acionável + `--edit-rules`; rename de palavra
secundária e de restrição; morte da reancoragem textual da cabeça.
Alimenta o Q5 da revisão (resolve-at cobre sites de diretiva).
**Critério**: na spec (mecânico) — zero impacto -w0 E -w3 + relink
duplo; `match[]`/`result[]` byte-exatos contra os `.ch`; round-trips;
suíte + lexdiff verdes.

### B5 — Extensão VSCode (restante)

Fatias entregues no arquivo. Restante: `--show-expansion` como opção;
preview `--dry-run --json` se a fricção pedir; **Q5 da revisão substitui
o `methodQuery`** (deixa de ser heurística local).
**Critério**: Diego usa no dia a dia; sem regressão.

### B-infra — suíte paralela (pool dinâmico)

Racional: [testes-paralelos.md](testes-paralelos.md). Pré-requisito R1
(WorkDir atômico) ✅ na B4b. Forma travada: pool dinâmico por-caso
(`xargs -P`/`wait -n`), `TMPDIR` isolado, resultado por artefato, tally
no join; Etapa 1 em bash, Etapa 2 em `.prg` (`hb_processOpen`, mata o
python dos casos 18/26).
**Critério**: paridade pass/fail com o runner anterior; 10× sem flake;
wall-time < sequencial; `JOBS=1` para depurar.

### B6 — PR upstream (BLOQUEADA: só quando o Diego mandar)

Mensagem com consumidor real; 1 arquivo novo + ganchos opt-in; prova de
zero impacto na árvore inteira; build limpo (corrigir o `-Wtype-limits`
de compast.c:578 — tirar o `iType >= 0`); regen bison 3.8.2 documentado;
split opcional em 2 PRs; ChangeLog via `bin/commit.hb`; uncrustify.

## Backlog (por valor)

0. **Velocidade em projetos grandes**: `-inc` já dá dumps incrementais;
   verificação proporcional à edição quando o uso real doer.
1. **Análise de programa inteiro (tipos interprocedurais)**: ponto fixo
   sobre os dumps com conjuntos finitos de classes — alavanca B do
   [mapa](limites-e-alavancas.md); os fatos (parms/RETURN) já estão no
   dump. Encolhe o "possible" para código disciplinado sem heurística.
2. **Evidência de execução (funil `hb_vmSend`)**: gancho gated no VM
   registrando despachos observados — terceiro nível epistêmico, nunca
   misturado ao estático (alavanca D do mapa).
3. **Regra sem cabeça** (`head null`, hbcompat legado): dump já registra;
   candidata a fixture de RELATO se um projeto real trouxer o caso.
4. Dedup pré/pós-decremento: não-fazer mantido (v2).
5. **Projetos grandes de produção** (quando o Diego liberar): dogfooding
   final — só depois de suíte + hbhttpd verdes.
