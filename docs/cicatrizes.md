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
   `AbbrevClash` reescrevendo a regra de `ppcore.c:2725` na ferramenta. Resultado:
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

### 1.3e PROSA no lugar de MEDIDA — quatro empurrões numa sessão (2026-07-27)

**O contexto:** revisão do intervalo da P20. A revisão em si funcionou — achou que o `col`
entregue era inferência. O que falhou foi tudo o que veio **depois**: quatro vezes o Diego
teve que empurrar, e **as quatro mudaram a resposta**. Nenhuma delas exigiu conhecimento que
eu não tivesse; as quatro exigiam um comando que eu não rodei.

| # | eu afirmei | a sonda que existia | o que ela custou |
|---|---|---|---|
| 1 | *"todo nó carrega o índice do token que o gerou"* | um dump: o `nBirthTok` varia com o lookahead (ora +1, ora +0) | mecanismo errado **já escrito na spec do roadmap** |
| 2 | *"o incremento do `FOR` é fato ausente"* | a gramática: `hb_compExprNewPreInc( $2 )` reusa o nó do cabeçalho, e o canal `statements[]` já publica isso | uma classe inteira mal classificada, e uma decisão pedida ao Diego sobre ela |
| 3 | *"bison não está instalado — nenhuma rota compila"* | `bison --version` → 3.8.2, em `/usr/bin`, no PATH | um bloqueio duro **inventado** |
| 4 | *"sítio sem coluna é canto (macro, `-kt`)"* | um comando no corpus do core: **40%** dos sítios | decisão pedida ao Diego sobre o exemplo errado |

**O padrão, e ele é o desconfortável:** nos quatro eu troquei uma sonda barata e decisiva por
**leitura do fonte + dedução**. Ou seja, fiz exatamente o que a ferramenta tem proibido fazer
— só que sobre o core, e em modo de projeto, onde a lei do §1 me parecia não alcançar. **A
regra do fato não é sobre o produto; é sobre como se decide.**

**Dois dos quatro violam regra que JÁ estava escrita.** O nº 2 é o gatilho §1.2/7 (observar em
vez de perguntar), que nasceu do `LoadProject` (§1.3c). O nº 3 é o §1.3 (silêncio de busca não
é evidência), aplicado a busca mas não a sonda — e a ironia é que o `TestExtrai` de
`tests-go/docs/docs_test.go`, escrito por mim dois dias antes, existe **exatamente** para
impedir que uma guarda muda passe por verde. Escrevi o controle positivo para o código e não o
apliquei a mim.

**O que o Diego disse, e é a régua:** *"há uma lição a ser tomada aqui sobre o quanto eu tive
que guiar o claude a investigar com precisão. além de forçar a fazer a pergunta correta
primeiro (TDD)."* O TDD deste repo nunca foi só sobre `expected/` — é sobre **a pergunta antes
da solução**, e uma extensão de core tem o seu próprio `expected`: a **tabela de sondas**
(§1.7/1), que diz o que o core responde HOJE, por classe, com o comando ao lado.

**O sinal operacional:** empurrão do Diego = sonda pulada. Quando ele diz *"investigue com
precisão"* ou *"decidir corretamente é o problema"*, a resposta certa não é um texto melhor —
é `bash`.

**A quinta, no fim da mesma sessão, e de natureza diferente das quatro.** Medi que
`__mvGet( "x" )`, `Type( "x" )` e `hb_macroBlock( ... )` alcançam símbolo pelo nome sem acender
`usesMacro`, e propus substituir o casamento de string por *"`calls[].sym` pertence a
{ `__mvGet`, `Type`, `hb_macroBlock` }"* — chamando isso de **substituto honesto**. Não era. O
símbolo vem resolvido pelo compilador (fato), mas **a lista é minha** (palpite), e a conclusão
"esta função alcança símbolo por nome" é conhecimento sobre a RTL que ninguém no core sancionou.
Era o gatilho 1 um nível acima do texto puro, e por isso não o reconheci.

