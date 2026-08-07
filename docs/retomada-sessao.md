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

Mais: os dois toolchains viraram dependência do projeto (`make stock`,
`make pcode-identity`), o build limpo do core parou de deixar a árvore sem compilador,
e nasceram três portões — `tests-go/shell` (pipefail), `stock-check`, e o build do
hbrefactor reprovando qualquer `Warning`.

---

## 2. ⚠️ O QUE AINDA NÃO FECHOU — e é por isto que este arquivo existe

### 2.1 A P27 — renomear o nome escrito no RESULTADO de uma regra

Spec escrita, com a tabela de sondas, na [P27 do roadmap](roadmap.md). **Falta implementar.**
Ela nasce destravada pela P24 (o sítio diz de qual aplicação veio, então o dump responde
quais locais de quais módulos a regra liga) e pela P25 (a ferramenta já ACHA o outro lado; a
P27 a faz EDITAR).

**Alcance decidido pelo Diego, duas vezes:** não há recusa por dono do arquivo — se o `.hbp`
alcança a regra, edita, inclusive `.ch` do próprio Harbour. A responsabilidade é de quem
refatora. O que a ferramenta deve é **relatar** que o arquivo é externo. `(builtin)` recusa,
e não por política: não há arquivo.

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
