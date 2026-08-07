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

Mais: os dois toolchains viraram dependência do projeto (`make stock`,
`make pcode-identity`), o build limpo do core parou de deixar a árvore sem compilador,
e nasceram três portões — `tests-go/shell` (pipefail), `stock-check`, e o build do
hbrefactor reprovando qualquer `Warning`.

---

## 2. ⚠️ O QUE AINDA NÃO FECHOU — e é por isto que este arquivo existe

### 2.1 P26 — `text` e `range` do mesmo sítio não compõem *(DECISÃO DO DIEGO)*

O `range` é absoluto no arquivo; o `text` vem sem os espaços da esquerda. Uma IDE que
destaque o trecho dentro do preview pinta os caracteres errados. Medido e registrado na
[P26 do roadmap](roadmap.md), com as duas saídas e a recomendação (**(a)** `text` vira a
linha crua). **Muda contrato publicado — não decidir por conta própria.**

### 2.2 Renomear nome escrito no RESULTADO de uma regra *(DECISÃO: abre fase ou não?)*

O `rename-dsl` cobre o lado do CASAMENTO (cabeça, palavra secundária, restrição) e recusa
o resto com motivo próprio — *"is not a match word of any project pp rule"*. Renomear o
`nAcc` de `=> nAcc += <v>` não é suportado. Levantado em 2026-08-07; o Diego confirmou
que **renomear o COMANDO já existe** (B4, `rename-dsl`, verificado rodando), então o que
falta é só este caso estreito. Não virou fase por não ter sido pedido.

### 2.3 Nenhum `push` foi feito, nos DOIS repos

Tudo local. A frente inteira (P21+P24+P25 e as entregas do core) está só nesta máquina.

### 2.4 O email do autor no core é um PLACEHOLDER

`{ID}+{username}@users.noreply.github.com`, em ~50 commits do branch — não só nos meus.
Para um branch upstreamável (fase B6) isso não passa, e corrigir significa reescrever a
autoria de todos eles. **Decisão do Diego.**

### 2.5 O acervo em PORTUGUÊS de código e commit *(DIEGO ASSUMIU)*

A regra mudou em 2026-08-07 (CLAUDE.md §5): **código e commit são inglês**; docs de
raciocínio seguem em português. Vale daqui pra frente — o acervo antigo o Diego disse que
trata depois. Arquivo misto durante a transição é esperado.
*(Os IDENTIFICADORES da infra de teste Go são portugueses — `registra`, `Projeto`,
`Roda`, `Aponta`. Renomeá-los é refatoração à parte.)*

### 2.6 `make core` ainda leva ~2min30

A janela sem compilador fechou; o custo não. Se incomodar, o caminho seria buildar num
diretório à parte. Não explorado, e não é urgente.

---

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
