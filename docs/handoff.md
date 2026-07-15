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

## 0. O ESTADO EXATO (2026-07-14, fim da sessão) — **LEIA ISTO PRIMEIRO**

**A frente ativa é o CORPUS DO PP, e ele mudou de MÉTODO.** Retomando o estudo do pp?
**Cole `docs/pp-corpus/METODO.md` inteiro** — é o prompt, e ele carrega o **modelo mental**
(o que o pp NÃO faz), os 10 passos e as armadilhas, cada um com exemplo real.

**A virada (Diego, 2026-07-14):** *"estes textos markdown vão apodrecer… o melhor dos mundos:
uma explicação em linguagem natural e comprovação via asserts, juntas, em `.prg`s"*. Logo:
- **o conhecimento mora no `.prg`**, que **compila, RODA e se afirma** (`hbtest` do core);
- o `.md` virou **índice + decisão** (curto);
- o comentário **INTERPRETA** o oráculo (não transcreve, não vira ensaio), e **cada afirmação
  tem assert que PASSA PELA DIRETIVA** — *se apagar a linha da diretiva e o assert continuar
  passando, o assert é decorativo*;
- **duas camadas**: o **texto** que a diretiva vira (pp vivo, `__pp_Process`) e o **valor** que
  ela vale (`hbtest`). Elas **discordam** — e é aí que mora o achado.

**Três placares MECÂNICOS rodam a cada `make ppcorpus`** (88/0 hoje; `make test` 990/0):
| guarda | cobra | estado |
|---|---|---|
| `corpus_compile_all` | **todo `.prg` compila** | 0 quebrados |
| `corpus_metodo` | selo `METODO-V2` nas revisadas; **selo sem prova reprova** | **16 revisadas · 10 pendentes** (nomeadas; `ppc-ref` + `ppc-store` + `ppc-say` revisadas 2026-07-15) |
| `corpus_docs` | **todo `.md` declara a guarda que o prova** | 3 famílias sem prova: `directive-scope` (vira teste), `uses-core` (censo) e `pp-as-search` (plano) |
| `corpus_refs` | citação `arquivo:linha` do core ainda aponta o que a doc diz | verde |
| `corpus_schema` | a tabela de mkinds do `ast-schema.md` × os dumps | verde |

**A fila (fase P-REV no roadmap):** revisar 13 fixtures — as 3 de `tests/fix*` são
**compartilhadas com o contrato** (casos 111/113/115): apresentar o drift ANTES. E `derivation`
já virou teste; falta `directive-scope`.

**Cinco famílias NOVAS nesta sessão** (todas com asserts): `pass-cycle` (o pp esgota o comando
antes de avançar; teto de 4096 passes, `#pragma RECURSELEVEL`), `derivation` (clone × paste ×
stringify, e o `from` com offset), `pp-api` (`__pp_Init` — contextos independentes, sem close, o
pp de runtime **não vê** as diretivas do arquivo), `no-eval` (**o pp não avalia**; o único estado
que atravessa uma cadeia é a **tabela de regras**) e `rule-order` (**vence a ÚLTIMA declarada**,
LIFO — é o que faz o `hbclass` funcionar).

**Duas afirmações do corpus caíram, medindo:** o `strdump` "não existe em regra" (existe em 31
regras, 6 no `std.ch`) e o `#xtranslate` gerado "não registra" (registra e casa; o limite real é
a **cabeça colada**, e o mecanismo é o pp desviar para o ramo de diretiva **antes** de concatenar
keywords → a regra nasce com a cabeça em **dois tokens**).

**Lacunas marcadas, não consertadas** (regra PROVE-MARQUE-SIGA): **P15** (rename pelo sítio da
diretiva perde o LOCAL), **P16** (relato do não-verificável: dado em stream, `__LINE__`,
string-macro), **P17** (`#ifdef` esconde diretiva e o `rename` **quebra o código** anunciando
sucesso), **P18** (símbolo dentro do macro chega sem posição).

---

## 0-old. O ESTADO EXATO (2026-07-13, fim da sessão)

**Suíte 990/0.** O código está COMMITADO nos dois repos; sobram duas coisas, ambas do Diego.

