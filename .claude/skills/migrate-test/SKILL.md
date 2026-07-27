---
name: migrate-test
description: O loop de UMA iteração de teste no formato de CASO (tests-go/suite/, em Go) — migrando um teste legado (unit_N do run.sh ou tests/cases/), ou escrevendo um caso novo do zero. Carrega a ordem, os portões executáveis que mordem em cada passo, e o catálogo de erros que já custaram uma iteração. Use ao migrar teste antigo, ao abrir teste novo, ou quando um caso divergir e você precisar separar os dois lados.
disable-model-invocation: true
---

# migrate-test — uma iteração, e os portões que a seguram

**O CONTRATO NÃO ESTÁ AQUI.** Ele está em [`tests/README.md`](../../../tests/README.md):
o que é um caso, os quatro artefatos do `testdata/`, as provas, a regra do esperado
escrito à mão, a exceção do `oracle/`, como propor mudança. **Leia-o inteiro uma vez
por sessão** — e não releia a cada iteração. Aqui fica só o que muda por iteração.

Duplicar o contrato aqui criaria uma segunda fonte de verdade que envelhece torto.

## Por que esta skill é fina e os portões são grossos

A lei do repo (CLAUDE.md §1.6): *"contra o modo de falha de um contribuidor
heurístico — que é o que eu sou —, o que funciona é **portão EXECUTÁVEL**, não
documento. **Regra nova sem portão novo é regra que eu vou violar de novo.**"*

Já provado: em 2026-07-26, **com o contrato escrito e lido**, escrevi `unclassified`
num esperado e inventei uma convenção de ausência. Nenhum documento me segurou; os
dois portões seguraram. Então: se você propuser régua nova, a pergunta obrigatória é
**"que check impede isso de novo?"**. Sem resposta, a régua provavelmente não vai
funcionar.

## A fila — não é arquivo, é fato

```bash
tools/unit-brief.py --fila          # os unit_N que sobraram no tests/run.sh
ls tests/cases                      # o formato-ponte que ainda resta
```

A fila são os próprios legados: o que sobrou neles é o que falta. Nada de estado
paralelo a apodrecer. Os três destinos convergem para `tests-go/suite/`.

**O `unit_0` sai por último**: ele é quem prova que a fixture `fix01` compila limpo,
e cada caso só prova a `source/` dele.

## A iteração

```bash
tools/unit-brief.py <N>                      # 1. o que o teste antigo prova
tools/caso-new.sh <nome-que-diz-o-que-prova> <fixture>   # 2. source/ + o .go
#  3. escreva expected/ e outputs.json À MÃO, ANTES de rodar
#     e escreva a invocação no <nome>_test.go
make oracle NOME=<nome>                      # 4. o retrato do core — e LEIA
make caso NOME=<nome>                        # 5. divergiu? veja "divergência"
#  6. apague o teste antigo (unit_N da função E de ALL_UNITS; ou a pasta do
#     cenário/caso legado) — migrar é MOVER, não copiar
```

**`make test` roda no fim do LOTE, não a cada iteração** — é o desperdício mais
caro. Durante o lote, `make caso NOME=x` leva segundos.
**Exceção que obriga `make test` na hora:** tocou em `src/hbrefactor.prg` (nasceu
código de recusa), porque aí outros testes podem depender.

**Lote de 5 casos — ou de 1, se tocou no fonte.** Com 5 novos, um `make test`
vermelho ainda é diagnosticável; com 20, você vai bissecar o próprio trabalho.

## O passo 3 é o trabalho — os outros são mecânica

Quatro fatos, e nenhum se adivinha:

| fato | de onde sai |
|---|---|
| **coluna** | `unit-brief.py` já resolve. Dump é 0-based, CLI é 1-based |
| **a invocação** | `p.Roda("verbo", "proj.hbp", ...)` — um argumento por string, como o campo `argv` do envelope. **Sem `--json`**: o harness o acrescenta, e passá-lo reprova |
| **texto da mensagem** | do FONTE que a produz (`grep` em `src/hbrefactor.prg`) |
| **`reason`** | da taxonomia (`#define RSN_*`, num lugar só). **Não existe? Ele NASCE aqui** |

O `reason` é o ponto onde a migração paga: cada caso migrado classifica a recusa
que ele exercita. Família/par nasce junto — meio classificado, o mesmo fato sai com
dois códigos dependendo do comando.

**O que você NÃO escreve no teste:** as duas comparações (o projeto × `expected/`,
o relatado × `outputs.json`) são do harness e rodam depois da sua função retornar.
O caso só afirma o que é dele — um `editCount`, um `verdict`, um `proof`.

