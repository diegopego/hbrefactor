# Fase RE — Re-escopo pós-revisão externa (plano vinculante)

Status: **FASE ATIVA — PRIORIDADE 1 (portão aberto pelo Diego,
2026-07-09: seguir o plano da revisão e documentá-lo para garantir a
execução).** Este documento É o plano; o roadmap aponta para cá.

**Como este plano se impõe** (mecanismo, não intenção):

1. Cada item RE.n tem critério de pronto EXECUTÁVEL; item fecha só com
   a evidência colada aqui (mesma sessão — regra do CLAUDE.md).
2. **Guarda de fase**: enquanto RE.1-RE.4 não fecharem, nenhum trabalho
   novo sobre B7/B7b, `guaranteed`, ClassGraph/dispatch ou fatia 2 da
   B9 (materialização) fora dos itens desta fase. Quem retomar a sessão
   começa por AQUI (o roadmap manda para cá no topo das ativas).
3. Decisões de produto embutidas ficam marcadas como **[PORTÃO Diego]**
   — o item não executa sem elas.

## Origem — as três rodadas da revisão externa (registro)

Instrumento (réguas R1/R2 do dono, glossário, delimitação do objeto):
[revisao-codex-zero-inferencia.md](revisao-codex-zero-inferencia.md).
Rodadas via Codex CLI em 2026-07-09, estado revisado: harbour-core
`c1927dfcac` (delta `master..HEAD`, 12 commits/16 arquivos — só o
delta está em julgamento), hbrefactor `6584aa8`/`590a4a5`:

| Rodada | Modelo | O que leu | Entrega |
|---|---|---|---|
| 1 — forma | gpt-5.4-mini | o instrumento + conferência pontual dos trechos citados | 6 achados de forma — aplicados no commit `590a4a5` |
| 2 — mérito | gpt-5.5 | leituras dirigidas pelas Q1-Q5 (amostral) | vereditos Q1-Q5 |
| 3 — auditoria | gpt-5.5 | o delta do harbour + as regiões críticas da ferramenta | achados A1-A5 (abaixo) + veredito por área |

Honestidade de escopo: nenhuma rodada leu 100% do experimento
(estimativa: 20-30% nas rodadas 1-2; a rodada 3 cobriu o delta do core
por inteiro e a ferramenta por amostragem dirigida). O peso do veredito
é de ARQUITETURA com evidência pontual de código, não de auditoria
linha a linha; a suíte não foi executada pelo revisor (sandbox
somente-leitura).

## O veredito convergente