O Diego cortou sem rodeio: *"heurística é code smell e deve ser retirada mesmo. se houver forma
de resolver através de alterações no core, aí sim, senão, o hbrefactor simplesmente não vai
suportar. me recuso a ter heurística nele."* — e note o que a frase decide: eu havia proposto
matar a heurística **se** houvesse substituto; a ordem é matar, e o substituto entra só se for
fato do core. **Perder capacidade é aceitável; adivinhar não é.**

A sonda seguinte achou a casa em dois minutos: `s_stdFunc`, em `src/compiler/hbfunchk.c` — a
tabela onde o compilador já guarda o que sabe das funções da RTL, e onde o `TYPE` **já estava**.
Ou seja, a pergunta que teria me poupado o erro não é "isto é texto ou símbolo?", é **"quem é
dono deste conhecimento?"**. Virou §1.7/5.

### 1.8 TRÊS ARGUMENTOS MEUS, MORTOS POR UM COMANDO CADA (2026-08-07)

*(A narrativa da [§1.8 do CLAUDE.md](../CLAUDE.md). O Diego pediu: "experimente cada
argumento seu com código, e a partir de seu prognóstico, determine se vale a pena explorar
mais, e só então dê seu diagnóstico".)*

Eu propunha consertar o campo `text` do envelope (a P26) e tinha três argumentos. Os três
eram prosa bem escrita. Nenhum sobreviveu ao primeiro comando.

**(1) "Uma IDE pinta `text[start:end]`" — CONSUMIDOR INVENTADO.** Era o argumento central, e
eu ilustrei com um exemplo de IDE que eu mesmo imaginei. Este repo **tem** um consumidor
real: `vscode/extension.js`. Um grep mostrou que ele monta
`vscode.Location(uri, range.start)` e deixa o editor abrir o arquivo — **nunca lê `text`**.
O defeito era real; a vítima, não.

**(2) "38 expectativas mudariam" — ERRADO POR 20×.** O número saiu de uma heurística minha
sobre os `outputs.json`. Aplicando de verdade: **67** falhas no desenho ingênuo, **3** no
desenho separado. O Diego decidiria sobre o meu número.

**(3) "O legado não assere o preview" — ERAM 67 ASSERÇÕES.** Eu tinha feito `grep -c text` e
olhado quatro linhas do resultado. Isso não é medição; é leitura com cara de medição.

**E um quarto, de outra natureza:** afirmei que prosa e JSON eram caminhos separados, então
mudar um não tocaria o outro. `SrcLine()` chamava `SrcText()`. Uma leitura da função inteira
teria mostrado.

**O que a sequência ensina, e é o motivo da regra:** o experimento que vale é o que **pode me
contradizer**. Os quatro caíram porque eu finalmente rodei o comando que tinha chance de
derrubá-los — e a decisão certa (o alcance da P26, cortado pela morte anunciada da prosa)
saiu dessa exploração, não do argumento. **Argumento derrubado é resultado**; o estrago mora
em apresentá-lo como fato e deixar o Diego decidir sobre premissa morta.

*(A régua do §1.8 não tem portão executável — ela governa a minha prosa. O freio é apresentar
o comando junto da afirmação.)*

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

**REINCIDIU em 2026-08-07 — e desta vez o número não chegou ao usuário, só ao Diego.**
Medi o ganho do incremental (fase W.3) num projeto que **eu mesmo gerei**, 13 módulos
minúsculos, **cronometrando só a etapa de compilação**: 6,197 s → 0,225 s, e daí saiu o
"28×" com que apresentei a fatia. No corpus real (`contrib/xhb`, 42 módulos, comando
completo) o ganho é **1,6×** — e foi esse que entrou no CHANGELOG, no manual e na página,
porque a medição certa veio antes de publicar.

**O que a reincidência ensina sobre a regra** (e é por isso que ela está aqui, e não só na
conversa): o §4 diz *"o número que se anuncia é o do produto rodando como o usuário roda"*,
e eu o li como regra de **PUBLICAÇÃO**. Não é. O microbenchmark já tinha feito o estrago
**antes** de qualquer anúncio — ao entrar na conversa em que se decide o que fazer. **Um
número que decide prioridade É um anúncio**, mesmo que morra na conversa: o Diego aprovou a
fatia ouvindo um ganho inflado por um fator de ~17, e ela ter valido a pena por outros
motivos foi sorte, não método.

Agravante que fecha o caso: **a fatia 1 da fase V já tinha PREVISTO o teto** — geração ~35%
do custo, análise ~50% —, num documento que eu havia lido nesta mesma sessão. O número certo
não estava faltando; estava escrito, e eu produzi outro por medir a peça em vez do produto.

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

### 3.7 A ÁRVORE DE BUILD SUJA — dois bugs INVENTADOS no mesmo dia (2026-07-13)

**Duas vezes, na mesma sessão, eu anunciei um bug que não existe.** Mesma causa das duas
vezes: **medi num diretório de build podre** — dezenas de rebuilds incrementais meus — e
tratei o sintoma como fato.

1. **"O `-rebuild` não desce para sub-projetos de um container"** — escrito no roadmap, com
   mecanismo e tudo. Re-sondado no limpo: **não reproduz**.
2. **"O branch tem uma REGRESSÃO que quebra o macro-compilador"** — codeblock macro-compilado
   perdendo todo parâmetro além do primeiro (`{|a,b| b}` → *variable does not exist*), com
   tabela branch × Harbour de fábrica, e o veredito de que isso **mataria o PR**. Rodei um
   `git bisect` de 42 commits para achar o culpado. **O bisect não achou nada porque não havia
   nada:** todo commit testado passou. Ele apontou o meu último commit **só porque eu declarei
   o "bad" a partir do binário do repositório real** — e nunca testei aquele commit num build
   limpo. Testado numa worktree isolada: **passa**. `make clean && make` no repo real: **exit 0,
   contribs inclusive**, e o macro funciona.

**E a segunda me levou a quase estragar o branch.** O Diego, diante do "make falha no hbwin",
mandou **inibir o hbwin no build deste branch**. Se eu tivesse obedecido, teria commitado um
patch permanente para mascarar **sujeira do meu diretório** — e o `-stop{!allwin}` do próprio
`hbwin.hbp`, que sempre funcionou, teria ficado ali como prova de que eu não entendi nada.
*(Pelo mesmo caminho eu "descobri" que uma nota antiga minha sobre o `gtwvg` era falsa. Não
era: eu estava explicando um sintoma inexistente com outro erro inventado.)*

**A régua, e ela é dura porque eu já a tinha escrito hoje de manhã e violei duas vezes na mesma
tarde:** **bug não existe até que alguém o reproduza numa árvore LIMPA.** Antes de anunciar
qualquer defeito do toolchain — e antes de aceitar ordem baseada nele —, reconstrua do zero
(`make clean`, ou uma worktree isolada) e repita. O custo de reconstruir é de minutos; o custo
de um patch que mascara nada é permanente.

**Corolário sobre o `git bisect`:** ele **confia** nos extremos que você declara. Um `bad`
errado produz um culpado errado, com toda a autoridade de uma ferramenta automática. **Teste os
DOIS extremos com o mesmo script, no mesmo ambiente, antes de rodar.**

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
- **(d) MUDAR UM HEADER (ou um `.c` INCLUÍDO) NÃO RECOMPILA NADA** *(2026-07-27, P21)*.
  O make do core não rastreia `#include`: editei `include/hbexprop.h` e `include/hbexprb.c`
  (que o `src/compiler/exproptb.c` inclui), rodei `make`, ele saiu **0**, e o `.o` era o
  de duas horas antes. **O sintoma é o pior possível: a medição roda, responde, e a
  resposta é do código velho** — perdi dois diagnósticos assim, um deles inventando uma
  teoria sobre a gramática para explicar um binário que não tinha a mudança.

  **POR QUE ele mente, e o mecanismo importa para não achar que foi azar:** o make
  decide recompilar comparando DATAS — se `foo.c` é mais novo que `foo.o`, refaz. O
  make do core **só declara essa dependência para o `.c`**; ele não sabe quais headers
  cada `.c` inclui. Editar um header, então, não muda **nada que o make olhe**: ele
  confere os `.c`, vê que nenhum mudou, e diz "nada a fazer". Não é um erro de build,
  que berra — é a ferramenta rodando normal e respondendo com o código de horas antes.

  **VEREDITO DO DIEGO (2026-08-06), e ele encerra as armadilhas (a)/(b)/(d) de uma vez:**
  *"não se deve usar a compilação incremental para evitar surpresas. isso se aplica ao
  harbour e ao hbmk2."* A minha régua da véspera — *"apague os `.o` certos"* — era
  disciplina, e disciplina é exatamente o que falha; ela ainda pedia que eu ADIVINHASSE
  quais objetos o header alcança. **O build é limpo, ponto**, e virou portão:
  `make core` — **no Makefile do hbrefactor, não num script à parte** (*"é preferível
  do que ter scripts espalhados"*, Diego): apaga os dois binários, roda
  `make clean && make` e **CONFERE que os dois relincaram** (build que "passou" sem
  binário novo reprova), mais o schema declarado pelo fonte dentro dos dois. As
  conferências têm alvo próprio (`make core-check`, 1s) — é o que as torna TESTÁVEIS
  sem um rebuild de minutos. É o §1.6 aplicado a mim: regra nova sem portão novo é
  regra que eu violo de novo.

  *Ganho que só apareceu ao mover para o make:* a sincronização do parser deixou de ser
  um `if` de shell e virou **dependência** (`harbour.yyc: harbour.y`) — que é aquilo de
  que o make é feito. Regenera quando e só quando precisa, e a receita reproduz o
  `.yyc` commitado byte a byte.

  **A janela que a regra abriu, e o conserto** *(2026-08-06, quando o Diego avisou que
  havia outra sessão rodando em paralelo)*: build limpo apagava os binários por ~2min30,
  e nesse intervalo qualquer outra sessão — ou a extensão do VSCode — batia num compilador
  ausente, com o sintoma enganoso do §5.2. Pior: build que FALHASSE deixava a árvore sem
  compilador nenhum. Conserto: guardar os binários FORA da árvore (onde o `clean` não
  alcança) e devolvê-los logo após o `clean`; o link no fim os substitui. Janela de
  milissegundos, e falha não desarma ninguém. **De brinde, a guarda ficou mais forte**:
  com `cp -p` preservando o mtime velho e um stamp tirado depois, "foi relincado agora?"
  passa a ser exato — comparar com o fonte, como antes, um binário restaurado enganaria.
  Os três controles foram rodados: 90 compilações durante o rebuild sem uma falha, build
  quebrado de propósito deixando o compilador servindo, e o stamp acusando os restaurados.

  *Nota de método, e ela quase passou:* meu primeiro controle negativo do script
  "falhou corretamente" — e era **falso**, porque a cópia no scratchpad não achava o
  `hbenv.sh` e morria antes de chegar na guarda. A segunda tentativa neutralizou o build
  mas não o `rm -f` dos binários, então **apagou os binários de verdade** e o controle
  positivo reprovou por outro motivo. Só a terceira, neutralizando os dois e rodando
  A(fresco)/B(velho)/C(ausente), provou a guarda. **Sonda que responde o que eu queria
  ouvir é a que mais precisa de controle positivo** (§1.3e).
- **(e) O ritual do parser tem CONTROLE POSITIVO barato** *(2026-07-27)*: rodar o bison
  **sem nenhuma mudança** e diferenciar contra o `.yyc` commitado. Se só divergirem os
  `#line` e o include guard, a sua versão de bison é a mesma que gerou o commitado e o
  diff da regeneração vai ser só a sua mudança. Gerar de `src/compiler/obj/<plat>/gcc/`
  com `bison -d -oharboury.c ../../../harbour.y` reproduz até os caminhos dos `#line`.

### 5.1b `grep -q` dentro de pipeline com `pipefail` MENTE (2026-08-06)

`set -o pipefail` + `strings bin | grep -qE ...`: o `-q` fecha o pipe no primeiro
casamento, o `strings` leva **SIGPIPE**, e o **pipeline sai não-zero mesmo tendo
CASADO**. A guarda responde *"não tem"* sobre um binário que tem — e essa é a direção
perigosa: ela deixa passar exatamente o que existe para barrar.

Peguei porque rodei os **três** cenários errados e não só o certo: as mensagens não
batiam com o caso (o cenário "os dois são o remendado" acusava o REMENDADO de não ter
o dump, nomeando o binário que tem). O cenário "certo" tinha passado **pelo motivo
errado**, e sozinho não teria denunciado nada.

Régua: em script com `pipefail`, nada de `-q` em pipeline — **substituição de comando**
(`x=$(... | grep -oE ...)` e testa `-n`/`-z`), que não sofre do problema. E o controle
de uma guarda é rodar **todas** as direções, conferindo que cada uma dá a mensagem
DELA; exit não-zero não prova que a guarda certa mordeu. *(Prima do §1.3e: sonda que
responde o que eu queria ouvir é a que mais precisa de controle.)*

**E a régua virou PORTÃO, porque cicatriz é prosa (§1.6):**
[`tests-go/shell/pipefail_test.go`](../tests-go/shell/pipefail_test.go) varre todo `.sh`
do repo e reprova a forma — pipeline + consumidor que fecha cedo + status consumido, em
script com `pipefail` —, apontando arquivo:linha e o conserto. Em Go, com o extrator
tendo **teste próprio** (`TestClassifica`, 4 positivos e 5 negativos): guarda em bash
cujo regex pare de casar passa verde e calada, e este repo já pagou por isso. Controle
negativo rodado: reintroduzi a linha exata que quebrou e ele a acusou. A varredura da
época achou **uma só** outra ocorrência da forma, no `anti-heuristica.sh`, e ela é
**segura** — descarta o status com `|| true` e decide pelo conteúdo, que é o idioma
certo quando se quer o valor.

### 5.1c O `grep` do MEU shell não é o do `make test` (2026-08-07)

Um teste da suíte reprovava a régua do caso 64 (*"a ferramenta não menciona nenhuma
palavra da DSL"*). Rodei **a linha exata do teste** no meu shell: passava. Rodei com
`LC_ALL=C`, com o locale do sistema, com `sh`, com `bash -c`, com um script isolado —
e fui relatando "a régua está limpa" enquanto o teste dizia o contrário, **seis
medições seguidas**, todas confiantes e todas erradas.

A causa: **neste ambiente o `grep` do shell interativo é uma função** que delega para
o `ugrep`; o `make test` chama o `/usr/bin/grep`. Os dois discordam justamente em
`-w` sobre acento — e a violação era `apagá-lo` num comentário meu, onde `apag` casa
como palavra porque `á` não é caractere de palavra em `LC_ALL=C`.

**A regra:** ao investigar divergência entre "eu rodei e passa" e "o teste reprova",
a primeira pergunta não é *sobre o dado* — é **"estou rodando o mesmo programa?"**.
`type -a <cmd>` custa um segundo e teria matado a investigação no primeiro minuto.
Vale para tudo que o shell pode interceptar (função, alias, wrapper, PATH diferente),
e vale em dobro quando o meu resultado é o **cômodo** — foi o caso: cada medição
"limpa" me dizia que o problema era do teste.

Prima da §1.3e (sonda que responde silêncio exige controle positivo) com uma torção:
aqui não houve silêncio, houve **resposta clara e errada** — o controle que faltava
não era sobre o alvo, era sobre o **instrumento**. E prima também da §5.1b, que é a
outra metade do mesmo assunto: lá o `grep` mentia pelo pipeline, aqui por ser outro
programa.

*(Custou também um comentário reescrito duas vezes: o portão anti-heurística barra o
texto do gatilho mesmo dentro de comentário — como a régua do caso 64 —, então narrar
"eu escrevia `X == "stale "`" no fonte reprova. Ilustre o formato, nunca com o texto
que a régua procura: é a §6.2 valendo para o outro portão.)*

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

### 6.4 Eu GRAVEI o expected e chamei de TDD (2026-07-25)

Migrando o caso 38 para o formato declarativo, escrevi `tools/mkcase.sh`: ele rodava o
comando e **gravava** a saída como `out`, imprimindo-a "para eu conferir". Racionalizei com
a armadilha real de escrever JSON à mão (`hb_jsonEncode` formata array vazio como `[\n  ]`)
e com o volume da migração (~468 asserts).

O Diego cortou: *"eu havia proposto algo bem estilo TDD: escreve os arquivos expected,
depois escreve o arquivo que vai ser alterado, e compara a saída do actual vs expected"*.

**Os dois arquivos ficam IDÊNTICOS; os dois testes, não.** Gravado, o `out` afirma *"a
ferramenta faz isto hoje"* — qualquer defeito atual entra no arquivo como se fosse contrato.
Escrito antes, ele afirma *"o contrato diz isto"*, e o defeito aparece como **falha**.

A prova saiu na mesma sessão, contra mim: as duas recusas de DSL saíam com
`reason: "unclassified"` — o campo pelo qual a extensão e o agente decidem. O grep antigo
(`grep -q "abbreviation"`) passava verde; o `out` **gravado** também teria passado verde,
porque eu gravei o que a ferramenta dizia. Só peguei porque **li** a saída — sorte, não
método. Escrevendo o expected antes, eu escrevo `new-name-collides-by-abbreviation`, o caso
falha, e o buraco aparece por construção.

Refazendo os quatro casos na ordem certa (expected à mão, derivado da fixture e do
contrato), **tudo semântico bateu de primeira** — colunas, ordem dos sítios, `kind`,
`detail`, `reason`, `proof`, `editCount`, `scope`. A única divergência foi uma linha em
branco no fim (o envelope sai com um `hb_eol()` a mais). O medo do volume era real; a
resposta a ele não era inverter a ordem.

---

### 6.5 O quarto teste que eu não enumerei — portão fora do contrato é portão que não existe (2026-07-27)

Ao remover a heurística de casamento de string (P22), enumerei os testes afetados do jeito
que a lei manda: rodei o **contrato executável**, `make test`, e reportei ao Diego **três**
quedas (casos 11, 73 e 125), com a análise de qual premissa cedia em cada uma.

Faltava um **quarto**. O exemplo `09-string-guard` da landing page — e ele não era um teste
qualquer: era o que sustentava a afirmação mais forte da página,

> *"No fact can prove whether a given string is a call, so the tool refuses to decide for
> you — it hands you the line and stops. **hbrefactor is the only one of the three that
> tells you the line is there.**"*

...que, no instante em que a heurística morreu, virou **propaganda de uma proteção
inexistente**. E o caso por trás dela (`? Rodar( "Backup" )` com `RETURN &cNome + "()"`) é
chamada por nome **de verdade**, que hoje renomeia e quebra em run time.

**Ele só apareceu por acaso**, horas depois, porque fui mexer na documentação e rodei
`make site-check` por outro motivo. Se a sessão tivesse terminado antes disso, a página
seguiria mentindo — e o `make test` seguiria **verde**.

**A causa não foi desatenção: foi o contrato.** `make test` era `run.sh` + `govet` +
`gotest`. O `site-check` — que roda cada exemplo da página e prova exit, saída e
imutabilidade dos fontes — estava **fora**, junto com o `lexdiff`. A lei diz *"contrato
executável: `make test`"* (§3), e eu confiei nela; ela é que não cobria o portão das
**afirmações que o usuário lê**.

Custo de trazer para dentro, medido: **13,7s** (site-check) + **0,02s** (lexdiff), contra
os ~2-3 min do `make test`. Não havia razão nenhuma para estarem fora além de ninguém ter
olhado.

**E uma segunda armadilha, dentro do próprio conserto:** pus os dois DEPOIS do `gotest`. A
cadeia para no primeiro erro, e a fase tinha três vermelhos de TDD longevos na suíte Go —
ou seja, os portões recém-adicionados **nunca rodariam** justamente na fase que os
quebrara. Foram para antes do `gotest`.

**A régua:** portão novo nasce DENTRO do `make test`; e se for barato, **antes** do alvo
que costuma ficar vermelho por desenho. *(Régua em CLAUDE.md §3.)*

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
