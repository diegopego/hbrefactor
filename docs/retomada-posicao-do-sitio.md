# Retomada — a frente da POSIÇÃO DO SÍTIO (P21 entregue → P24 aberta)

**Por que este arquivo existe, e por que não é o `handoff.md`** *(Diego, 2026-08-06:
"existe outra [sessão] em andamento e não quero que este trabalho daqui seja perdido")*.
Duas sessões correram em paralelo neste repo no mesmo dia. O `handoff.md` e o
`roadmap.md` são superfícies **compartilhadas** — a outra sessão commitou nos dois — e
um documento de retomada que pode ser sobrescrito não retoma nada. Este é escopado a
UMA linha de trabalho e some quando ela fechar.

> **Não é fonte de verdade concorrente.** O estado durável mora no
> [`roadmap.md`](roadmap.md) (P21, P24) e o mecanismo em
> [`posicao-do-sitio.md`](posicao-do-sitio.md). Aqui só entra o que eles NÃO dizem:
> onde a linha parou, o que retomar primeiro, e onde se tropeça.

---

## 1. O ESTADO EXATO

**Tudo desta frente está COMMITADO.** Nada em risco no working tree.

| repo | commits desta frente |
|---|---|
| hbrefactor | `4a70134` a entrega da P21 · `8c07fe6` o CHANGELOG · `b1a825e` os dois toolchains + portão do pipefail · `d18456d` o build limpo sem janela |
| harbour-core | `c37f8b7c93` `ast-21` · `b7c1aa979a` o `NEWS.md` · `5f827665bd` a página aos mantenedores |

`make test` no HEAD: **verde** (1001/0, `lexdiff` 100/0, Go completo) desde que o
vermelho de TDD da §2 esteja fora.

**Nada foi enviado (`push`).** Os dois repos estão só locais.

---

## 2. O ÚNICO ARTEFATO FORA DO GIT — e ele é o próximo passo

```
tests-go/suite/usages_site_from_include_test.go
tests-go/suite/testdata/usages-site-from-include/
```

É o **TDD vermelho da P24**, escrito à mão ANTES do conserto, que é o método deste repo
(§3: o esperado se escreve, nunca se grava). Ele fica untracked de propósito — a §3 quer
o HEAD verde, e ele entra com a entrega que o torna verde.

> ⚠️ **Untracked morre num `git clean -fdx`.** Se esta frente for ficar parada por muito
> tempo, vale decidir entre (a) deixá-lo assim e não rodar `git clean`, ou (b) commitá-lo
> aceitando um HEAD vermelho até a P24 fechar. Hoje está em (a).

O que ele cobra, e que é o contrato da P24:

- o uso trazido pela diretiva sai em `6:3..11` — o token `CMD_SOMA` da aplicação — e
  não em `6:0..0`;
- a entrada do `.ch` sai com `text` (o preview da linha), não `null`.

---

## 3. O PRÓXIMO PASSO: a P24, com a sonda JÁ FEITA

Escopo e critério mecânico estão na [P24 do roadmap](roadmap.md). O que a próxima
sessão precisa saber e que economiza a exploração inteira:

**A cadeia que eu supunha publicada NÃO existe.** A leitura de primeira era
`token → from[].app → ppApplications[app]`. Medido: o `from[]` só nasce para **artefato
de operação do pp** — colagem, stringify, clone (`hb_pp_fromAdd`, ppcore.c:783/808). O
`nAcc` que a regra copia do próprio resultado é token **comum**: sai
`{"line":1,"col":null,"prov":"i","text":"nAcc"}`, **sem `from`**.

**Mas o fato existe e está a uma estampa de distância:** `pState->iDrvApp`
(ppcore.c:1680) é o índice da aplicação corrente, posto assim que
`hb_pp_trackApply()` registra o `ppApplications[]`. É dele que as entradas de derivação
já se servem. Falta estampá-lo nos tokens de resultado **comuns**.

**Régua que não afrouxa:** nada de *"a aplicação que está na mesma linha do sítio"* —
duas diretivas numa linha (`CMD_A 1 ; CMD_B 2`) tornam isso adivinhação. É o índice ou
é nada.

### Não confunda com a fase X da outra sessão

Ela nasceu no mesmo dia e o nome colide de propósito nenhum:

| | pergunta | para quê |
|---|---|---|
| **P24** (esta frente) | que **aplicação de diretiva** escreveu este nome? | posição de sítio, find-all-references |
| **[Fase X](roadmap.md)** (outra sessão) | este **`.ast.json`** corresponde a este fonte? | destravar o `-inc` da W.3 |

As duas dizem "procedência" e "de onde veio". São artefatos diferentes e não se
bloqueiam.

---

## 4. ONDE VOCÊ VAI TROPEÇAR

- **`make core` é o único jeito de buildar o core** — nunca incremental. Ele já não
  deixa a árvore sem compilador (os binários são preservados fora e devolvidos após o
  `clean`), mas continua levando ~2min30. **`make core-check` responde em 1s** se o
  binário que você está medindo é o do fonte de agora — rode isso antes de confiar em
  qualquer medida, sobretudo ao voltar de uma pausa. *(CLAUDE.md §2, cicatrizes §5.1.)*
- **São DOIS toolchains e o papel de cada um está em código**, não em prosa:
  `tools/hbenv.sh`. O do branch trabalha; o stock (`make stock`, worktree de
  `upstream/master` em `harbour-stock/`, **175 MB, fora do git**) só existe para ser
  comparado. `make pcode-identity` roda a prova — hoje **889/889, 0 divergentes**.
- **Sessões em paralelo disputam recursos globais**: `make core` e `make stock` mexem
  em binários compartilhados, e `make test` escreve em `tests/tmp/`. Antes de rodar
  qualquer um deles, saiba se há outra sessão viva.
- **Nada de `git add -A`.** Duas sessões neste repo no mesmo dia; nomear arquivo por
  arquivo é o que evita varrer o trabalho alheio para dentro do seu commit. Conferi
  depois: nenhum commit meu varreu nada — mas foi sorte, não cuidado.
- **`docs/roadmap.md` foi editado pelas DUAS sessões.** Reler antes de escrever nele.

---

## 5. O QUE FICA PENDENTE ALÉM DA P24

- **`push` nenhum foi feito**, nos dois repos.
- **O email do autor no core é um placeholder** — `{ID}+{username}@users.noreply.github.com`,
  em **49 commits** do branch, não só nos meus. Para um branch upstreamável (fase B6)
  isso não passa; corrigir é reescrever a autoria de todos eles, e é decisão sua.
- **`make core` ainda leva 2min30.** A janela sem compilador fechou, mas o custo não. Se
  incomodar, o caminho seria buildar num diretório à parte — não explorado.
