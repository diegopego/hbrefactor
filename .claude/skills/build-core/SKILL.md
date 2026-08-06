---
name: build-core
description: Rebuilda o harbour-core (branch feature/compiler-ast-dump) do jeito que este repo aceita — LIMPO, harbour e hbmk2 juntos, parser sincronizado, e conferindo que os binários de fato relincaram. Use depois de editar o compilador/pp/RTL do core, ou a gramática. Não commita nada (commit é autorização por-commit do Diego).
disable-model-invocation: true
---

# build-core — o build do core é `make core`

```bash
make core            # é isto. Não há segundo jeito.
make core JOBS=4     # paralelismo (default 8)
```

## A regra, e ela não tem exceção

**Build incremental do core NÃO SE USA** *(Diego, 2026-08-06: "não se deve usar a
compilação incremental para evitar surpresas. isso se aplica ao harbour e ao
hbmk2")*. O `make` do core **não rastreia `#include`**: editar um header — ou um
`.c` que outro inclui, como o `include/hbexprb.c` — e rodar `make` sai **exit 0
sem recompilar nada**.

O sintoma é o pior que existe: **a medição roda, responde, e a resposta é do
binário velho**. Custou dois diagnósticos errados numa sessão, um deles uma
teoria inventada sobre a gramática para explicar um binário que não tinha a
mudança ([cicatrizes §5.1](../../../docs/cicatrizes.md)).

A régua anterior — *"apague os `.o` certos"* — era disciplina, e ainda exigia
adivinhar quais objetos o header alcança. Morreu. **Rode `make core`.**

## O que o alvo faz por você

**Está no `Makefile` do hbrefactor, não num script à parte** *(Diego, 2026-08-06:
"é preferível do que ter scripts espalhados")*.

| passo | por quê |
|---|---|
| resolve o core por `tools/hbenv.sh` | fonte única; caminho cravado envelhece (§1.4) |
| regenera o parser quando `harbour.y` > `harbour.yyc` | `HB_REBUILD_PARSER=yes` regenera o artefato de build, **não** os `.yyc/.yyh` COMMITADOS — que são o que um checkout limpo usa. Aqui é **dependência do make**, que é aquilo de que o make é feito |
| apaga `harbour` **e** `hbmk2` | o hbmk2 **EMBUTE** o compilador (linka `libhbcplr`); hbmk2 velho emite dump de schema antigo mesmo com harbour novo |
| `make clean && make` | a regra acima |
| **confere que os dois relincaram** | build que "passou" sem produzir binário novo é justamente o modo de falha procurado |
| **confere o SCHEMA dentro dos dois binários** | o conjunto de `ast-N` no binário tem de ser exatamente o que o `compast.c` declara; sobrou outra versão = objeto velho linkado |

## `make core-check` — a mesma conferência, em 1s, sem rebuildar

```bash
make core-check      # "o binario que eu estou medindo e' o do fonte de agora?"
```

É a pergunta cujo NÃO responder custou os dois diagnósticos errados. Rode antes de
confiar numa medição, e sempre que voltar a uma sessão sem saber o que ficou
buildado.

Ter alvo próprio é também o que torna a guarda **testável**: os controles negativos
(binário velho, binário ausente, schema fora de passo) rodam contra ele em segundos,
não contra um rebuild de minutos. Os três foram rodados e reprovam de verdade.

## O que ele NÃO faz — e por quê

- **Não commita.** Commit no core é autorização por-commit do Diego (§6). Mexeu
  na gramática? **Commite os TRÊS juntos** (`.y` + `.yyc` + `.yyh`) — só o `.y`
  deixa o parser commitado fora de passo.
- **Não mexe no `NEWS.md` nem na landing page do core** — isso é o pipeline
  `commit → NEWS.md → site` (skill `/update-manual`, CLAUDE.md §5).
- **Não decide** se a mudança no core é a certa: só a materializa em binário
  confiável.

## Depois

- `make test` no hbrefactor: o **caso 122** fica vermelho na hora se core e
  ferramenta divergirem de schema (§1.5).
- `git -C "$(sh tools/hbenv.sh --print HB_CORE)" status` antes de qualquer commit
  — e confira que nenhum `.d`/`.ppo`/`.c` vazou (§2).
