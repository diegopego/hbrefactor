# Spec B9 — Fatia 2 v2: `annotate`, a escada de declarações

Status: **ATIVA (reescrita F2.2 do plano vigente
[plano-b9-fatia2-escada.md](plano-b9-fatia2-escada.md), 2026-07-09;
execução aberta pelo Diego na mesma data).** Estágio 1 (relatório)
ENTREGUE; **PORTÃO DO MEIO decidido (Diego, 2026-07-09): candidato (g)
adotado, F2.4 aberta.** Estágio 2 (`--apply`) ENTREGUE — ver
"Entregue (F2.4)" no fim. A v1 desta spec (P1-a/P1-b/P2/P3 como portões) foi
dissolvida pela investigação do P1 — registro da dissolução no plano,
§ "Esclarecimentos pós-aprovação". Fatos do compilador que esta spec
consome: ast-schema § "O que o compilador FAZ e NÃO FAZ com as
tabelas". Sementes obrigatórias do critério de aceite: itens
`[FATIA-2]` de [testes-suspensos-re3.md](testes-suspensos-re3.md).
Fatia 1 (core `-kt` + consumo): entregue e corrigida
([spec-b9-anotacoes-impostas.md](spec-b9-anotacoes-impostas.md), RE.2).

## O que é

`annotate` — o comando que fecha o ciclo virtuoso da REGRA DO FATO:
a máquina B7/B7b (DORMENTE desde o RE.3) sugere; o comando **escreve
declarações e anotações da linguagem**; o `-kt` impõe; o site volta a
decidir por FATO no `usages`. É o **único consumidor** da máquina
dormente: revive-a por `B7Ctx` (hbrefactor.prg:6288) e mata o W0034 do
build. O `usages` de produto continua sem construir `hInter` — nada
aqui re-liga inferência ao veredito.

## A escada (decisões do Diego incorporadas, 2026-07-09)

Todo candidato à anotação é classificado pela JUSTIFICATIVA disponível:

- **Nível 1 — fato declarado puro.** O tipo do RHS resolve pelo canal
  declarado sem a máquina (TypeOf com `hInter == NIL`). Materializa por
  default (mesmo nível epistêmico do `confirmed declared` do produto).
- **Nível 2 — fecha com one-liner(s) declarado(s).** A cadeia quebra em
  elo(s) que a MECÂNICA DA LINGUAGEM fecha (tabela abaixo). A máquina
  dormente é quem PROVA qual declaração escrever (é o papel de
  sugeridora do RE.3); a edição escreve os one-liners primeiro,
  verifica, **re-analisa**, e só então a local/param é anotada — a
  justificativa final é fato declarado, nunca `via`.