As rodadas 2 e 3 convergem ENTRE SI e com o julgamento interno
registrado em 2026-07-08 (pendência 3 da sessão — "manter renames
verificados + usages honesto; a linha semântica não compensa no teto
medido"):

- **Manter como estão**: dump `-x` (factual, gating correto),
  rastreamento de PP (a parte mais aderente a R2), renames/extract/
  reorder verificados por recompilação, `usages` factual.
- **`-kt` é R1-legítimo** (é "estender o core para o fato existir"),
  mas fatia 1 + consumo OVERCLAIMAM: `guaranteed` sai para sites que o
  cheque não cobre (A1/A2).
- **B7/B7b são inferência nos termos de R1** — rótulo honesto não
  salva como produto; rebaixar para SUGERIDORA/materializadora de
  anotações (o destino que o CLAUDE.md já previa).
- **Veredito de viabilidade (Q5)**: "a linha atual, como produto
  amplo, não compensa. Re-escopada, compensa." Produto mínimo
  defensável: dump factual + PP genérico + refatorações verificadas +
  `guaranteed` real por `-kt`.

## Achados da auditoria (rodada 3) — verificar no fonte ANTES de agir

Disciplina do repo: achado externo é HIPÓTESE até confirmação com
arquivo:linha (e probe executável quando couber). Status vive aqui.

- **A1 — `guaranteed` falso para símbolos que `-kt` não checa.**
  Alegação: o core só emite prólogo para parâmetros de assinatura
  (harbour.y:331) e pós-atribuição só para `HB_VS_LOCAL_VAR`
  (hbmain.c:2873); ficam fora `PARAMETERS`, parâmetros de codeblock e
  escrita em local detached dentro de bloco — mas `B7KtMark`
  (hbrefactor.prg:6409) marca QUALQUER anotação de módulo `kt` e o
  veredito sai `guaranteed` (hbrefactor.prg:7708). Quebra R1.
  Status: **A VERIFICAR** (nota: o gap de codeblock estava registrado
  como fora da fatia no ast-schema.md §B9; o furo NOVO alegado é o
  consumidor não degradar por causa dele).
- **A2 — `PARAMETERS x AS ...` está no canal e não é imposto.**
  Alegação: gramática aceita via `MemvarList` (harbour.y:1113 +
  AsType:1229); `hb_compChkTypeParams()` não passa por esse caminho.
  Status: **A VERIFICAR**.
- **A3 — B7/B7b são inferência** (uniões: hbrefactor.prg:6500/7213/
  6690/6993). Status: **ACEITO SEM VERIFICAÇÃO ADICIONAL** — é o que a
  própria documentação diz; a consequência é o RE.3.
- **A4 — a ferramenta é class-keyed onde o core é genérico**
  (ClassGraph:7509, dispatch:7553, síntese `METHOD ... CLASS`:2777).
  Status: **ACEITO COM CONTEXTO** — a síntese hbclass é exclusiva da
  forma hbclass por portão (Q7 da revisão de generalidade); o resto é
  objeto do RE.3/RE.6.
- **A5 — `pPosTbl` não é limpo em `hb_pp_reset()`** (ppcore.c:6665;
  só no destrutor, ppcore.c:2909) — risco de proveniência fantasma
  entre módulos por reuso de ponteiro com mesmo `value/len`.
  Status: **A VERIFICAR**.

## O plano (ordem de execução; critérios executáveis)

**RE.1 — Verificar A1, A2 e A5 no fonte.**
Critério: cada um confirmado ou refutado com arquivo:linha e, para
A1/A2, probe executável (fixture `-kt` com `PARAMETERS x AS`,
parâmetro de bloco anotado e escrita em detached — o cheque dispara ou
não dispara?); refutado = registrar aqui e fechar. Resultado atualiza
o status acima na mesma sessão.

**RE.2 — `guaranteed` honesto (consumidor; curto prazo).**
Escopo: restringir a marca `kt` (`B7KtMark`) aos sites que o `-kt` da
fatia 1 COBRE de fato (conforme RE.1): parâmetro de assinatura e local
anotado com escrita coberta; anotação não coberta degrada para o canal
`declared` (a promessa continua, sem o selo de invariante).
Critério: casos de suíte novos (fixkt estendido) provando que
`PARAMETERS AS`/param de bloco/detached **não** saem `guaranteed`;
caso 87 intacto nos sites cobertos; suíte verde byte-idêntica
paralelo × JOBS=1.

**RE.3 — B7/B7b fora do veredito de produto.**
Escopo: `confirmed`/`excluded` derivados de inferência (cadeia de
construção, união de call sites/retornos/Evals, ClassGraph "as
written") deixam de ser veredito de produto; a máquina vira camada
SUGERIDORA — insumo do comando de materialização (fatia 2 da B9), não
resposta do `usages`.
**[PORTÃO Diego]** a forma da camada rebaixada: (a) some do `usages` e
só existe no materializador; (b) aparece atrás de flag explícita
(ex.: `--inferred`) com rótulo `suggested`; (c) outra.
Critério: nenhum `confirmed`/`excluded` do `usages` de produto deriva
de B7/B7b/ClassGraph (prova: casos 84/85/86 re-baselined para o novo
contrato); M-cov re-rodada (`tests/mcov2.sh`) e o retrato honesto
pós-rebaixamento registrado no limites-e-alavancas.md; suíte verde.

**RE.4 — Hardening `pPosTbl` (core; independente, pode intercalar).**
Escopo: limpar `pPosTbl` em `hb_pp_reset()` (se A5 confirmar).
Critério: zero impacto sem `-x` (byte-idêntico, protocolo padrão);
`make lexdiff` limpo; suíte 616+/0. Commit no harbour-core só com
autorização do Diego.

**RE.5 — [GAVETA — PORTÃO Diego] cobertura completa do `-kt`.**
Estender a emissão no core (`PARAMETERS`, params de bloco, detached)
E/OU matriz explícita "o que é imposto" no dump. RE.2 remove a
urgência (o consumidor para de overclaimar); esta fatia devolve
alcance. Abrir só com escopo+critério escritos, depois de RE.1-RE.3.

**RE.6 — [GAVETA — PORTÃO Diego] contratos genéricos de diretiva.**
A resposta de Q3 da revisão: invariantes genéricas por construto de
diretiva (papéis de marker, relações owner/member/generated-symbol no
dump), sem "classe" como modelo universal. Spec separada quando o
Diego abrir o portão.

## O que NÃO muda nesta fase

Dump `-x` e rastreamento de PP (vereditos "manter"); renames/extract/
reorder verificados; camadas `confirmed`/`excluded` por FATO
não-inferido (tipo declarado do próprio símbolo, homônimos por
declaração, exclusão por conjunto nomeado); o contrato de degradar
honesto. A fatia 1 da B9 fica commitada como está — RE.2 corrige o
CONSUMO dela, não o core (RE.5 é que mexeria no core, sob portão).
