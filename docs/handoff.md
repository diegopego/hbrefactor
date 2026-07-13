# Handoff — onde o trabalho parou, e como retomar

Companheiro do [prompt-revisao-anti-heuristica.md](prompt-revisao-anti-heuristica.md)
(que cobre a **P-AUDIT**, e só ela). Este cobre **o resto**.

> **Este documento é um INSTRUMENTO, não um relatório de estado.** O estado vive no
> `docs/roadmap.md` e no `docs/pp-corpus/ROADMAP.md` — e é lá que se lê, sempre. Se
> algo aqui contradisser o roadmap, **o roadmap ganha**: um segundo lugar guardando os
> mesmos fatos envelhece e vira fonte de verdade concorrente. Aqui só entra o que o
> roadmap NÃO diz: qual é a próxima sessão, o que ela precisa saber que não está
> escrito em lugar nenhum, e onde ela vai tropeçar.

---

## 0. ⚠️ HÁ TRABALHO NÃO-COMMITADO NOS DOIS REPOS (2026-07-13)

**Suíte 990/0.** Nada foi commitado — commit é autorização por-commit do Diego, nos dois
repositórios.

**No `harbour-core` (`utils/hbmk2/hbmk2.prg`): comando NOVO `hbmk2 --hbproject[=nested]`.**
Devolve, em JSON, **de que um projeto é feito** — `sources` (`.prg` e `.hbx`), `incpaths`,
`prgflags` — tudo já resolvido pelo builder (`.hbp`/`.hbc`/`.hbm`, `-i`, `${macros}`,
filtros), **um bloco por alvo**, e **sem buildar nada**. O `--hbinfo` ficou **byte-idêntico**
(ordem do Diego: *"se mudar a saída de algum comando, crie um comando novo"*).

**No `hbrefactor` (`src/hbrefactor.prg`, `tests/run.sh`):** o `LoadProject` consome esse
canal; o **`CmdTokens` morreu**; e o **caso 124** trava a recusa de projeto com fontes de
**basename homônimo**.

**Escrito e pronto:** entrada no `CHANGELOG.md` (a recusa nova) e no `NEWS.md` do core (o
`--hbproject`). Ponteiro do CHANGELOG avançado para `hbrefactor@304cfa8`; **ao commitar,
avance os dois ponteiros de novo** para os SHAs novos.

**PENDENTE DE OK DO DIEGO — o delta do `docs/manual.md`** (a skill `/update-manual` exige
aprovação site a site; foi proposto e NÃO aplicado). Dois sítios:
(1) *"the tool uses the already-resolved command"* → passa a *"asks hbmk2 (`--hbproject`) and
reads the answer as data"*; (2) o limite *"two modules with the same filename … can get
confused"*, hoje em **Still rough**, é **falso** — vira recusa deliberada e **permanente** em
*What it never does*. Aplicado o manual, a `site/index.html` do hbrefactor se regenera (é
derivação mecânica, não pede segunda aprovação).

**Recomendação registrada:** o `--hbproject` deve ser **PR SEPARADO** do PR da AST (B6) — é
pequeno, não-controverso e vale sozinho; é o mesmo argumento do `-ge2` (fase A.4). A landing
page do core **não muda** (o conceito não mudou; ela escopa o diff em `src`/`include`, e o
hbmk2 é `utils/`).

## 0b. A LIÇÃO DESTA SESSÃO, e ela é a regra agora (CLAUDE.md § 1.2)

**ESTENDER O CORE É O CAMINHO PADRÃO, NÃO A EXCEÇÃO** *(Diego)*: identificada uma
necessidade, a pergunta é *"como o core passa a responder isto?"* — nunca *"como me viro com
o que ele já dá?"*. **Para PROJETO, o hbmk2 é SEMPRE a fonte de verdade** (build, quais
arquivos compõem o projeto, includes, flags). Nasceu daí o **gatilho 7**: *OBSERVAR o core
(raspar log, trace, efeito colateral de build) em vez de PERGUNTAR a ele*.

O `LoadProject` era o retrato disso: raspava a linha *"Harbour compiler command"* do
`-traceonly`, que lista os fontes **a recompilar** — não os do alvo — e por isso carregava um
`-rebuild` que **recompilava o projeto inteiro só para descobrir de que ele era feito**.
Cicatrizes § 1.3c. **E a § 1.3d é sobre mim:** quando o Diego deu o veredito, eu respondi
*"você está certo, mas…"* — defesa, não precisão. Ele pegou na hora. **Veredito dele sobre o
meu trabalho → aceitar e executar; se a nuance importa, ela aparece no código.**

## 0c. O ROADMAP FOI ARQUIVADO (2026-07-13) — leia o novo, não o que você lembra

`docs/roadmap.md` foi de **1.495 para ~440 linhas**. Ele estava violando a própria regra de
manutenção: era quase todo narrativa de coisa já entregue, com a intenção viva enterrada no
meio. As narrativas foram **verbatim** para
[roadmap-fases-entregues.md](roadmap-fases-entregues.md).

