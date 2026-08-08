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
| **P30** | dois `STATIC` de mesmo nome no mesmo `.prg` renomeiam por POSIÇÃO; a coleta file-wide respeita a sombra |
| **P28** *(3 fatias)* | `static` e `memvar` escritos por diretiva renomeiam os dois lados; a fatia 1 (relato) virou andaime e saiu |
| **matriz de homônimos** | 6 casos SEM diretiva: local sombreando, param, static de outro módulo, dois criadores, uso fora do alcance, campo de área de trabalho |
| **prova do memvar** | recusa falsa consertada: módulo NÃO editado exige byte-identidade (mais duro), módulo editado aceita um símbolo trocado |

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

### 2.1 A P29 — dois criadores PRIVATE, recusa larga demais *(nasceu 2026-08-08)*

Spec com tabela de sondas na
[P29 do roadmap](roadmap.md#p29--dois-criadores-private-a-recusa-é-larga-demais). Em uma
frase: a ferramenta JÁ separa o alcance de cada criador e joga a distinção fora, recusando
igual quando os alcances são disjuntos (decidível) e quando se cruzam (aí sim ambíguo).

**Não falta fato nem edição — falta PROVA.** Acrescentar um símbolo renumera a tabela e muda
o pcode de funções intocadas (`HB_P_PUSHMEMVAR` indexa `pSymbols`). Precedente para a prova
nova: o `symbols-preserved` do `reorder-params`.

### 2.2 A P31 — o lado direito de uma diretiva não é UM símbolo *(nasceu 2026-08-08)*

Sondada em três rodadas (escopos misturados; funções estáticas; diretivas INDIRETAS do
`doc/pp.txt`, em 2 e 3 níveis). A cadeia do Diego — "se temos usage com escopo, temos
rename" — **está medida e já implementada**: rename começando no lado direito produz o mesmo
conjunto, e a genealogia atravessa regra que gera regra. A P31 virou 4 itens concretos
(diagnóstico multi-ligação, mapa nas recusas, o rollback que culpa o inocente, a declaração
file-wide no `usages`); **qual entra e em que ordem é decisão dele.**
*(2026-08-08, P32 corpo: o item 3 está PAGO — a prova por-módulo matou o culpa-ao-inocente —
e a metade "funções" do item 2 também, via `directive-binds-static-and-dynamic`. Restam o
item 1, a metade memvar do 2, e o 4.)*

### 2.3 A P32 — ✅ FECHADA (fatia 0 + corpo, 2026-08-08)

> Fatia 0 (`ast-24`: `symbols[]` + hashes por função, `HrbParse` morto) e o
> corpo (arraste por módulo-aplicador, duas pontas iguais por `DeepEqual`,
> misto com `directive-binds-static-and-dynamic`, prova POR MÓDULO no
> `rename-function`, caso pinado invertido, execução idêntica dentro do
> próprio caso Go) entregues no mesmo dia. Registro completo na P32 do roadmap. A prova
> por-módulo consertou também a homônima SEM diretiva (reprovava injusto), e
> pagou o item 3 da P31 + a metade "funções" do item 2. **A P29 tem o fato
> dela (`pcodeNormHash`) esperando.** Saiu do §2 — resta commit.

Ordem do Diego ("quero"), e a natureza dela mudou DUAS vezes até a forma final — as três
versões estão datadas na [P32 do roadmap](roadmap.md#p32--renomear-a-função-estática-que-uma-diretiva-chama):

1. eu disse "o core precisa estampar a resolução em `calls[]`" → sonda desmentiu: o vínculo
   já está nos 2 bytes de escopo do símbolo no `.hrb` (`HB_FS_STATIC`, forward e controle
   negativo medidos);
2. "então lê-se do `.hrb`" → o Diego apontou o drift de um leitor próprio de formato alheio,
   e depois perguntou *"o quanto já pode vir da compilação?"* → inventário: as provas leem
   só nome, escopo e IGUALDADE de pcode — tudo que o compilador sabe ao compilar;
3. **forma final (fatia 0): `ast-24`** — o dump ganha `symbols[]` (nome+escopo) e hash de
   pcode por função; o `HrbParse` MORRE e **nenhum leitor de `.hrb` nasce**; byte-identidade
   continua crua sobre o artefato; o drift morre pelo schema que berra (caso 122). É
   extensão de core SIM — do canal que já é o padrão da casa, o dump.

O corpo da fase: rename da static citada no result arrasta as homônimas dos módulos que
APLICAM a regra + o header; módulo que não aplica fica byte-idêntico; prova por-módulo (mata
o culpa-ao-inocente); misto static/dinâmico recusa com mapa. Na entrega, o caso pinado
`refuse-rename-static-function-cited-by-directive` inverte.

### 2.4 A página pública (`site/index.html`) — ADIADA pelo Diego

O manual foi atualizado (baseline `a97c00d`, dois itens novos em *Still rough*). A página é
derivação mecânica dele e **não** precisa de segunda aprovação — mas o Diego adiou em
2026-08-08 ("o manual ainda não"). Retomar daqui.

*(O ponteiro do `CHANGELOG.md` saiu desta lista: foi movido para `a97c00d` depois de escritas
as duas entradas que faltavam — as posições dos usos que a diretiva escreve, e a linha crua
nos resultados `--json`.)*

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
- **Sonda começa por `mktemp -d` + `git init`/`commit`, nunca por `mkdir` seu.** A
  ferramenta EDITA os fontes, então pasta de sonda é de uso único; reusar faz o "antes"
  ser o "depois" da medição anterior, e a medição SAI, com cara de resposta. Aconteceu
  três vezes em 2026-08-08. *(A receita está no [CLAUDE.md §1.7.8](../CLAUDE.md); o
  `tools/probe.sh` que eu escrevi para isso foi deletado — reimplementava o git e
  contaminou uma medição por conta própria.)*
- **Nada de `git add -A`** — nomear arquivo por arquivo é o que evita varrer trabalho de
  outra sessão para dentro do seu commit.
- **`docs/roadmap.md` é escrito pelas duas sessões.** Reler antes de escrever.
- **Número de schema é disputado:** a P24 reservou `ast-22`, a fase X entregou primeiro e
  o consumiu, e a P24 virou `ast-23`. Confira o `HB_AST_SCHEMA` do fonte antes de reservar.
- **A régua do caso 64 vale para COMENTÁRIO** — citar a palavra de uma fixture num
  comentário de `src/hbrefactor.prg` quebra a suíte, e está certa em quebrar. Ilustre o
  formato genericamente. *(Caí nisto de novo em 2026-08-07, ao traduzir comentário.)*