- **Nível 3 — só inferência.** Nenhum elo declarado fecha (ex.: união
  de call sites de parâmetro). **NÃO edita — nem com flag** (decisão
  do Diego): recusa nomeada no relatório ("justificativa só por
  inferência; se quiser, anote à mão"); válvula `--force` só em fatia
  futura, com a fricção medida.

## Mecânicas por topologia (F2.1 — todas com probe compilado E executado)

| Topologia do site | One-liner | Prova (scratchpad/f21) |
|---|---|---|
| classe hbclass no MESMO módulo, membro FALTANTE (`New` herdado — fixrcv r2) | `_HB_MEMBER <M>() AS CLASS <Cls>` avulso após a classe; sem W0019; gruda na ÚLTIMA classe declarada (`pLastClass`) — multi-classe (fixext e1) exige posição entre a classe-alvo e a próxima | proba/proba2 + execução `-kt` |
| classe em OUTRO módulo ou runtime-pura (fixcls w2, fixdis, fixmth, DSLs) | `DECLARE <Cls> <M>() AS CLASS <Cls>` no módulo do SITE — registra a classe (mata o W0025/degrade), declara o membro e auto-declara `<Cls>()` | smoke3/probc; `-kt` checa por NOME no objeto VIVO |
| fábrica/retorno de função (fixb7 b1) | `DECLARE <F>() AS CLASS <Cls>` **antes da definição, no módulo definidor** — a ordem é IMPOSIÇÃO (DECLARE depois NÃO embrulha, provado com fábrica mentirosa); se a classe não está registrada no módulo, registrá-la ANTES (linha da topologia acima) | probb: `MenteA` dispara, `MenteB` silencia, `CriaA` roda |
| membro JÁ declarado ganhando retorno (fixb7b q1 `Pega`/`Soma`) | **DESBLOQUEADA (candidato (g) ADOTADO, core `00ccbc20b3`)**: `_HB_MEMBER <M>() AS CLASS <C>` repetido faz o merge (hbmain.c:1178) e o W0019 já não dispara em complemento de tipo (hbmain.c:1174-1180); topologia (g) vira nível 2 normal | probg/probg2 + pg1-pg5b |
| classe citada sem registro no módulo | RECUSA mecânica: W0025 + o dump PERDE a classe (`type O`) | probd |

## Pipeline

**Estágio 1 (F2.3 — relatório, zero edição):**
1. Carrega dumps do projeto (hbmk2, como todo comando) e constrói
   `B7Ctx( hAsts, hDecl )`.
2. Enumera candidatos: locals/params sem tipo (`declarations[]` sem
   `type`, sem `dim`) cujo TypeOf-com-máquina prova classe única; e
   funções sem DECLARE cujo retorno a máquina prova (pushes `ret`,
   identidade `QSelf`).
3. Classifica cada um na escada; para nível 2, NOMEIA os one-liners
   exatos (texto + módulo + posição); nível 3 e recusas mecânicas saem
   com motivo nomeado.
4. `--json` estruturado + texto humano; NENHUMA edição de fonte do
   usuário (o único arquivo gravado é o de SAÍDA pedido em
   `--json <out>` — mesmo contrato do `usages --json`; precisão da
   revisão Codex, Q1/Q6.1).

**Estágio 2 (F2.4 — edição, só após o portão):**
5. Escreve os one-liners do nível 2 (ordem: registro de classe →
   membro/DECLARE de função), verifica, re-analisa; escreve as
   anotações de local/param justificadas por fato declarado
   (nível 1 + nível 2 pós-recompute); âncora byte-exata pelo
   `tokens[]` (`prov 's'`; sítio de expansão de pp = recusa).
6. Verificação padrão-ouro POR EDIÇÃO, em cópia atômica (`WorkDir`):
   (i) sem `-kt` `.hrb` byte-idêntico (anotação é inerte — se mudou
   pcode, rollback); (ii) compila limpo `-w3 -es2`; (iii) com `-kt` o
   projeto RODA e os cheques passam. Rollback + relato nomeado em
   qualquer falha (idioma `Refuse`/`RollbackAll`).

## Recusas fato-based (relato honesto, nunca ajeito)

Nível 3 (só inferência); conjunto >1/`clsset` (nunca decide);
multi-write discordante (⊤); memvar/field; parâmetro de codeblock
(A6 + Rota D — fora); sítio sem byte-exato (`prov != 's'`); classe
impossível de registrar no módulo do site; topologia (g) enquanto o
candidato de core não abrir. (Correção da revisão Codex, Q6.3: a
recusa por `usesMacro` da v1 era REDUNDANTE para o alvo da fatia —
`&` não alcança LOCAL, fato de linguagem já embutido na TypeOf, e
memvar/field já são recusa própria.) Cada recusa nomeia sítio e motivo.

## Limite honesto da verificação (declarado)

O passo (iii) só prova o que a execução EXERCITA: anotação em caminho
morto não dispara cheque na verificação — mas fica fail-fast para
sempre (o primeiro caminho real que a exercitar sob `-kt` estoura
nomeando). A escada reduz o risco na origem: só se escreve o que fato
declarado justifica; o resíduo inferencial não edita.

## Critérios de aceite

**Estágio 1 (F2.3):**
- Relatório reproduzível sobre sementes + fixtures da suíte +
  work/hbhttpd, com contagem por nível e one-liners nomeados; tabela
  registrada no roadmap e delta no limites-e-alavancas.md.
- Suíte 622/0 byte-idêntica paralelo × `JOBS=1` (o comando novo não
  muda nada existente); build da ferramenta SEM W0034.

**Estágio 2 (F2.4, após o portão) — um caso de suíte novo por semente
`[FATIA-2]`, fixtures originais INTOCADOS (cópia em WorkDir →
`annotate` → recompila → `usages` asserta no MESMO site):**

| Semente | Rota da escada | Rótulo-alvo |
|---|---|---|
| 39/61 fixcls w2:7 `oMenu:Paint()` | nível 2: `DECLARE UWMenu New()...` em w2 + local | `guaranteed ... AS CLASS UWMENU imposed by -kt checks` |
| 61 fixmth c2:28 `oC:Soma(5)` | nível 2: DECLARE (DSL, módulo do site) + local | `guaranteed ... CAIXA ...` |
| 63 fixrcv r2:28 `s:Zap()` | nível 2: `_HB_MEMBER New()...` (mesmo módulo) + local | `guaranteed ... SEMCTOR ...` |
| 66 fixdis d1:87/88 | nível 2: DECLARE (DSL) + locals — SÓ a tipagem; exclusão de homônimo segue Rota C (sem promessa) | `guaranteed ... NCMAIN/NCSECONDARY ...` |
| 84 fixext e1:71/73/74 | nível 2: `_HB_MEMBER` posicionado (multi-classe) + locals | `guaranteed ... CONTA/CONTAVIP ...` |
| 85 fixb7 b1:53 `p:Gira()` | nível 2: registro de classe + local (variante direta) | `guaranteed ... PECA ...` |
| 85 fábrica `Cria()` | nível 2: registro + `DECLARE Cria() AS CLASS Peca` ANTES da definição (IMPOSTO) | send do retorno decide por fato |
| 86 fixb7b q1:73/75 (`Pega`/`Soma`) | **nível 2-BLOQUEADO (candidato g)** — entra SÓ se o portão do meio abrir o (g) | — |

- Recusas assertadas: nível 3, W0025, topologia (g) [enquanto fechada],
  `prov != 's'`, codeblock; caso de ROLLBACK provocado (anotação que
  contradiz o runtime sob `-kt`).
- Cobertura honesta: site coberto sai `guaranteed`; escrita só em
  bloco/`@ref` sai `confirmed declared` sem selo (matriz RE.1/RE.2 —
  `B7KtCovered` decide, o comando não promete selo onde ela nega).
- Extensão VSCode `hbrefactor.annotate` na mesma fatia + guardas no
  harness do caso 71 + bump de versão.
- Suíte inteira verde byte-idêntica; `make lexdiff` limpo.

## Candidatos de CORE no portão do meio (adoção = decisão do Diego)

- **(f) `New` implícito**: classe `_HB_CLASS` ganha membro `NEW AS
  CLASS <própria>` por default no compilador (sobreposto por declaração
  explícita, sem W0019). Efeito: sites de `New` herdado viram nível 1
  SEM materialização. Protótipo DEPOIS do F2.3 (o relatório mede o core
  como está; o (f) entra como coluna-delta na tabela do portão). Mexe
  em baselines (re-tipa sites no canal declared) — por isso é decisão,
  não default.
- **(g) merge silencioso de re-declaração tipada**: não warnar W0019
  quando a re-declaração de membro COMPLETA tipo ausente
  (`cType == ' '`; hbmain.c:1174-1176) — o override já é o
  comportamento projetado, só o warning bloqueia. Destrava a topologia
  fixb7b q1.

## Fora do escopo (inalterado da v1)

Rota C (exclusão de homônimo em send) — SEM ROTA, não se promete;
Rota D (codeblock) — A6 + RE.5; Rota E (`possible` nomeado) — degrade
pleno salvo RE.6; cobertura completa do `-kt` — RE.5; FIELD/MEMVAR/
variável-de-macro; reativar `B7Ctx` no `usages` — proibido (RE.3).

## Entregue (F2.4, 2026-07-09)

Comando `annotate <projeto> [<arq[:função]>] [--json <out>] [--apply]`:
RELATÓRIO por padrão (estágio 1); `--apply` escreve (estágio 2). No CLI
(`src/hbrefactor.prg`): a análise virou reutilizável (`AnnLoad`/
`AnnPlan`/`AnnReport`) e o caminho de edição é `AnnApply` +
`AnnQueueIns`/`AnnResolveLine`/`AnnWriteInserts`/`InsertLinesBefore`/
`AnnNameCol`/`AnnWriteAnnots`/`AnnInsertAt`/`AnnGoldCheck`/`AnnKtRun`/
`AnnHasMain`. Âncoras ESTRUTURAIS (não texto): cada one-liner carrega
`{ kind: afterClass|beforeFunc, cls|func }`, resolvida em linha-fonte
por fato do dump (função por nome; classe = antes da 1ª função após o
CREATE CLASS, i.e. após END CLASS/antes da próxima — pLastClass é a
classe-alvo). Inserções bottom-up (linha DESC, agrupadas por linha);
AS CLASS por âncora de token (type 21, prov 's', ÚNICO na linha de
declaração) aplicada (linha,col) DESC. `-l` (suprime nº de linha) faz
o `.hrb` ser byte-idêntico apesar do deslocamento de linhas → o teste
inerte vale.

Pipeline bottom-up entregue: baseline `.hrb` → escreve one-liners →
**padrão-ouro** (inerte byte-idêntico sem `-kt` + compila limpo `-w3
-es2` + roda sob `-kt` se executável) → **re-analisa** (`AnnLoad`+
`AnnPlan` de novo) → escreve `AS CLASS` das locais AGORA nível 1 →
padrão-ouro de novo → `RollbackAll` + recusa nomeada em qualquer
falha. Prova de round-trip: **caso 89** (fixb7b) — 4 declarações + 3
AS CLASS, verificado, e os sends encadeados que a RE.3 degradara para
`possible` (caso 86) voltam a `confirmed ... via declared types`;
fixture original intocado (cópia em WorkDir). O `--apply` na topologia
(g) (send via retorno de método completado) também decide por fato.
Adotado o gatilho `--apply` (relatório = padrão seguro, sem edição
surpresa); a extensão VSCode expõe `hbrefactor.annotate` (relatório) e
`hbrefactor.annotateApply` (edição com confirmação modal), guardas no
harness do caso 71; `package.json` 0.9.0.

**Resíduos honestos de F2.4** (declarados, não varridos): (1)
~~projeto já-`-kt`~~ — **FECHADO (2026-07-10, portão de escopo aberto
pelo Diego)**: o teste inerte compila baseline e pós-edição SEM a flag
(`AnnNoKt` remove só o `-kt` dos flags resolvidos; com ela a anotação
muda pcode POR DESIGN — ela emite os cheques); a execução de
verificação segue com o projeto como está. Caso 97 (fixb7b +
`-prgflag=-kt`): antes recusava "a edição NÃO é inerte"; agora anota,
roda os cheques e o site coberto sai `guaranteed` DIRETO no `usages` —
invariante no mesmo passo, sem re-flag. (2) Anotação de PARÂMETRO
(assinatura) fica de fora — só LOCAL puro; a assinatura colapsa em
`tokens[]` (fato B4) e pede o idioma de `SigParamHits`; rendimento
auto-escrevível hoje é BAIXO (parâmetro quase sempre só se prova por
união de call sites = inferência = nível 3, que não edita) — fatia
futura, sob demanda real. (3) ~~rollback provocado~~ e (4) ~~demais
sementes~~ — **FECHADOS no complemento abaixo (2026-07-10)**.
Observação honesta registrada (caso 97): no send ENCADEADO o rótulo do
1º elo fica `confirmed ... via declared types` mesmo com a local
anotada coberta — o caminhante de cadeia subclama (nunca overclaim);
o `guaranteed` aparece no site de receptor direto.

## Entregue (F2.4-complemento + F2.5, 2026-07-10)

- **Caso 90 — rollback provocado** (fixture `fixrbk`): mentira num
  fato DECLARADO — `_HB_MEMBER ACHA() AS CLASS MOEDA` promete que o
  método `Acha()` de BAU (pertencimento por POSIÇÃO/pLastClass)
  DEVOLVE MOEDA (o `AS CLASS` do `_HB_MEMBER` é tipo de RETORNO,
  hbclass.ch:282 — dona e retorno distintas de propósito, precisão do
  Diego); o runtime devolve N. Pristino compila e RODA limpo sob `-kt`
  (promessa de membro não imposta — fato 6: a mentira é INVISÍVEL sem
  o materializador); `--apply` escreve por fato declarado, o cheque
  pós-store pega EM EXECUÇÃO, rollback restaura BYTE A BYTE (cmp) e a
  recusa nomeia o motivo com o BASE/3012 verbatim (`AnnChkLine`).
- **Casos 91-96 — round-trip por semente** (fixcls/fixmth/fixrcv/
  fixdis/fixext/fixb7): tabela de aceite cumprida — cada site decide
  `confirmed send (receiver declared AS CLASS <X>)` na cópia
  materializada e **sobe a `guaranteed ... imposed by -kt checks`**
  com `-prgflag=-kt` no projeto (o rótulo-alvo da tabela). Recusas
  honestas assertadas: nível 3 NÃO editado (fixb7 `oCoisa`/`o`);
  espelho/cruzado segue `possible` com relação nomeada (Rota C sem
  rota — casos 92/94/95). Fixtures originais intocados.
- **Correções que as sementes provocaram**: (i) nível 1 com classe
  fora do módulo do site → nível 2 com **registro puro `_HB_CLASS
  <Cls>`** (harbour.y:1253; sem promessa de membro — substituiu também
  o regtext `DECLARE ... New()`); (ii) **atribuição honesta**: pristino
  roda sob `-kt` ANTES da edição; se já falha, o passo `-kt` degrada
  para "pulado" nomeando a falha pré-existente (fixb7) em vez de
  culpar a edição; (iii) recusa do padrão-ouro nomeia site/tipos do
  próprio erro (`expected S:X, got Y @ FUNC:VAR`).
- F2.5: testes-suspensos-re3 Rotas A/B **RECONQUISTADAS**; M-annotate
  re-medida com o ciclo completo no corpus (31 declarações + 7
  anotações; re-relatório drena — limites-e-alavancas.md); suíte
  **692/0** byte-idêntica paralelo × `JOBS=1`; lexdiff limpo.