> **Ao arquivar, EXTRAIA as pendências vivas primeiro** — a regra agora está escrita no topo
> do roadmap. Quase enterrei a P12 (que dizia *"NADA PROVADO AINDA"*) junto com a fase P, que
> estava marcada como ENCERRADA. **Fase encerrada pode conter trabalho aberto.**

Consertados no caminho: a seção *Fundação* (a que manda "não re-derivar") afirmava schema
`ast-8` com o core em `ast-16`; e um link para um arquivo que não existe.

---

## 1. A PRÓXIMA sessão, nesta ordem

**1.0 — A FASE A.1 (contrato de máquina), SE o Diego abrir o portão.** É o próximo passo
recomendado, e a razão é uma linha de código, não um argumento: **a entrega da A.2 AUMENTOU a
dívida que a fase A existe para pagar.** Para oferecer o rollback no `BROKEN`, o primeiro
consumidor do comando novo já casa **prosa em inglês** para decidir fluxo — `extension.js:368`,
`/BROKEN/.test(...)`. São **quatro** regexes agora (`:235`, `:280`, `:290`, `:368`), e cada um
quebra calado no dia em que alguém reescrever a mensagem. **A ferramenta proíbe comparação de
texto no motor e obriga comparação de texto no consumidor** — é essa contradição que o A.1 fecha.

O **levantamento do drift já está feito** (spec § 2.4), e ele é **assimétrico** — não repita o
meu erro de apresentá-lo como duas decisões simétricas ao Diego:

- **`usages` com zero hits deixa de sair `1`: quase NÃO há drift.** Varridos os 100 sítios da
  suíte — **nenhum teste depende disso**. O único que exige exit ≠ 0 (`run.sh:2356`) é uma recusa
  de verdade e continua recusando.
- **A morte do `--json <arquivo>`: é aqui que está o trabalho** — 17 sítios na suíte, 4 comandos
  no fonte, 2 fluxos da extensão que escrevem num temp e leem de volta. Não é difícil; é volume.

**Ainda assim, os dois são DECISÃO DO DIEGO** (regra do drift em teste pré-existente). Leve-os a
ele **antes** de escrever a primeira linha. Critério de pronto:
[spec-a-oraculo-para-agentes.md](spec-a-oraculo-para-agentes.md) § 2.

**1.1 — Migrar os quatro transcripts colados à mão da página para `tests/site/`.**
As seções profundas (rename de `DATA`, genealogia de regra, tempo de vida de diretiva,
sequestro por abreviação) ainda têm saída **digitada** — corretas hoje, mas **FORA do portão**
do `make site-check`, e é exatamente assim que as anteriores apodreceram (uma chegou a exibir
mensagem em português depois que a CLI virou inglês, e nenhum teste acusou).

**1.2 — P12 + P13 (exploração; destravam-se mutuamente — rode JUNTOS).**
O `ast-16` entregou o **tempo de vida da diretiva** (o dump diz que uma regra foi removida, e
**qual**). Isso destravou o P12: ele precisava injetar uma regra de **consulta**, deixá-la
casar e **tirá-la da mesa** antes que contaminasse o build. Era o mecanismo que faltava.

**É exploratória — não é entrega.** Saída legítima inclui *"não dá, e eis a varredura que
prova"*. Toda recusa sobre o core exige varredura REGISTRADA (`--help` inteiro, API pública,
`tests/` do core, ChangeLog) — porque *"não achei" quase sempre é "não procurei"*, e isso já
custou um veredito errado publicado.

Prompt para colar:

> Você vai **explorar** (não entregar) duas fatias da fase P, que se destravam
> mutuamente. Leia antes, nesta ordem: `CLAUDE.md` (§ REGRA DO FATO e § GATILHOS),
> `docs/pp-corpus/pp-as-search.md` (P12), `docs/pp-corpus/directive-scope.md` § 4 (P13)
> e `docs/ast-schema.md` (em especial `undoes`/`removed`, do `ast-16`).
>
> **P12 — o preprocessador como ENGENHO DE BUSCA.** A ideia do Diego: o pp já é um casador
> de padrões industrial, e nós o usamos só para expandir. Um `#xcommand` é uma *query*. A
> pergunta a sondar: **dá para injetar uma regra cuja única função é RECONHECER (não
> reescrever), rodá-la sobre o código, colher os sites, e removê-la** — sem que ela vaze
> para o build? O mecanismo de remoção existe desde o `ast-16`; use o **pp vivo**
> (`__pp_init` / `__pp_process`, como o P11 fez em `c391408`), nunca o `.ppo` destrutivo.
>
> **P13 — os USOS que o escopo de diretiva promove.** O pedido textual do Diego está no § 4
> do `directive-scope.md`. A pergunta que ele levantou: *dá para injetar diretiva num **bloco
> arbitrário** e desligá-la depois?* Cuidado: o pp é **linha a linha**, então "escopo" aqui é
> **posicional**, não sintático — sondar o limite honesto disso é metade da fatia. As **três**
> famílias de remoção contam (`#undef` inclusive; foi a que eu esqueci, e o Diego pegou).
>
> **Método:** probe executável, sempre. Fixture `.prg` que compila limpo sob `-w3 -es2`
> (exportar `HB_BIN`!). Nada de conclusão por leitura de fonte. Registre o que sondou e
> **não** funcionou.
>
> **Saída:** o que o pp PODE fazer (com o probe que prova), o que ele NÃO pode (com a
> varredura que sustenta a recusa), e o que isso habilita no hbrefactor. **Não construa verbo
> novo** — isso é portão do Diego (D-P5).

