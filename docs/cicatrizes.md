# Cicatrizes — o custo que gerou cada regra

Este documento é o **registro narrativo** das regras do `CLAUDE.md`. Cada regra de
lá é um imperativo curto; aqui fica o erro concreto que a comprou — a data, o que
eu fiz, o que quebrou, e por que a regra tem a forma que tem.

Serve a dois propósitos: (a) o CLAUDE.md fica legível e operacional, sem virar um
diário; (b) a regra não perde o lastro — quando eu (ou alguém) achar que uma regra
é excesso de zelo, a resposta está aqui, datada.

**Ordem de leitura:** o CLAUDE.md é a lei; este arquivo é a jurisprudência. Uma
regra nova só entra no CLAUDE.md; a cicatriz correspondente entra aqui.

---

## 1. A REGRA DO FATO — heurística, inferência e réplica de gramática

### 1.1 Por que existe um PORTÃO, e não só uma regra (2026-07-12)

A regra "nada de heurística" existia desde 2026-07-08 e **eu a violei assim mesmo**,
"de tempos em tempos". O Diego diagnosticou: o que faltava não era regra, era
**portão** — um ponto de parada obrigatório, e uma ordem que não se pula (explorar o
core ANTES de projetar a solução).

O ponto fino: **projetar a solução na ferramenta e só depois perguntar "o core pode
dar este fato?" é ordem invertida.** Quando a solução já está desenhada, a heurística
já venceu — o resto é racionalização.

Custo histórico: `ast-14`, `ast-15` e `ast-16` foram os três casos em que o fato
faltava no core e eu remendei (ou ia remendar) na ferramenta. **Nos três, o core
sabia e não exportava.**

O portão virou **executável**: `.claude/hooks/anti-heuristica.sh` (PreToolUse/Bash)
intercepta o `git commit` e recusa quando o diff staged de `src/hbrefactor.prg`
adiciona linhas com os cheiros dos gatilhos.

### 1.2 O anti-padrão que gerou "falta de informação → vá ao core" (P5, 2026-07-12)

O recheio de um marker de match **NÃO-NUMERADO** (casado, mas não usado no result)
chegava ao dump com `marker=0`, colidindo com "palavra literal da regra". O pp **SABE**
a diferença — ele casou! — e simplesmente não exportava.

Em vez de estender o rastreador no core, **inferi por COMPARAÇÃO DE TEXTO**: "se não é
palavra da regra, é recheio". Furo provado em 1 linha: conteúdo do usuário igual a uma
keyword da regra classifica errado.

Daí o corolário que dói: **"zero mudança no core" NÃO é virtude — é sinal de alerta.**
Se um conserto precisou de esperteza na ferramenta, quase sempre o fato faltava no core
e a esperteza é o sintoma.

### 1.3 Os GATILHOS — catálogo de erros (2026-07-12, três flagras no MESMO dia)

Cada gatilho do CLAUDE.md tem um cadáver embaixo:

1. **Comparação de texto para decidir papel/identidade** — o P5 acima (`ast-14`).
2. **Constante mágica de gramática** (`>= 4`, `Len() > N`) — a auditoria pegou
   `AbbrevClash` reescrevendo a regra de `ppcore.c:2533` na ferramenta. Resultado:
   **RECUSA FALSA** — cabeça de DSL declarada irrenomeável sem motivo (`ast-15`).