## Divergiu? Separe os dois lados

Um dos dois está errado, e dizer **qual** faz parte do trabalho:

- **o esperado** → conserte o esperado, e diga por quê (ex.: *"eu tinha omitido a
  prosa de progresso; ela vem de `Prose()` antes da verificação"*);
- **a ferramenta** → conserte a ferramenta.

**Nunca "conserte" copiando a saída.** É o golden-file entrando pela janela: um
arquivo idêntico, um teste diferente. Gravado, ele afirma *"a ferramenta faz isto
hoje"*; escrito, *"o contrato pede isto"*.

## Catálogo de erros — cada linha custou uma iteração

Só entra erro que **aconteceu**, com o caso que o expôs. Hipotético não entra —
é assim que o catálogo fica curto e lido.

| erro | sintoma | como não repetir | portão |
|---|---|---|---|
| esperado grava o defeito | você escreve `"reason": "unclassified"` | o código nasce NESTE caso | harness (`esperados`) |
| **decidir sem ler o roadmap** | você constrói contra a fase que está executando | a spec descreve o desenho; **o roadmap tem a DECISÃO, e é mais recente** | — |
| convenção implícita | *"a ausência de X significa Y"* | ausência nunca significa nada; a comparação é do envelope INTEIRO, cru | harness |
| coluna contada na cabeça | `no compile-time identifier at …` | sempre do `unit-brief` | — |
| **filtrar a saída de um comando de teste** | `\| grep` no fim engole a falha: o exit do pipeline é o do ÚLTIMO comando | comando de portão não passa por pipe | medido em 2026-07-26: o `make caso` saía 0 com o caso quebrado |

> **O segundo é o mais caro, e é recente (2026-07-26).** Escrevi um portão exigindo
> que todo cenário rodasse prosa **e** JSON — tendo lido a `spec-a` §2.2 (*a prosa
> como renderização do fato*) e **não** o `roadmap.md` A.1, onde está a decisão final
> e posterior do Diego: *"a saída é o envelope, e nada mais; sem renderizador humano
> (a prosa é arrasto → deletada); a flag `--json` some"*. O **passo 3 da própria fase
> é arrancar a prosa**. O portão foi invertido e os testes, limpos.
>
> **Régua: antes de construir régua nova, leia o `docs/roadmap.md` da fase ativa.**
> A spec diz como o desenho funciona; o roadmap diz **o que foi decidido, e quando**.

## Os portões, e o que cada um pega

| portão | quando morde |
|---|---|
| `Roda` | stderr não-vazio, stdout com algo além de UM envelope + `\n`, exit do processo ≠ campo `exit`, `--json` escrito no caso |
| `esperados` | `outputs.json` congelando `"reason": "unclassified"` |
| `transformação` | o projeto ≠ `expected/`; o relatado ≠ `outputs.json` (envelope CRU: pega até campo que o tipo não conhece); artefato novo não declarado; **caso que não invocou a ferramenta** |
| `TestCasos` | `testdata/<nome>/` sem caso registrado, e caso registrado sem `testdata/` |
| `fixture/compila` | `source/` + `expected/` por cima não compila limpo sob `-w3 -es2` |
| `fixture/vocabulário` | palavra de diretiva da fixture aparece em `src/hbrefactor.prg` (régua do caso 64) — extraída sozinha, não se declara |
| `fixture/retrato` | o `.ppo`/`.ppt` do core divergiu do `oracle/` |
| compilador + `go vet` | o resto (`make govet`) |
| hook `formato-de-teste.sh` | commit que ACRESCENTA teste a um formato legado — os que restam, e os já extintos, que ele barra de ressuscitar |

## Não coube no formato?

Isso é uma **proposta**, nunca uma exceção. Vá a `tests/README.md` §9 com: (a) o que
o teste prova, (b) por que o formato não modela, (c) o que resolveria, (d) o que isso
custa a quem lê um caso. E a régua que governa: **uma exigência só entra na spec
quando a implementação a honra** — exigência escrita e não verificada é pior que
omissa, porque quem lê acha que está coberto.

## Auto-ajuste desta skill

Achou fricção nova? Duas rotas, e as duas terminam em lugar durável:

1. **fricção de FORMATO** → proposta em `tests/README.md` §9 (o contrato);
2. **fricção de PROCESSO** → linha nova no catálogo acima, com o caso que a expôs.

E, nas duas, a pergunta que não se pula: **que portão impede isso de novo?** Régua
sem portão é régua que a próxima sessão quebra — foi assim que esta skill nasceu.
