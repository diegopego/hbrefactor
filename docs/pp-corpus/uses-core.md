<!-- guarda: NENHUMA (censo: o instrumento e' tools/pp-uses.sh) -->
# O USO real do pp — os ESPÉCIMES: que módulo, que arquivo, que linha

Índice: [README.md](README.md). As outras famílias explicam a **DEFINIÇÃO** (a
diretiva, dentro da `.ch`). Esta explica o **USO** — e o faz do único jeito que
ensina alguma coisa: **apontando o arquivo e a linha**, e explicando o que o pp faz
ali. *(Direção do Diego, 2026-07-13: "o pp tem muitos casos reais de uso no próprio
código fonte do Harbour que merecem ser estudados"; e, sobre a primeira versão desta
página, que era uma tabela de porcentagens: **"era melhor falar que módulo e arquivo
estudou do que falar de números"** — ele tem razão, e a razão é dupla: o número
envelhece e o `arquivo:linha` não, e o número dava a impressão de que eu ESTUDEI 419
módulos quando eu CONTEI 419 e estudei um.)*

## O censo é o INSTRUMENTO, não o produto

O número não vai a lugar nenhum sozinho: ele serve para **escolher o espécime** —
qual arquivo do core merece ser aberto. Quem os produz é
**[`tools/pp-uses.sh`](../../tools/pp-uses.sh)** (roda o `harbour -x` sobre `work/` e
conta `ppApplications[]`; não é grep, e não entra no `hbrefactor`):

```
HB_BIN=<bin do branch> tools/pp-uses.sh
```

Ele imprime o que interessa aqui: **quais arquivos** concentram uso, **quais**
declaram DSL própria, **quais** geram regra ao compilar — e o rodapé honesto (nem
todo módulo dumpou). **Número novo nesta página só depois de re-rodar.**

---

# ESPÉCIMES ESTUDADOS

## 1. `tests/rddtest/rddtst.prg` — a DSL de teste do RDD

**O que é**: a bateria de testes do RDD escreve os casos numa **linguagem própria**,
declarada no próprio `.prg`. É o maior uso de DSL caseira do corpus.

**As diretivas** (linhas 26-35):

```harbour
#ifdef _TEST_CREATE_
  #command RDDTESTC <*x*>          => <x>; rddtst_wr( #<x> )
  #command RDDTESTF <x>            => rddtst_wr( #<x>, <x> )
  #command RDDTEST  <*x*>          => RDDTESTC <x>
  #command RDDTEST  <x>            => RDDTESTF <x>
#else
  #command RDDTESTC <s>, <*x*>     => <x>; rddtst_tst( #<x>, <s> )
  #command RDDTESTF <r>, <s>, <x>  => rddtst_tst( #<x>, <s>, <x>, <r> )
#endif
```

**O que ele ensina — três fatos, cada um confirmando uma família da DEFINIÇÃO:**

- **O `#<x>` (strdump) sobre o MESMO nome que a regra avalia.** Em `RDDTESTF`, o
  `<x>` é **estringificado** (`#<x>` — vira o rótulo do teste, o texto que o
  programador escreveu) **e clonado** (`<x>` — é executado). Um nome, dois destinos.
  É, letra por letra, a forma da família [strdump.md](strdump.md) — o mkind que o
  corpus dava como **inexistente em regra** até 2026-07-13. **O uso real derrubou o
  veredito da definição**, e é essa costura que faz o corpus ser um corpus.
- **A regra que expande em OUTRA regra caseira**: `RDDTEST` → `RDDTESTC`/`RDDTESTF`.
  Multi-passe ([rule-structure.md](rule-structure.md)) em código de produção.
- **Duas regras RIVAIS com a mesma cabeça, uma por ramo de `#ifdef`** — e aridades
  diferentes (`<x>` × `<r>, <s>, <x>`). O `-D` escolhe qual existe; **o dump só
  enxerga a ativa**, e a outra não está em oráculo nenhum.

> ⚠️ **É deste espécime que sai a lacuna mais grave em aberto (fase P17 do
> [roadmap](../roadmap.md)):** o `rename` da cabeça edita o ramo visível e os usos,
> **deixa o ramo desligado com o nome velho, e anuncia sucesso** — e o outro build
> para de compilar. **A ferramenta grava uma árvore quebrada e diz que está tudo
> certo.** Repro mínimo e critério de pronto no roadmap. *(Marcado, não consertado:
> regra PROVE-MARQUE-SIGA.)*

## 2. `contrib/gtwvg/class.prg` — o módulo que se ESTENDE enquanto compila

**O que é**: o módulo que mais gera regra do corpus — **285 diretivas nascem durante
a própria compilação dele** (o `#xcommand METHOD` do `hbclass.ch` **cria uma regra
nova** para cada método declarado, para depois casar a implementação).

**O que ele ensina**: a genealogia de regra (`ast-13`) **não é caso de laboratório** —
é o que acontece em todo módulo que declara classe, e classe é a maior parte do
Harbour. O fato "esta regra foi gerada por aquela aplicação" tem consumidor real.
→ [generated-rules.md](generated-rules.md) · [class.md](class.md)

## 3. `tests/clsscope.prg` (e irmãos: `clsccast`, `clsicast`, `speedtst`) — a DSL que REDEFINE a linguagem

**O que é**: um `.prg` de teste que **sobrescreve o `?` e o `QOut` do Harbour** com
`#xtranslate` próprio, para capturar o que seria impresso em vez de imprimir.

**O que ele ensina**: uma diretiva pode **substituir a saída padrão da linguagem** —
e o compilador nem fica sabendo (para ele, sempre foi assim). **Consequência para o
produto**: naquele módulo, o `?` **não é o `?` do Harbour**, e a ferramenta hoje não
diz isso a ninguém. *(Marcado como aviso faltante na fase P16 — o fato está no dump;
o relato não existe.)*

---

# ESPÉCIMES NA FILA (contados, ainda NÃO estudados)

Honestidade de estado: o censo os apontou; ninguém abriu ainda.

| espécime | por que ele foi apontado |
|---|---|
| `rtl/tbrowse.prg`, `rtl/tget.prg` | os módulos de RTL mais densos em pp; `_TBCI_*`/`GET_CLR_*` — DSL de campo de estrutura |
| `tests/rto_get.prg` | `#xtranslate TEST_LINE` — a DSL de teste mais usada depois do `rddtst` |
| `contrib/gtwvg/wnd.prg`, `crt.prg` | densidade de pp altíssima; classe + DSL própria juntas |
| `hbhttpd` | corpus moderno (código novo do ecossistema), ainda intocado aqui |
| os **13 módulos que NÃO dumparam** | faltam includes de contrib — **é preciso fechar isso antes de qualquer número novo** |

> **ANTES DA FILA ACIMA, porém: os testes do PRÓPRIO pp** *(indicação do Diego)* —
> `tests/pp.prg`, `tests/pragma.prg`, `tests/ppapi.prg` e `tests/hbpp/`. O censo acha
> onde o pp é MUITO usado; esses acham onde ele é usado **no limite, de propósito**,
> por quem o construiu. Detalhe do que há em cada um: [METODO.md](METODO.md) § 2b.

# Lacunas

> Classificação por FATO (VERIFICADO). Regra: PROVE, MARQUE e SIGA ([README.md](README.md)).

- **[LACUNA REAL — fase P17]** as diretivas puladas por compilação condicional não
  existem em oráculo nenhum, e o `rename` **quebra o código** por causa disso
  (espécime 1, repro no roadmap). O pp **sabe** que pulou (`iCondCompile`) e não conta
  → experimento de core, sob autorização.
- **[Consumo futuro — VERIFICADO]** módulo que **redefiniu a linguagem** (espécime 3)
  não é anunciado a ninguém. Fato no dump (a regra, com arquivo e linha); aviso
  inexistente → fase **P16**.
- **[Medição incompleta, honesta]** 13 dos 432 módulos não dumparam. Enquanto isso não
  fechar, todo censo é parcial — e a sonda diz isso na primeira linha, de propósito.