**1.3 — P-DOC**: próxima família do corpus do pp = um contrib (por medição). Famílias 1-4
entregues. Regra dura do Diego: **lacuna real PAUSA a exploração e vira experimento de core
imediato**.

---

## 2. O que é DECISÃO DO DIEGO, e não deve ser "resolvido" por iniciativa

- **Os commits desta sessão** (§ 0), nos dois repos — e o **delta do manual**, que está
  proposto e aguardando OK.
- **Portão D-P5 — migração de DSL como verbo novo.** Desenho pronto (`roadmap.md`, Eixo B),
  barrado por duas regras do projeto, não por dificuldade: verbo novo exige portão dele, e o
  critério do `adr-003` (*"fato sem consumidor = fato local, não arquitetura"*). O instrumento
  já existe e está provado (P11, o pp vivo). Espera desde 2026-07-12.
- **B6 — limpeza do diff do PR.** Só quando ele for abrir o PR. O roadmap § B6 carrega a
  **retratação** de um achado meu que era falso (comparei contra um `master` local sete
  commits atrasado e acusei o upstream) — leia antes de tocar no assunto. **A base é
  `upstream/master`, com `git fetch` antes.**
- **Commit no core e push:** autorização **por-commit**, sempre. Não encadear.

---

## 3. Onde você vai tropeçar (custou caro, não está óbvio no código)

- **O hook `.claude/hooks/anti-heuristica.sh` está CERTO mais vezes do que você vai querer
  admitir.** Nesta sessão ele barrou o commit e o achado era **real**: eu classificava flags
  por prefixo de texto (`Left(cTok,2) == "-o"`) para descartar ruído — e o ruído não devia ter
  vindo. O conserto foi **no core** (o `--hbproject` deixou de emitir o `-o`/`-q`, que são
  plumbing do hbmk2), e o hook passou. **Leia a mensagem dele antes de pensar em contorná-la.**
  *(Cuidado com um efeito colateral bobo: ele é PreToolUse e casa a string `git commit` no SEU
  comando — um `echo "... git commit ..."` dispara o hook ANTES do seu `git add` rodar, e você
  vai depurar um índice velho achando que é bug do hook.)*
- **`make` do harbour-core FALHA no contrib `hbwin`** (`windows.h`, `olectl.h` — Windows-only).
  É **pré-existente e alheio**; o `harbour` e o `hbmk2` são regravados normalmente. Não tente
  "consertar". *(Mesma família do `gtwvg`, que não compila neste Linux — e que já me fez
  publicar um benchmark de um comando abortado.)*
- **Ao mexer no hbmk2, rebuildar apagando o binário** (`rm -f bin/linux/gcc/hbmk2 && make`) — o
  `make` mente "up to date". E o hbmk2 **embute o compilador**: mudou o compilador, rebuilde os
  dois.
- **`git checkout -- <arquivo>` destrói trabalho não-commitado, e é irreversível.** Teste em
  **cópia no scratchpad**, nunca no fonte real.
- **O shell é `zsh`**: `for x in $VAR` **não** faz word-splitting como no bash. Uma régua de
  verificação minha "passou" por vacuidade por causa disso.
- **`bin/` é lixo de build (ignorado); `tools/` é o que se versiona.** Escrevi dois scripts em
  `bin/`, "commitei", e o `.gitignore` os engoliu — as mensagens de commit afirmavam o que não
  existia.
- **A suíte grepa as mensagens da ferramenta** (é o contrato). Mexeu numa string de saída →
  asserção quebra, e está CERTA em quebrar. A extensão casa a mensagem do CLI em
  `extension.js`, com o harness (`vscode/test-resolveat.js`) assertando essa string **no fonte
  dela**. Três lugares, sempre juntos.
- **NUNCA edite entre os marcadores `SITE-EX:*:BEGIN/END`** do `site/index.html` — são
  gerados; a próxima execução sobrescreve e o portão acusa.
- **Antes de escrever entrada de CHANGELOG, CONFIRA se a sessão da entrega já escreveu uma.**
  Eu dupliquei a entrada da P-AUDIT por não olhar primeiro; a regra da skill é *conferir e
  completar*, não duplicar.
- **Repetir o experimento no LIMPO antes de anunciar bug.** Nesta sessão eu escrevi no roadmap
  um "bug do container" que **não reproduz** — o que eu vira acontecera num diretório sujo de
  builds que haviam falhado na minha própria sonda. A retratação está lá. **Bug não existe até
  que alguém o reproduza.**