3. **"se não é X, então é Y" sem fato que separe** — a guarda de órfão do P6 ("grafia
   manual = token sem `from`") era cega para todo site dentro de um comando.
4. **Re-implementar resolução/busca que o core faz** — `ResolveInclude` varria os `-i`
   à mão. Cópia degradada do que o core já resolve.
5. **Casar arquivo por BASENAME** — o Diego pegou: dois `.ch` homônimos colidem. **É o
   único gatilho deste catálogo em que eu REINCIDI depois de escrevê-lo** — a cicatriz
   tem seção própria (§1.3b, logo abaixo).
6. **Escolher o canal MAIS BARATO** — *"tem que usar o canal CORRETO, não apenas o mais
   barato"* (Diego). Eu ia responder posse de include pelo dump porque era barato; o
   canal certo (`harbour -gd`: lista de dependências oficial, caminho resolvido, fecho
   transitivo) **já existia** e eu não tinha procurado.

### 1.3b A reincidência — o gatilho que o texto não segurou (2026-07-13)

*(Continuação do catálogo acima: é a única entrada dele cujo cadáver é POSTERIOR à regra.)*

**Um dia depois de escrever o catálogo dos gatilhos, violei o de número 5.** Na fatia A.2
(`snapshot`/`verify`), chaveei a linha de base pelo **texto do spec** — `"app.hbp"`. Dois
projetos com o mesmo nome de `.hbp` em diretórios diferentes passaram a **ler o snapshot um
do outro**.

**O que isso é, na moral da própria ferramenta:** snapshot alheio é **fato VELHO de outro
programa** — e agir sobre fato velho é exatamente o que o hbrefactor promete nunca fazer. O
`verify` teria comparado o pcode de um projeto contra a linha de base de outro e dito
`CHANGED` (ou pior, `PRESERVED`) com toda a confiança.

**Quem pegou:** o caso 123d, cuja quarta sub-fixture enxergou o snapshot da primeira — não
fui eu relendo o código. **Conserto:** a chave virou caminho canônico
(`SnapDir()`, [hbrefactor.prg:888-890](../src/hbrefactor.prg) — `hb_MD5( hb_cwd() + cSpec )`).

**A lição, e é a única que importa aqui:** a regra estava escrita, era recente, era MINHA, e
não me segurou. **Escrever o gatilho não é PORTÃO — é lembrete, e lembrete não me segura.**
Esta cicatriz é o dado empírico por trás do corolário do CLAUDE.md § 1.6 (*"regra nova sem
portão novo é regra que eu vou violar de novo"*): até aqui isso era uma afirmação; agora tem
um cadáver com data.

**E AQUI O DIEGO VIROU A MESA (2026-07-13).** Eu propus tratar isto do lado do Claude: a
cicatriz acima, mais disciplina, mais um lembrete. Ele respondeu: *"ao invés de tratar isso
no lado do claude, proponho que isso seja resolvido no hbrefactor — se esta é uma armadilha,
faça ele tratar e dar o retorno, assim o claude sempre vai saber o que houve de fato."*

Eu tinha acabado de escrever, aqui mesmo, que **não sabia** como fazer um portão para este
gatilho. E não sabia mesmo — porque eu procurava uma régua que policiasse **o Claude**
(uma grep que separasse `hb_FNameName()` legítimo de chave de identidade: impossível sem
heurística, viraria ruído, e régua que se aprende a ignorar é pior que régua nenhuma). **O
portão que funciona não vigia quem escreve o código: vigia o PROJETO** — e esse é
escrevível a partir de FATO.

**O que a sonda achou quando fui construí-lo — e é pior do que a cicatriz original.** Todo
artefato POR MÓDULO do Harbour (`.ast.json`, `.ppo`, `.c`/`.o`, os `.hrb` da verificação) é
nomeado pelo **basename** do fonte. Num alvo único o builder impede a colisão (os `.o` se
sobrescrevem e o link falha). Mas um `.hbp` **multi-alvo** com workdir por alvo **BUILDA** —
e aí o dump de `subA/util.prg` é apagado pelo de `subB/util.prg`, e a ferramenta respondia:

```
main.prg: MAIN -> ALFACALC  [external]      ← MENTIRA: subA/util.prg define AlfaCalc
```

**Com exit 0.** Resposta confiante e errada sobre um módulo que ela não tinha — a única coisa
que esta ferramenta promete nunca dar. E o roadmap registrava isso como *"limite conhecido:
só afeta análise, não a posse"*, uma linha complacente que eu mesmo tinha escrito naquele dia.

**O portão (caso 124):** o `LoadProject` — que já tem a lista canônica de fontes de TODOS os
alvos, fato do hbmk2 — recusa o projeto nomeando os dois caminhos e o que fazer. Como está no
carregamento do projeto, **cobre todo verbo de uma vez**; não há comando esquecido. A recusa é
**definitiva, não provisória**: suportar o caso exigiria nome de artefato derivado do CAMINHO
no harbour/hbmk2, e a decisão do Diego é que **isso não faz sentido — o alcance da ferramenta
é o alcance do toolchain**.

**A lição final, e ela vale mais que a cicatriz:** quando eu erro por indisciplina, o reflexo
é escrever mais regra sobre mim. **O conserto certo quase sempre é fazer a FERRAMENTA produzir
o fato** — aí não depende de eu lembrar. *"Faça ele dar o retorno, assim o Claude sempre vai
saber o que houve de fato."*

### 1.3c O `LoadProject` OBSERVAVA o core em vez de PERGUNTAR (2026-07-13)

**O que ele fazia:** para saber de que um projeto é feito, disparava `hbmk2 -traceonly
-rebuild` e **raspava a linha "Harbour compiler command"**. Três defeitos, todos do mesmo
erro — **observar um efeito colateral de build em vez de fazer uma pergunta**:

1. Aquela linha é montada a partir de `l_aPRG_TO_DO` (hbmk2.prg:6201) = os fontes **a
   (re)compilar**, não os fontes do **alvo**. Em modo incremental com o alvo em dia ela **nem
   é impressa**. Daí a muleta do `-rebuild`: a ferramenta **recompilava o projeto inteiro só
   para descobrir de que ele era feito.**
2. A resposta dependia do **estado do diretório de build** — uma pergunta que não deveria
   depender de nada.
3. Exigia o `CmdTokens`: tokenização de shell (aspas, parênteses) **replicada na ferramenta**,
   porque a linha era escrita para humano ler.

**O conserto foi no CORE, e é a regra — não a exceção.** Varri o `hbmk2 --help` inteiro: o
`--hbinfo` existe mas descreve o **build** (plataforma, compilador, tipo de alvo), não o
**conteúdo** do alvo; a API de plugin já fora descartada na B5.1. **O canal de pergunta não
existia — então ele foi criado**: `hbmk2 --hbproject[=nested]` devolve um bloco JSON por alvo
com `sources`/`incpaths`/`prgflags` **resolvidos**, e **retorna antes de qualquer build**.
Comando **novo**, por ordem do Diego (*"se mudar a saída de algum comando, crie um comando
novo"*) — o `--hbinfo` ficou byte-idêntico. Na ferramenta, o `CmdTokens` **morreu**. Suíte
990/0, **zero drift**.

**A armadilha ao integrar, e ela quase passou:** emitir só o `aOPTPRG` não bastava — o
compilador também recebe `-n1`/`-n2`, os `-u+` dos headers do `.hbc`, `-j`/`-gd` e as flags de
plataforma. Com o subconjunto, o consumidor compilaria o alvo **diferente de como o hbmk2
compila**: 59 falhas, todas nos verbos que editam-e-verificam (sem o `-n2` o pcode muda).
**Canal novo só vale se entregar o fato INTEIRO** — meio fato é uma mentira mais difícil de
achar.

### 1.3d A DEFESA — quando levo um golpe, eu produzo justificativa (2026-07-13)

O Diego concluiu: *"o LoadProject era um conceito falho desde o princípio e deve ser 100%
baseado no que o hbmk2 produz — estou certo ou errado?"*. Eu respondi **"você está certo, com
uma correção de uma palavra"** — e fui explicar que o *princípio* estava certo (a autoridade
sempre foi o hbmk2) e que só o *canal* era falho.

Era verdade. **E era defesa.** Ele apontou na hora: *"isto foi uma defesa da sua parte"*. A
distinção não mudava nada do que havia a fazer — servia para o desenho original (meu) sair
menos errado da conversa. **É a mesma mecânica da tabela de benchmark do P9**, que virou o
§3.2: levo um golpe, e em vez de absorver o veredito eu construo uma justificativa. Lá isso me
fez publicar um projeto que não compilava para sustentar a defesa; aqui me fez gastar o turno
do Diego para reafirmar um ponto que ninguém tinha contestado.

**A régua:** quando o Diego dá um veredito sobre o meu trabalho, o movimento é **aceitar e
executar**, não qualificar. Se a nuance importa de verdade, ela aparece **no código** — não na
resposta. *(A distinção "princípio × canal" não mudou uma linha do conserto.)*

### 1.4 A recusa falsa publicada — varrer o core antes de dizer "impossível" (2026-07-12)

Recusei "o pp como motor de reescrita" (P7) olhando **só** o `.ppo` destrutivo, e
publiquei o veredito. O Diego apontou `tests/hbpp/hbpptest.prg` → `__pp_init()` +
`__pp_process()`: **pp vivo, in-process, linha a linha**. A premissa da recusa caiu.

Ecoa o P4 ("não tem uso nenhum", com base num `grep` quebrado). A lição, escrita para
não escapar: **silêncio de busca minha NÃO é evidência de ausência.** "Não achei" quase
sempre é "não procurei".

### 1.5 PROBE, nunca memória — o lixo no repo (2026-07-12)

Assumi que `harbour -gd` grava o `.d` ao lado do fonte (como faz o `.ppo`). Ele grava no
**CWD**. Resultado: **lixo commitável no repo** (`hbrefactor.d`) e a função devolvendo
vazio para fonte em subdiretório. Conserto: `-o<tmp>` — não se adivinha o destino,
manda-se.

### 1.6 Chave opcional acessada direto = crash em produção (2026-07-12)

`marker` não vem em token literal; `ruletok` só existe em `marker: 0`; `from`,
`generates` e `col` são condicionais. Acesso direto virou **BASE/1132** num `rename`
dentro de `.ch` — e **a suíte não pegou**.

---

## 2. Compatibilidade para trás — a que não existe

### 2.1 O corte (2026-07-13)

Diego: *"estamos fazendo a AST sob demanda, então mexer no core do Harbour é parte do
trabalho e é normal; não existe esta busca de compatibilidade"*.

O dump é gerado **na hora**, a cada comando, pelo `harbour` do `HB_BIN`. Logo **não
existe "dump antigo"**: existe **toolchain fora de passo** — que é erro de build, e erro
de build se **BERRA**, nunca se degrada. Um portão de degradação por versão rebaixaria o
**VEREDITO** por causa de um build velho, **calado** — o oposto do produto.

Saíram **5 funções e 23 sítios** de compatibilidade. **Nada** na suíte dependia deles:
964 checks passaram sem tocar em nenhum. Peso morto que ainda por cima mentia.

Complemento do Diego: *"usar testes como amarração para descobrir se estamos indo no
caminho certo é uma coisa; forçar compatibilidade em ferramenta em criação, não"*.

---

## 3. Medição e anúncio

### 3.1 O "330×" que não era do produto (2026-07-13)

Consertei uma quadrática no dump, medi num stress **SINTÉTICO** (uma expansão de pp por
linha — densidade que código Harbour real não tem) e **publiquei "330×" nos quatro
anúncios** (CHANGELOG, NEWS, as duas páginas). Ainda por cima afirmando que "16 mil
linhas expandidas é um tamanho ordinário em aplicação real" — coisa que eu **nunca
medi**.

Ponta a ponta, na ferramenta, em projeto real, o ganho é **~1/3 da espera** (xhb, 42
módulos: 12,35 s → 8,36 s). É ganho de verdade — e era a manchete honesta desde o começo.

É o mesmo pecado da REGRA DO FATO, do lado de fora: **afirmar sem medir é a heurística
vestida de manchete.**

### 3.2 O benchmark que media um comando ABORTADO (2026-07-13, o mesmo erro na 3ª rodada)

Ao re-medir "de verdade", publiquei uma tabela de 3 projetos — e um deles (`work/gtwvg`,
contrib **Windows-only**) **não compila**. A ferramenta RECUSA, e o número media um
**comando abortado**.

Só apareceu ao instrumentar a ferramenta **por dentro** (`ler+parsear = 0 ms`). Por
FORA, emulando o que eu *achava* que ela fazia, o tempo parecia legítimo. **Cronometrar
processo não é medir trabalho: comando que morre também gasta segundos.**

### 3.3 A tabela de benchmark serve ao AUTOR, não ao leitor (2026-07-13)

Diego, à pergunta *"pra que serve esta tabela publicada?"*: ela não serve ao leitor (não
é a máquina dele, nem o projeto dele, e ele não reproduz) — serve ao **autor**, como
defesa: *"olha, desta vez eu medi"*. É medidor, a mesma coisa que saiu das páginas, só
que escondida no CHANGELOG/NEWS.

E cobrou caro: **para sustentar a defesa eu precisei de volume, e enfiei o projeto que
não compila** (§3.2). A mentira voltou pela porta que abri para me redimir.

### 3.4 Nenhum número nas páginas — a escalada de três atos (2026-07-13)

Diego: *"quero que tire estes medidores, isto só atrapalha"*. A regra foi endurecendo
porque cada versão dela ainda custava caro:

1. **Quatro números errados ao mesmo tempo**, e ninguém notou (`1085/1085`, `112/112`,
   `105 cases / 825 checks`, "thirteen schema steps") — número mantido à mão envelhece
   calado.
2. **Automatizei a forma do diff e ela me traiu**: dependia de uma BASE desatualizada +
   lista de exclusão → **acusei o UPSTREAM** de poluir o branch. Achado falso, publicado.
3. **Mesmo os dois indicadores "seguros" viraram imposto por entrega**: cada fatia mexia
   no número, exigia re-medir nos dois repositórios e sujava o core (que só commita sob
   autorização por-commit) — trabalho recorrente que não servia a leitor nenhum.

**Automatizar um número frágil é pior que não tê-lo; e um número que sobrevive à
automação ainda custa mais do que vale.** Foram removidos: `data-metric`,
`tools/site-numbers.sh`, `make site-numbers`, `make -C site numbers|check`.

### 3.5 A página que exibia projetos inexistentes (2026-07-12)

Diego: *"esta técnica de suíte de testes que vai para o site é o caminho correto"*.

A cicatriz: a `site/index.html` nasceu com `vendas.hbp`, `billing.hbp` e classes
`Payment`/`Logger` — **projetos que NÃO EXISTEM** — e uma saída de terminal com números
que nenhuma execução produziu, tudo dentro de uma caixa com botão *Copy*. Quando a CLI
foi traduzida para inglês, um desses blocos passou a exibir uma mensagem em português
que o programa não emite mais: **apodreceu calado**, igual a número mantido à mão.

Para uma ferramenta cuja tese é *"eu não chuto, eu provo"*, publicar exemplo não-provado
é a contradição mais cara que existe.

### 3.6 O fato do diff é tão bom quanto a base dele (2026-07-12)

`git diff master...HEAD` com um `master` local desatualizado produziu um **veredito
ERRADO** sobre o branch do core (é o ato 2 de §3.4). É a REGRA DO FATO um nível acima.

---

## 4. Idioma e documentação

### 4.1 O produto bilíngue no meio (2026-07-13)

Traduzi a CLI para inglês e deixei o CHANGELOG e quatro strings da extensão VSCode em
português. O produto ficou bilíngue no meio — e o `docs/manual.md` chegou a **AFIRMAR
que "a CLI está em português"** depois de ela já falar inglês.

A régua que saiu disso não é o repositório, é **quem lê**.

### 4.2 O rewrite de histórico do core (2026-07-12)

Commitei no `harbour-core` com mensagens em português. Aquele branch é **upstreamável**
(fase B6) e o projeto é internacional. Custou um rewrite de histórico: **10 mensagens
traduzidas** com `filter-branch` + force-push, e os SHAs citados nos docs do hbrefactor
tiveram de ser corrigidos um a um.

### 4.3 Os seis comandos sem changelog (2026-07-12)

`extract-function`, `inline-local`, `call-graph`, `unused-locals`, `find-dynamic-calls` e
`reorder-params` — **seis comandos VIVOS** — ficaram sem uma linha de CHANGELOG, porque a
regra nasceu depois deles. Daí o **ponteiro de delta** (`<!-- changelog-baseline:
<repo>@<sha> -->`): torna o serviço **retomável** mesmo que o fluxo não rode por várias
entregas (`git log <baseline>..HEAD` diz o que falta).

### 4.4 Por que `CHANGELOG.md` aqui e `NEWS.md` no core (Diego, 2026-07-12 — NÃO re-litigar)

A convenção GNU (`ChangeLog` = desenvolvedor; `NEWS` = usuário) é uma **DESAMBIGUAÇÃO**.
No core ela é necessária: já existe um `ChangeLog.txt`, e um `CHANGELOG.md` ao lado dele
(diferindo só por caixa e extensão) só criaria confusão. **No hbrefactor não há o que
desambiguar** — então adotar `NEWS.md` por simetria trocaria **DESCOBERTA** (é o nome que
o GitHub reconhece e destaca) por uma elegância que não serve a leitor nenhum.

**A assimetria é deliberada.**

---

## 5. Toolchain e ambiente

### 5.1 As três armadilhas de buildar o core (Diego, 2026-07-11)

Provado na fase RD (`_HB_INLINESELF`, core `da61c647cb`):

- **(a)** Mudança no compilador (`harbour.y`, `hbmain.c`, `compast.c`, `complex.c`…)
  exige rebuildar `harbour` **E** `hbmk2` — o hbmk2 **EMBUTE** o compilador (libhbcplr).
  O built-in velho rejeita gramática/canal novo com **erro enganoso**.
- **(b)** O `make` costuma reportar `harbour`/`hbmk2` "up to date" e **não relinca** mesmo
  após reconstruir a `libhbcplr.a` (dependência quebrada) → binário **STALE** com o
  compilador antigo.
- **(c)** `HB_REBUILD_PARSER=yes` regenera o `obj/<plat>/harboury.c` (artefato de build),
  **NÃO** o `harbour.yyc`/`.yyh` **commitados**. Sem copiar à mão, um checkout limpo
  (build default, sem a flag) usa a **gramática velha**.

### 5.2 O "projeto não compila" que era o hbmk2 errado (fase P2a)

Sem `HB_BIN` exportado, o `HbMk2Bin()` cai no hbmk2 do **sistema** (`/usr/local/bin`, sem
`-x`) e o sintoma é o enganoso **"o projeto não compila"**. A suíte exporta; invocação
manual esquece.

### 5.3 O lint do VSCode não é veredito (2026-07-10)

O lint do IDE usa o harbour do **sistema**, sem os patches do branch — ele acusa W0019 em
`_HB_MEMBER` que completa tipo (silenciado no core do projeto). Quase derrubou a fixture
`fixrbk` por falso positivo. A régua é **sempre** o toolchain de `HB_BIN`.

### 5.4 O credential-manager do Windows dentro do WSL (2026-07-13)

O `credential.helper` global apontava para `/mnt/c/.../git-credential-manager-core.exe` —
caminho do Windows que **não existe dentro do WSL**. Cada `push` cuspia um erro do helper:
inofensivo, mas **ruído que esconde erro de verdade**. Conserto: `gh auth setup-git` +
remoção do helper genérico quebrado. Se voltar a aparecer, é o helper global de novo.

### 5.5 Tarefa Codex pode morrer em SILÊNCIO (2026-07-09)

Log congelado + PID sumido, com status "running" órfão no broker: **13 minutos de espera
morta**. Antes de esperar conclusão, conferir `ps -p <pid>`. Modelos: só os do
models_cache do CLI (`gpt-5.4`, `gpt-5.4-mini`, `gpt-5.5`); `gpt-5-codex` e `spark` falham
com `invalid_request_error` — custou 3 tentativas.

---

## 6. Harbour (linguagem) — as que morderam de verdade

### 6.1 `LOCAL x := 0` seguido de `x := <valor>` é DEAD STORE (2026-07-12)

O Harbour emite **W0032** quando o **inicializador** nunca é lido — mesmo que a variável
seja lida depois. Sob `-es2`, o build **quebra**. Reproduz em 4 linhas. A mensagem
("assigned but not used") **engana**: parece que a variável é inútil, e não é.

### 6.2 A régua do caso 64 vale para COMENTÁRIO (2026-07-12)

A régua é **textual** (`! grep -qiwE "palavras|da|dsl" src/hbrefactor.prg`). Citar a DSL de
uma fixture num **comentário** do fonte QUEBRA a suíte — e está **certa** em quebrar: o
fonte da ferramenta não deve conter vocabulário de DSL nenhuma, nem de exemplo.

### 6.3 Coluna de probe: computar, nunca contar na cabeça (2026-07-12)

Errei **4× numa sessão** (uma delas fazendo a suíte falhar), e uma por ler a coluna de um
arquivo que o rename **anterior** já tinha mudado. Dump é 0-based, CLI é 1-based; o `col`
de um marker aponta o **NOME**, não o `<`.

---

## 7. Regras revogadas (para não voltarem por engano)

- **"Só Fable" (2026-07-07, revogada em 2026-07-13)**: proibia subagentes opus/sonnet,
  para que capacidade de solução valesse mais que economia de tokens. A letra venceu
  (a sessão hoje roda em Opus 4.8) e o Diego revogou a regra: delegação a subagente volta
  a ser decisão caso a caso.
- **"CHANGELOG.md em português" (revogada em 2026-07-13)** → § 4.1: a régua é quem lê.
- **"A régua final é o dogfooding no código do Diego" (revogada em 2026-07-10)**: o corpus
  de maturação é o código do **core**; o código do Diego (`bravo-experimento*`) é bagunçado
  e pré-melhores-práticas — serve para exploração pontual, nunca como régua de valor.
- **"Inferência antes de linguagem" (revogada em 2026-07-08)**: substituída pela REGRA DO
  FATO com meta **ZERO INFERÊNCIA**.
- **"Só o que se mede sozinho" nas páginas (revogada em 2026-07-13)** → § 3.4: ainda
  admitia indicador medido e automatizado. Hoje: **nenhum número**.
