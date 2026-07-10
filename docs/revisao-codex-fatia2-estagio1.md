# Brief de revisão externa — B9 fatia 2, estágio 1 (`annotate` relatório)

Instrumento para revisão independente via Codex (idioma da fase RE:
o brief é FATO e pergunta, sem juízo do requisitante; achado externo é
hipótese até verificação no fonte com arquivo:linha).

## Objeto

O delta NÃO-COMMITADO do working tree sobre `master` (`e56d841`) do
repositório hbrefactor:

- `src/hbrefactor.prg` — comando novo `annotate` (estágio 1 —
  relatório): funções `Annotate`, `AnnOne`, `AnnLinks`, `AnnAddLine`,
  `AnnClsInMod`, `AnnClsModName`, `AnnParamList`, `AnnSigTxt`,
  `AnnSetTxt` (bloco inserido antes do banner "B7 - tipos
  interprocedurais"); CASE novo no dispatch de `Main()`; linhas novas
  no `Usage()`.
- `docs/ast-schema.md` — seção nova "O que o compilador FAZ e NÃO FAZ
  com as tabelas".
- `docs/spec-b9-fatia2-materializacao.md` — reescrita completa (v2).
- `docs/plano-b9-fatia2-escada.md` — resultados F2.1/F2.3 e tabela de
  alcance.
- `docs/roadmap.md` (§ B9), `docs/limites-e-alavancas.md`
  (§ M-annotate).

## Contratos vigentes (réguas da revisão)

1. **Estágio 1 = zero edição**: o comando só relata; nenhum caminho de
   escrita em fonte do usuário pode existir.
2. **RE.3 intacto**: o `usages` de produto NÃO consome a máquina
   B7/B7b (constrói com `hInter := NIL`); o único consumidor de
   `B7Ctx` deve ser o `annotate`.
3. **Escada**: nível 1 = fato declarado puro; nível 2 = one-liners de
   declaração NOMEADOS (mecânicas provadas: `_HB_MEMBER` avulso
   in-module; `DECLARE <Cls> <M>() AS CLASS <Cls>` no módulo do site;
   `DECLARE <F>(...) AS CLASS <X>` ANTES da definição no módulo
   definidor); nível 2g = membro já declarado sem tipo (bloqueado —
   W0019); nível 3 = só inferência, NUNCA materializa.
4. **Zero regressão**: nenhum comando existente muda de comportamento;
   suíte 622/0 byte-idêntica (verificada paralelo × JOBS=1).
5. Regras gerais do repo: CLAUDE.md (REGRA DO FATO; nunca editar o
   não-verificável; genérico > específico).

## Perguntas (responder com arquivo:linha)

- **Q1**: Existe no delta algum caminho pelo qual `annotate` escreva ou
  modifique arquivo do usuário (direta ou indiretamente)?
- **Q2**: A revivificação de `B7Ctx` pelo `annotate` vaza para algum
  veredito de produto (usages/renames)? Algum estado compartilhado
  (memos em `hInter`, campos `_b7*` gravados nos asts) contamina outro
  comando?
- **Q3**: `AnnOne`/`AnnLinks` espelham a semântica da `TypeOf` com
  fidelidade? Aponte divergências que possam (a) classificar nível 2
  com one-liner INSUFICIENTE para fechar a cadeia, (b) classificar
  nível 1/2 onde a TypeOf-fato não resolveria, ou (c) perder elos
  (classificar nível 3/divergência onde havia rota declarável).
- **Q4**: Os one-liners emitidos respeitam as mecânicas do contrato 3
  (topologia certa por caso)? Há emissão de linha cuja compilação
  falharia (W0019/W0025) se materializada como proposto?
- **Q5**: O relatório pode MENTIR? (ex.: nível 2 cuja materialização
  não tornaria o site decidível pelo canal declarado; contagens do
  resumo inconsistentes com as listas.)
- **Q6**: Os documentos do delta afirmam algo que o código não sustenta
  (ou vice-versa)?

## Estado para reprodução

- Build: `make` (usa `HB_BIN ?= ~/devel/harbour-core/harbour/bin/linux/gcc`).
- Suíte: `make test` (622 esperados).
- Relatório nas fixtures: `HB_BIN=... bin/hbrefactor annotate
  tests/<fix>/<fix>.hbp [--json <out>]`.
- Probes das mecânicas: scratchpad da sessão (fora do repo); as
  evidências estão coladas em `docs/plano-b9-fatia2-escada.md` (F2.1).

## Achados e vereditos (verificação Claude, 2026-07-09 — mesma sessão)

Rodada única gpt-5.5 (a 1ª execução morreu em silêncio no meio da
leitura — pid sumiu com log congelado; re-execução com modelo
explícito). Cada achado verificado no fonte antes de agir:

| Achado | Veredito | Ação |
|---|---|---|
| Q1.1/Q6.1 `--json` grava arquivo × "NENHUM arquivo tocado" | CONFIRMADO como imprecisão TEXTUAL da spec (a intenção do contrato é fonte do usuário; `usages --json` tem o mesmo comportamento). Severidade real: baixa, não alta | spec corrigida (exceção nomeada) |
| Q2 (sem vazamento p/ produto; memos locais) | LIMPO — confirma RE.3 intacto | — |
| Q3.1/Q4.1 `AnnParamList` inclui param de CODEBLOCK na assinatura | **CONFIRMADO — bug real** (prova: dump probc, OS param declLine=15 ≠ função linha 9). PORÉM o risco W0016/17 alegado se apoiava num ERRO MEU no ast-schema: os emissores são só dos builtins i18n (hbexprb.c:1951-2034) — assinatura errada não warna; o bug é de FIDELIDADE | filtro `declLine == hFunc["line"]` aplicado + ast-schema corrigido |
| Q3.2 param de bloco declarado → infer prematuro | CONFIRMADO — convergiu com o achado próprio S1 (pré-relatório); direção conservadora | espelhamento consertado (DeclType primeiro) |
| Q4.2 posição do `_HB_MEMBER` sem âncora multi-classe | CONFIRMADO (texto do relato insuficiente p/ F2.4) | pos ganhou "e ANTES da próxima classe" |
| Q5.1 filtro de escopo não cobria funrets/(g) | CONFIRMADO | filtro aplicado às duas listagens |
| Q5.2 needreg sem o one-liner exato | CONFIRMADO | `regtext` no relato e no JSON |
| Q6.2 extensão VSCode "na mesma fatia" não entregue | **REFUTADO** — a exigência está nos critérios do ESTÁGIO 2 (F2.4) da spec; o delta é estágio 1 por desenho do plano aprovado | — |
| Q6.3 recusa `usesMacro` sem implementação | CONFIRMADO como excesso da SPEC, não falta do código: `&` não alcança LOCAL (fato de linguagem já na TypeOf) e memvar/field é recusa própria | spec corrigida |

Avaliação da revisão: 8 confirmados (1 bug real de código, 1 divergência
convergente com o S1 próprio, 2 de escopo/precisão do relato, 4 de
docs), 1 refutado, 1 com severidade rebaixada; o Q4.1 expôs por tabela
um erro MEU de doc (W0016/17) que nenhum dos dois tinha visto direto.
Pós-fixes: build limpo, suíte 622/0, relatório das sementes inalterado.