**Entregue e commitado:**
- **`harbour-core@f8b2c9ab31`** — comando NOVO `hbmk2 --hbproject[=nested]`: devolve em JSON
  **de que um projeto é feito** (`sources` com `.prg` e `.hbx`, `incpaths`, `prgflags`), tudo
  já resolvido pelo builder (`.hbp`/`.hbc`/`.hbm`, `-i`, `${macros}`, filtros), **um bloco por
  alvo**, e **sem buildar nada**. O `--hbinfo` ficou **byte-idêntico** (ordem do Diego: *"se
  mudar a saída de algum comando, crie um comando novo"*).
- **`hbrefactor@ef6f1e3`** — o `LoadProject` **pergunta** ao hbmk2 em vez de raspar o
  `-traceonly`; o **`CmdTokens` morreu**; o **caso 124** trava a recusa de projeto com fontes
  de **basename homônimo**. Zero drift.

**A doc alcançou o código (commit `9251a1c` + árvore).** O delta do manual foi aplicado (o
`--hbproject` no lugar do *"already-resolved command"*; o homônimo de basename saiu de *Still
rough* e virou recusa permanente em *What it never does*), a página seguiu, e os ponteiros de
baseline avançaram: `CHANGELOG.md` → `hbrefactor@9251a1c`, `NEWS.md` → `harbour-core@f8b2c9ab31`.

**As entradas de changelog JÁ ESTÃO ESCRITAS e commitadas** (a recusa nova no `CHANGELOG.md`;
o `--hbproject` no `NEWS.md`) — não duplicar.

**FALTA commit** (autorização por-commit, e o do core é repo separado): a árvore do hbrefactor
carrega o manual, a página, os oito exemplos novos de `tests/site/` e o gerador; a do core,
só o ponteiro de baseline do `NEWS.md`.

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

**1.1 — FEITO (2026-07-13).** Os quatro transcripts colados à mão viraram os exemplos
**11-18** em `tests/site/`, sob o `make site-check`. Eles **já estavam apodrecendo**: o bloco
do rename de `DATA` mostrava uma classe com o membro `nSaldo` e, embaixo, a saída de um
comando que renomeava `nLimite`; o da genealogia exibia uma regra cujo corpo não era o da
fixture que produzira aquela saída. **Sobraram dois blocos de uma linha**, ambos ilustrações:
o `confirmed send` da seção `INLINE` (só precisa de fixture) e o aborto de `-kt` (que é erro
de *runtime* — o portão roda a ferramenta e compara fonte, não executa o programa do usuário;
esse pede porta nova). Registrado em `tests/site/README.md`.
*(No caminho, a página ainda anunciava o comando `unused-locals`, removido no `1141943` —
removido dela e do manual.)*

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

**1.3 — P-DOC** *(retomando o estudo do pp? **cole o `docs/pp-corpus/METODO.md`** — os 10
passos, com exemplo real em cada)*: a lista de famílias do pp acabou (o `hbct` foi medido e descartado: não tem
UMA diretiva de comando). **A exploração NÃO acabou** *(Diego, 2026-07-13)*: até aqui se estudou
a **DEFINIÇÃO** (a diretiva, nas `.ch`); falta o **USO** — o fonte do Harbour é um corpus de
código real escrito com o pp, e as próximas famílias saem da **medição dos sítios de uso**.
**Regra de lacuna (TROCADA em 2026-07-13)**: era *"pausa a exploração + experimento de core
imediato"*; agora é **PROVE, MARQUE e SIGA** (repro + fase no roadmap com critério de pronto; o
conserto é fatia própria sob autorização). Exceção: achado em que a ferramenta QUEBRA código do
usuário sobe na hora.

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
- **O `make` do harbour-core PASSA (exit 0), contribs inclusive — se falhar, a árvore de build
  é que está velha.** Eu afirmei aqui, horas atrás, que ele "falha no contrib `hbwin`
  (Windows-only), pré-existente e alheio". **MENTIRA, e ela quase virou um patch permanente no
  branch.** O `hbwin.hbp` tem `-stop{!allwin}` e se auto-pula sozinho; ele só era compilado
  porque o motor de filtros do hbmk2 (que compila as expressões por **macro em runtime**) estava
  quebrado — num binário construído a partir de objetos velhos meus. **`make clean && make`
  resolve.** Depois de reconstruir do zero: 0 erros de filtro, 0 erros de header Windows,
  `make` exit 0.
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
- **A ÁRVORE DE BUILD SUJA — leia a [cicatriz § 3.7](cicatrizes.md) ANTES de anunciar qualquer
  defeito do toolchain.** Nesta sessão eu inventei **DOIS bugs**, pela mesma causa: medi num
  diretório podre de rebuilds incrementais meus. O primeiro ("o `-rebuild` não desce para
  sub-projetos") está retratado no roadmap. O segundo foi pior: anunciei ao Diego uma
  **regressão do branch que quebraria o macro-compilador** (`{|a,b| b}` perdendo o 2º
  parâmetro), com tabela comparativa e o veredito de que **mataria o PR** — e rodei um `git
  bisect` de 42 commits atrás de um culpado que não existe. **`make clean && make` no core:
  exit 0, contribs inclusive, macro perfeito.**
  - **Bug não existe até que alguém o reproduza numa árvore LIMPA** (`make clean`, ou uma
    worktree isolada). Isso vale também para **aceitar uma ordem baseada nele**: o Diego mandou
    inibir o `hbwin` no build, e obedecer teria posto no branch um patch permanente para
    mascarar sujeira minha. O `hbwin.hbp` tem `-stop{!allwin}` e sempre se auto-pulou.
  - **O `git bisect` CONFIA nos extremos que você declara.** Um `bad` errado produz um culpado
    errado com toda a autoridade de uma ferramenta automática — ele apontou o meu próprio
    commit. **Teste os DOIS extremos com o mesmo script, no mesmo ambiente, antes de rodar.**
  - **Nunca `git clean -xdf` no repo real** (destrói não-rastreados, irreversível). Para
    experimentar com a árvore, `git worktree add` num scratchpad.
