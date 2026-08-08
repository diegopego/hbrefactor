# Retomada — o que esta sessão abriu e ainda não fechou

**Este arquivo vive até a ÚLTIMA tarefa desta sessão fechar** *(Diego, 2026-08-07:
"quero que o roadmap desta sessão exista até que todas as tarefas desta sessão sejam
concluídas, incluindo as novas tarefas que possam ter sido criadas ao longo da nossa
conversa")*. Não some quando a frente principal entrega — some quando o §2 esvaziar.

> **Erro que gerou esta regra:** a primeira versão dele (`retomada-posicao-do-sitio.md`)
> dizia *"some quando a P24 fechar"*. A P24 fechou e eu o apaguei — seguindo a LETRA da
> minha própria nota em vez do PROPÓSITO dela, que era não perder trabalho entre sessões.
> A sessão continuava, e já tinha estado novo (a P25 nasceu depois, a P26 também).

> **Não é fonte de verdade concorrente.** Fase entregue vira registro no
> [`roadmap.md`](roadmap.md); mecanismo, em [`posicao-do-sitio.md`](posicao-do-sitio.md);
> regra, no [`CLAUDE.md`](../CLAUDE.md). Aqui só entra o que **ainda não fechou** e o que
> a próxima sessão precisa saber para retomar.

---

## 1. O QUE ESTA SESSÃO ENTREGOU (fechado, não mexer)

| fase | o quê |
|---|---|
| **P21** `ast-21` | a posição de um sítio vem do PARSER, não de contagem |
| **P24** `ast-23` | o sítio vindo de diretiva aponta a aplicação dela (40% dos sítios) |
| **P25** | a recusa CONTA a causa: `diagnostics[]` nomeia o `.ch` que escreve o nome |
| **P26** | o `text` do envelope é VERBATIM — `text[start:end]` volta a recortar a palavra |
| **P27** *(commit `3ad98db`)* | o nome escrito no RESULTADO de uma regra se renomeia, pelas duas pontas |
| **P28 fatia 1** *(mesmo commit)* | recusa de `static`/`memvar` diz qual `.ch` escreve o nome |

Mais: os dois toolchains viraram dependência do projeto (`make stock`,
`make pcode-identity`), o build limpo do core parou de deixar a árvore sem compilador,
e nasceram três portões — `tests-go/shell` (pipefail), `stock-check`, e o build do
hbrefactor reprovando qualquer `Warning`.

**E TRÊS portões MORRERAM na P27, cada um medido antes** *(registro completo na P27 do
roadmap)*: o `--edit-rules`, o veto por dono do arquivo (`ProjectOwnsFile` nos caminhos de
edição de diretiva) e a regra 2 do hook anti-heurística. Os dois primeiros cobravam pedágio
sem fato atrás; o terceiro acusava 54 linhas do fonte e nenhuma era heurística.

---

## 2. ⚠️ O QUE AINDA NÃO FECHOU — e é por isto que este arquivo existe

### 2.1 A P28 — a diretiva que escreve um STATIC ou um MEMVAR *(nasceu nesta sessão)*

Spec com a tabela de sondas na
[P28 do roadmap](roadmap.md#p28--a-diretiva-que-escreve-um-static-ou-um-memvar). São TRÊS
fatias, e a ordem foi decidida medindo os dois verbos por dentro.

| fatia | o quê | estado |
|---|---|---|
| **1 — o relato** | recusa de `static`/`memvar` passa a dizer qual `.ch` escreve o nome | ✅ **ENTREGUE 2026-08-07** |
| **2 — o static** | o motor da P27 alcança `static` e edita os dois lados | **A FAZER** |
| **3 — o memvar** | idem para `private`/`public` | **A FAZER, e o tamanho é DESCONHECIDO** |

**Fatia 1, entregue.** `DiagRuleWritesApplied()` emite a regra como `diagnostics[]` nas
recusas dos dois verbos. O gatilho é **aplicação**, não menção: uma regra só REGISTRADA num
módulo que nunca usa o comando não causou nada ali, e relatá-la foi o erro que matou o
`DiagRuleWrites` antes. Casos: `refuse-rename-static-written-by-directive` e
`refuse-rename-memvar-written-by-directive` (dois, porque são dois sítios de chamada — um
não pega o outro emudecendo).

**Fatia 2 é repetição de caminho já andado.** O `rename-static` tem a MESMA forma que o
`rename-local` tinha: guardas, laço que junta posições, dedup. Foi daí que saiu o
`LocalScan`; sai igual.

**Fatia 3 é diferente, e por isso está por último.** O `rename-memvar` **não** é um coletor
de posições: ele calcula o alcance de quem criou a variável, monta o grafo de funções que
rodam com ela viva, recusa se o alcance tem buracos, e trata criação por macro. Antes de
propor mecanismo é preciso **medir** se aquele alcance continua valendo com as edições do
`.ch` dentro do conjunto. *(A suspeita do Diego de que "cada caso tem uma complexidade" se
confirma AQUI — e não por falta de prova, como eu tinha escrito, mas porque o verbo faz
muito mais coisa.)*

### 2.2 Duas dívidas que a P27 abriu e não fechou

- **O hook anti-heurística não tem teste.** Ele é um portão que ninguém verifica, e a P27
  mexeu nele (apagou a regra 2). Eu propus escrever o teste; o Diego autorizou só o apagar.
  Fica: um diff com a aritmética de abreviação tem de BARRAR, um com `Len( aArgs ) < 6` tem
  de PASSAR.
- **O ponteiro de baseline do `CHANGELOG.md` está parado em `e3efe33`**, com 13 commits
  depois dele — e há entradas de 2026-08-07 que parecem descrever parte deles. Ou o ponteiro
  ficou para trás, ou as entradas foram escritas sem movê-lo. **Não mexi**: mover sem saber
  o que ele já cobre quebra a retomada, que é justamente o que ele existe para dar. Conferir
  antes de escrever a próxima entrada.

---

> **O que estava aqui e NÃO era tarefa** *(limpo em 2026-08-07, depois de o Diego perguntar
> "não entendo qual é a pendência" em dois itens)*: o `push` (é dele, manual), o email
> placeholder do core (escolha dele, o GitHub cuida), o acervo em português (ele trata
> depois) e o tempo do `make core` (observação, ninguém pediu). **Eu havia enchido a lista
> de pendências com não-tarefas, o que derrota o propósito deste arquivo — não dá para ver o
> que de fato bloqueia.** Régua: entra no §2 o que ALGUÉM precisa FAZER; o resto é nota.

## 3. ONDE VOCÊ VAI TROPEÇAR

- **`make core-check` antes de confiar em qualquer medida** (1s). Responde *"o binário que
  eu estou medindo é o do fonte de agora?"* — a pergunta cujo não responder custou dois
  diagnósticos errados. Sobretudo ao voltar de uma pausa, porque **outra sessão pode ter
  rebuildado o core** (aconteceu: o schema pulou de `ast-21` para `ast-22` sem eu saber).
- **Sessões em paralelo disputam recursos globais:** `make core`/`make stock` mexem em
  binários compartilhados, e `make test` escreve em `tests/tmp/`.
- **Nada de `git add -A`** — nomear arquivo por arquivo é o que evita varrer trabalho de
  outra sessão para dentro do seu commit.
- **`docs/roadmap.md` é escrito pelas duas sessões.** Reler antes de escrever.
- **Número de schema é disputado:** a P24 reservou `ast-22`, a fase X entregou primeiro e
  o consumiu, e a P24 virou `ast-23`. Confira o `HB_AST_SCHEMA` do fonte antes de reservar.
- **A régua do caso 64 vale para COMENTÁRIO** — citar a palavra de uma fixture num
  comentário de `src/hbrefactor.prg` quebra a suíte, e está certa em quebrar. Ilustre o
  formato genericamente. *(Caí nisto de novo em 2026-08-07, ao traduzir comentário.)*
