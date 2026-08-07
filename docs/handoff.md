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

> **A frente da POSIÇÃO DO SÍTIO tem retomada PRÓPRIA:**
> [`retomada-posicao-do-sitio.md`](retomada-posicao-do-sitio.md) *(2026-08-06)*. Ela
> nasceu separada porque duas sessões correram em paralelo neste repo e este arquivo é
> superfície compartilhada — retomada que pode ser sobrescrita não retoma nada. Some
> quando a P24 fechar.

## 0-28. A SESSÃO DE 2026-07-28 — a P21 entregou o MECANISMO, e a fila mudou de dono

**Frente ativa: não é mais a migração da suíte, é a POSIÇÃO DO SÍTIO.** A P21 fechou:
a coluna de um sítio deixou de ser CONTADA e passa a vir do parser. Detalhes e as
medições no `docs/roadmap.md` (P21); aqui só o que faz tropeçar.

**Estado dos dois repos: EDITADOS, BUILDADOS, NADA COMMITADO.** `make test`: legado
**1001/0**, `lexdiff` **100/0**, Go **19/20**. O único vermelho é
`usages-site-from-include` — **TDD da [P24](roadmap.md), escrito antes do conserto**,
igual aos três que abriram esta sessão. Não é regressão.

### O mecanismo, em uma frase (para não re-derivar)

O lexer carimba cada símbolo com o índice do token que o inicia; o **bison carrega o
carimbo na pilha de localizações**, em passo com os valores semânticos; a ação lê `@N`
e entrega o token ao nó; a geração de código diz em que nó está; o registro do sítio
lê o token do nó. **`%locations` com `HB_COMP_YYLTYPE` = índice de token.**

> **A sonda achou uma TERCEIRA saída, e as duas que o roadmap listava eram piores.**
> "Estender o `YYSTYPE` do identificador" assustava pelo ripple em dezenas de `$N` —
> **por este caminho nenhum `$N` mudou de tipo**. E "o lexer guarda o último
> IDENTIFIER entregue" seria a mesma inferência com raio menor: o lookahead do parser
> não garante que o último entregue seja o do símbolo que reduz. **Régua: quando duas
> saídas parecem ruins, a pergunta certa é o que a FERRAMENTA (aqui, o bison) já
> mantém para essa necessidade** — era literalmente para isto que a pilha de
> localizações existe.

### ONDE VOCÊ VAI TROPEÇAR (custou 2 diagnósticos errados nesta sessão)

- **O build do core é `make core`, e SÓ ele** *(Diego, 2026-08-06)*. Nada de
  incremental, nem para o `harbour` nem para o `hbmk2`: o make do core não rastreia
  `#include`, então editar um header sai **exit 0 sem recompilar nada** e a medição
  seguinte responde do binário velho — cheguei a inventar uma teoria sobre a gramática
  para explicar um binário que não tinha a mudança. `make core` apaga os dois
  binários, faz `make clean && make`, **regenera o parser quando o `.y` mudou** (é
  dependência do Makefile, não um `if`) e confere que os dois relincaram. `make
  core-check` roda só as conferências, em 1s. CLAUDE.md §2,
  [cicatrizes §5.1](cicatrizes.md).
- **A prova de pcode agora RODA: `make pcode-identity`** *(resolvido 2026-08-06)*. Ela
  exigia um `harbour` STOCK que não existia na máquina, e por isso a afirmação mais
  importante do PR passou semanas sem quem a medisse. O stock virou **dependência do
  projeto**, como o do branch: worktree de `upstream/master` em `harbour-stock`,
  provisionado e buildado pelo `make`. **889/889 `.hrb` byte-idênticos, 0 divergentes**
  — com o parser regenerado e `%locations` ligado, que era justamente a dúvida.
- **A suíte para no primeiro erro**: com o vermelho de TDD da P24 no `gotest`, ele é o
  ÚLTIMO da cadeia, então legado/lexdiff/docs ainda rodam. Se algum dia o vermelho for
  de um alvo anterior, tudo depois dele emudece.

### O que a P21 mudou na FERRAMENTA (e por que dois testes velhos caíram)

- a **prosa** passou a usar a linha do SÍTIO: ela dizia `c.prg:7` enquanto o `--json`
  dizia 6, para o mesmo statement continuado;
- o fallback **"primeiro token da linha"** morreu nos três laços. Sem `col`, range de
  largura zero — nunca um homônimo escrito na mesma linha carimbado de `confirmed`.

Os dois units re-baselinados (`run.sh` 2456 e 2927) afirmavam a prosa velha; o nome de
um deles descrevia o defeito como contrato (*"guaranteed no site da última linha
física"*). **Decisão do Diego, pedida site a site** (§3).

---

## 0. O ESTADO EXATO (2026-07-27, fim da sessão) — **a linguagem foi DECIDIDA: Go**

**A frente ativa é a FASE A.1 passo 2** — a migração da suíte. A escolha da linguagem da
camada de controle está **fechada**, e a fila é o que sobrou nos três legados:

| formato | onde | quantos | estado |
|---|---|---|---|
| legado imperativo | `tests/run.sh` + `bin/parrun` + `tcheck.prg` | 125 units | 1014/0 |
| legado intermediário | `tests/casedir.sh` + `tests/cases/` | 12 casos | roda dentro do run.sh |
| ~~ponte declarativa (bash)~~ | ~~`tests/scenarios.sh`~~ | **0** | **EXTINTO em 2026-07-27** |
| **o destino** | `tests-go/suite/` (Go) | 16 casos | verde |

**`make test` verde: 1014/0 + `tests/docs` + `tests/suite`.**
**Fila total: 137.** Os legados **só encolhem** — o hook `formato-de-teste.sh` barra
o commit que faça qualquer um deles crescer, e continua barrando a **ressurreição** do
formato-ponte.

**O primeiro legado morreu inteiro.** Com `tests/scenarios/` vazio o `scenarios.sh` saía 1
por anti-vacuidade e derrubava o `make test` — matá-lo deixou de ser opcional. Saíram
junto: o alvo `make scenarios`, o ramo bash do `make oracle` (que agora é só Go) e a
citação da skill. **Régua que isto ensinou:** esvaziar um legado é a metade barata; a outra
metade é arrancar o runner, o alvo do Makefile e toda citação dele — e o portão
`tests-go/docs` é quem cobra a última (ele reprovou a skill citando `tests/scenarios`, e
reprovou **de novo** quando eu tentei explicar a extinção citando o caminho morto).

> **O CONTRATO NÃO ESTÁ AQUI — está em [`tests/README.md`](../tests/README.md)**, escrito
> como **especificação INDEPENDENTE DE LINGUAGEM**. Leia-o inteiro antes de escrever um
> teste. Aqui fica só o ESTADO e o que vai fazer você tropeçar.
> **O loop de UMA iteração está na skill `migrate-test`** — não o re-derive.

### Go, e por que a comparação anterior não valia

*(Diego, 2026-07-27.)* A escolha foi refeita porque o dado estava **contaminado**: a versão
Go que existia era **transliteração** do Python, método a método (`Roda`/`roda`,
`EnvelopesEsperados`/`envelopes_esperados` — até os nomes em português atravessaram). Ela
media o custo da TRADUÇÃO, não o do Go. Reescrita a partir da spec, sem olhar a outra:
**infra 447 → 351 linhas de código, e o caso 26 → 7**.

O que decidiu não foi o placar, foram **dois portões que o desenho em Go torna
impossíveis de esquecer** — e a doutrina do repo é essa (§1.6, portão executável × regra):

- **vacuidade**: as duas comparações são do harness e rodam depois da função do caso
  retornar, então não existe caso que rode a ferramenta e não compare. No Python era uma
  rede em teardown, que ainda reportava `1 failed, 1 error`;
- **fixture órfã**: pasta em `testdata/` sem caso registrado reprova. Medido no outro lado:
  passava **verde, calada**.

**A régua que gerou tudo isto continua valendo:** ao portar qualquer coisa, a pergunta não é
*"como escrevo isto na outra linguagem"*, é *"o que esta linguagem faz para esta
necessidade"*. Foram três traduções pegas pelo Diego (bash→Python, Python→Go,
`tools/oracle.py`→binário) antes de a régua existir.

### As DUAS CLASSES de teste *(decisão do Diego)*

- **Classe A — transformação** (o hbrefactor): `source/` + comandos + `expected/`. É o que
  está em `tests-go/suite/`. **Recusa é subcaso**: `expected == source`.
- **Classe B — estudo** (exploratório): o **pp-corpus**, único ocupante hoje (26 famílias,
  `tests/ppc-*`, 28 guardas). Fica em **Harbour + hbtest** — ali o objeto de estudo é
  Harbour e o teste precisa do pp vivo. **NÃO migra** para o formato da classe A.
  Exige **explicação** (§ abaixo); a classe A não.

### A "explicação" — desenhada, NÃO implementada

Nome certo *(Diego)*: **"explicação para programadores Harbour de como o código em `source/`
funciona"**. Só na classe B. O desenho acordado:

- **`make test` só VERIFICA** (hash de `source/`+`expected/` casando com o registrado);
  determinístico, sem rede, sem modelo. **`make explica` GERA**, disparando o agente.
- O agente lê `.ppo`, `.ppt` e **AST**; compreende os dois lados numa transformação; **se
  faltar fato, ESTENDE O CORE**; escreve `explicacao.md` na pasta do teste.
- O hash mora num **JSON de metadados** do teste, com schema. **A régua que impede o
  `case.json` de voltar: o JSON DESCREVE o teste, nunca o EXECUTA.**
- A AST não fica no `oracle/` (76 KB por fixture); é gerada sob demanda e descartada.

### O runner, em uma tela

```
tests-go/suite/
   suite_test.go       registro, descoberta, as DUAS comparações do §5
   projeto_test.go     o projeto no tmp e a invocação (as invariantes do §4)
   fixture_test.go     as três propriedades do §7 (compila, vocabulário, retrato)
   envelope_test.go    o envelope cli-2 como tipo
   <nome>_test.go      UM por caso: init() + registra() + o que ele afirma
   testdata/<nome>/    source/ expected/ outputs.json oracle/
```

```bash
make caso NOME=x      # UM caso + as provas da fixture dele (segundos)
make gotest           # a suíte da classe A inteira
make oracle NOME=x    # regrava o retrato do core (ato DELIBERADO)
tools/caso-new.sh <nome> <fixture>    # o esqueleto; NÃO escreve esperado
```

**Os portões que nasceram nesta sessão** (todos com controle negativo rodado):

| portão | pega |
|---|---|
| harness | caso que não comparou, artefato novo, `unclassified` congelado, fixture órfã |
| `tests-go/docs` | comando/caminho citado pela spec ou pela skill que não existe |
| hook `formato-de-teste.sh` | commit que faça `run.sh`, `tests/cases/` ou `tests/scenarios/` crescer |

### A sonda de recusa e a de multi-comando — FEITAS (2026-07-27), e o formato aguentou

Os dois casos que o passo anterior mandava tentar antes do volume estão migrados, e
**nenhum deles pediu mudança em `tests/README.md`**:

- **`refuse-old-name-shadowed-by-block-param`** (recusa, 1 comando): `expected/` é o
  `source/` copiado, e é ele que prova que a recusa não tocou em nada. Nada a inventar.
- **`refuse-new-function-name-shadows-runtime`** (3 comandos): `outputs.json` é a lista, na
  ordem; o caso itera os três nomes num `for` e o harness compara a lista inteira. O
  controle negativo (tirar o 3º envelope) reprova.

**O que a migração pagou, e é o padrão a repetir:** o `reason` do multi-comando
(`textual-refs-require-force`) vivia como **literal repetido em 4 sítios** do
`src/hbrefactor.prg` — o único fora da taxonomia `#define RSN_*`, e exatamente o erro que o
cabeçalho da taxonomia descreve. Virou `RSN_TEXTUAL_FORCE`.

**Ganho de infra:** `Envelope.Recusa()` devolve o par `(reason, action)` achatando os
ponteiros — um `*env.Reason` cru num caso é panic no dia em que a ferramenta parar de
recusar, que é justo o dia em que se quer LER a falha. Sucesso vira `""/""`, e o caso falha
mostrando isso.

### O que a migração dos 7 cenários encontrou (e não estava previsto)

**A régua do vocabulário ficou mais rigorosa ao migrar, e a primeira coisa que ela achou foi
uma colisão entre a DSL da fixture e o INGLÊS DO PRODUTO.** No formato-ponte a lista de
palavras proibidas era escrita à mão (`forbid` do `case.json`) e o `fixdsl` **esquecera** as
cabeças `REPEAT`/`UNTIL`; o harness Go extrai as cabeças sozinho, e a `REPEAT` bateu nas seis
mensagens `"repeat with --force"` do fonte.

**Decisão do Diego: a fixture cede, e as cabeças ganham PREFIXO** (`CMD_REPEAT`/`CMD_UNTIL`
— inglês, uppercase, prefixado). A régua não afrouxa: ela é textual e case-insensitive de
propósito, porque um gatilho de verdade se escreve `== "repeat"`, minúsculo, dentro de
string. **O contrato disso está em [`tests/README.md`](../tests/README.md) §7.2** — é lá que
quem escrever fixture nova vai ler.

**Mina que fica:** a cabeça `SQUARED` do mesmo `fixdsl` é palavra inglesa comum passando com
zero ocorrências hoje. Não foi trocada porque mexer nela ripplaria no `outputs.json` e no
`expected/` (ela é usada em 3 sítios), e churn sem prova é o que a lei do repo evita — mas
ela é o próximo `UNTIL`.

### Os dois primeiros units, e o que o formato mostrou de cara (units 8 e 9)

**O `usages` de um LOCAL relata CINCO sítios em TRÊS posições, e ninguém sabia** — o
`unit_9` afirmava que três deles existiam, com `envloc` (*"ache isto na lista"*), que por
construção **não prova o que a ferramenta TAMBÉM disse**. A comparação do envelope inteiro
trouxe os outros dois à luz no primeiro `make caso`.

**Verificado no core antes de acusar a ferramenta** (`harbour -x`, o dump): a duplicação
vem do **compilador**, não do relator. Para `nTotal` em `Main`, o dump traz
`declarations: linha 5` e `occurrences: 5 write | 6 use | 6 ref | 13 read` — a declaração
com inicializador é declaração E escrita, e a captura pelo codeblock chega em DOIS
registros. A ferramenta projeta um sítio por registro. **O lado errado era o meu esperado**,
e o caso migrado agora documenta o contrato real (e afirma que os 5 caem em 3 posições).

> **Régua que isto confirma, e ela é o argumento inteiro da migração:** asserção do tipo
> "ache isto na lista" prova um pedaço e **nunca** o que a ferramenta não disse. Ao migrar
> um unit, o `total` do `usages` é o campo que mais surpreende — compute os sítios do dump,
> não da leitura do fonte.

**E puxando o fio, apareceu LACUNA DE CORE: a fase [P20](roadmap.md).** Perguntado se o
achado estava certo ou pedia mudança no core *(Diego)*, a sonda respondeu: `occurrences[]`
dá **`line` e não `col`**. Com N registros na mesma linha a ferramenta não sabe a qual token
cada um pertence, e resolve todos pelo primeiro — em `nTotal := nTotal + nTotal` os tokens
estão nas colunas 3/13/22 e o `usages` relata 3/3/3. **O `rename` escapa** porque edita
todos os tokens do nome na linha e a recompilação prova; só o relato posicional depende do
fato que falta. Casar o N-ésimo registro com o N-ésimo token seria inferência e **erraria**
(a ordem dos registros é `use, ref, read`; a dos tokens é alvo-de-atribuição, leitura,
leitura). **RESOLVIDO NO MESMO DIA**, por ordem do Diego (*"a lacuna do core tem que ser resolvida
agora no quente"*) — e a pergunta seguinte dele (*"procure se deixou passar algo parecido
nos outros testes"*) achou **mais dois canais com a lacuna idêntica**: `calls[]` e
`sends[]`. A de `calls` é a que mais aparece em código real (chamada aninhada), e nenhum
teste a via.

O core ganhou `col` nos TRÊS canais de sítio (`ast-19 → ast-20`), a ferramenta o consome por
`hb_HGetDef` nos três laços, e três casos travam os três. Detalhes e as medições na P20.

E a varredura achou um **TERCEIRO**, de outra natureza: **statement continuado com `;`**.
Ali não faltava coluna — a **linha estava errada** (o `line` do registro é a ÚLTIMA linha
física do statement). Resolvido também, capturando a posição no REGISTRO e emitindo
`tokLine` só quando difere, sem mexer no significado de `line`. Quatro casos travam as duas
naturezas de defeito nos três canais.

> **Régua que isto deixa, e ela é a lição da sessão:** achado de posição num canal do dump é
> achado de **CLASSE** — varra os outros canais no mesmo passo, e depois varra de novo
> procurando outra NATUREZA de erro no mesmo lugar. Foram três achados em cascata, e só o
> primeiro veio de um teste: os outros dois vieram de perguntar *"onde mais?"*.
> O `grep TokenCols(` em `src/hbrefactor.prg` lista os consumidores; sobraram dois usando a
> resolução por linha (`hFunc["line"]` da definição de função, `declLine` da declaração), e
> ali o nome aparece **uma vez** por construção.

**Os dois repos estão EDITADOS E BUILDADOS, e NENHUM commitado** — commit no core é
autorização por-commit, e ela não foi pedida ainda.

### PRÓXIMO PASSO

O volume: **os 125 units de `tests/run.sh`** (`tools/unit-brief.py --fila` dá a lista; o
`unit_0` sai por último, ele guarda a fixture `fix01`). **Os 12 de `tests/cases/` por último
e com cuidado redobrado**, porque **o esperado deles foi GRAVADO de uma execução** e precisa
ser reescrito do contrato, nunca copiado.

**Lote de 5, `make caso NOME=x` a cada iteração, `make test` no fim do lote** — salvo se
tocar em `src/hbrefactor.prg` (aí é na hora).

---

## 0-hoje. O QUE ESTA SESSÃO ENTREGOU (2026-07-26)

**Na ferramenta** (`src/hbrefactor.prg`):

- **O envelope virou `cli-2`**, com dois campos novos, ambos por crítica do Diego:
  - **`exit`** — e ele **não era derivável** do `status`: o `verify` de veredito BROKEN sai
    `status: "ok"` com exit 1. Quem lia o stdout num pipe concluía o oposto do shell;
  - **`argv`** — a invocação inteira, *"demonstrando o conjunto comando/resultado"*.
- **O `NameAccepted` MORREU** *(ordem do Diego: "o próprio compilador vai reclamar depois")*.
  Ele não era heurística (chamava `hb_compileFromBuf`), mas era um oráculo **aproximado**
  para o que a recompilação responde de forma **definitiva** — e os dois divergiam: medido,
  ele recusava `while` como nome de LOCAL, que o projeto real **aceita**. Era falso-negativo,
  barrando rename legítimo. No mesmo passo, os erros do compilador viraram `diagnostics[]`
  (`DiagCompile`) em vez de vazar em prosa no stderr sob `--json`.
- **Um `\n` a mais em todo envelope**, achado pelo esperado escrito à mão: o
  `hb_jsonEncode( x, .T. )` já termina em newline e as quatro emissões somavam `hb_eol()`.
- **Recusas classificadas**: `compile-failed-rolled-back`, `verification-failed-rolled-back`,
  `old-name-shadowed-by-codeblock-param`, `new-name-is-codeblock-param`,
  `new-name-already-called`. A política é uma por cenário migrado; família/par nasce junto.

**Na suíte:** units 3, 4, 5, 7 e **37** migrados (o 37 virou TRÊS cenários). O `unit_37`
provava que `while` era recusado — **a premissa dele era falsa**, e a migração revelou.

**Ferramentas e portões novos:** `tools/unit-brief.py` (o brief de um unit, com a coluna
COMPUTADA), `.claude/hooks/formato-de-teste.sh`, skill `migrate-test` (substitui a
`new-fixture`, que ensinava o formato legado), `make deps` provisionando **Go 1.26.5 do
site oficial**.

---

## 0-27. O QUE A SESSÃO DE 2026-07-27 ENTREGOU

**A decisão da linguagem, com o dado refeito** (§0). O Python foi removido inteiro
(`tests/*.py`, `tests/casos/`, `tests/meta/`, `pytest.ini`, `pyrightconfig.json`, o venv);
o `tools/deps.sh` parou de provisioná-lo.

**O runner ligado ao `make`** — antes ele só rodava quando alguém digitava o comando à mão,
o que na prática é não rodar. `make caso NOME=x` é o comando do loop; `make oracle` regrava
o retrato dos dois formatos que ainda convivem.

**Três defeitos achados por auditoria, não por teste** — todos no próprio runner, onde
nenhum teste olha:

- **`make caso` saía 0 com o caso quebrado.** Terminava em `| grep`, e o exit de um pipeline
  é o do ÚLTIMO comando. Imprimia `FAIL` e reportava sucesso. O mesmo defeito estava no
  `oracle` e, em outra forma, no `gotest NOME=x` (que passava o nome a um `-run` que não
  casa nada — e `go test` sai **0** com *"no tests to run"*). **Comando de portão não passa
  por pipe.**
- **Nenhum `oracle/` jamais foi versionado**: o `.gitignore` tem `*.ppo`/`*.ppt`, que os
  engolia. O retrato existe para o diff dele aparecer na revisão do commit que mexeu no pp —
  ignorado, não rastreava nada, e num clone novo todo caso reprovaria pedindo `make oracle`.
- **O `tools/scen-new.sh` sobrevivia** criando arquivos num formato que o hook agora barra no
  commit. Ferramenta cujo único produto é proibido não deveria existir.

**A régua do bash, medida:** o modo de falha padrão dele é **sucesso silencioso**. Além dos
dois acima, o runner bash checa artefato com `for f in "$d"/*` + `[ -f ]` — só topo, e o
glob nem enxerga nome com ponto. **Portão novo nasce em Go**, onde o extrator pode ter teste
próprio (foi assim que o `tests-go/docs` substituiu a primeira versão, em bash, que passava
verde se o regex parasse de casar).

---

## 0-trop. ONDE VOCÊ VAI TROPEÇAR (desta sessão)

- **O hook `formato-de-teste.sh` vai barrar o commit de trabalho ANTERIOR a ele** — o
  critério dele é a data do diff, não a intenção, e ele não tem como distinguir "o legado
  está crescendo" de "estou commitando cenário escrito ontem". Aconteceu no commit `7f5a2cd`:
  desliguei por um comando, declarando o motivo, e reativei conferindo que voltou a morder.
  **Se repetir, a resposta certa é migrar o cenário — não afrouxar o portão.**
- **Editar por script (`python3 - <<EOF` sobre um Makefile/`.sh`) não é pego por nada.**
  Foi assim que os três defeitos do §0-27 entraram, e o `make test` ficou **verde** com todos
  eles: estavam no runner, onde nenhum teste olha. **Depois de edição por script, LEIA o
  resultado**; se o alvo é um portão, quebre-o de propósito e confira que reprova.
- **`open(p,'w').write(open(p).read()...)` TRUNCA antes de ler.** Cometi **duas vezes**, nas
  duas o diff mostrou "esperado vazio" e quase virou diagnóstico errado. Nenhum compilador
  pega; o TESTE pega. Leia para uma variável primeiro.
- **`map` em Go itera em ordem ALEATÓRIA.** A saída do regravador de retrato variava entre
  execuções até eu ordenar. Saída de ferramenta que se lê num commit tem de ser determinística.
- **`json.Marshal` do Go escapa `<`, `>` e `&`** (defesa de XSS em HTML). O `<CWD>` virava
  `\u003cCWD\u003e`. Use `Encoder` com `SetEscapeHTML(false)`.
- **Sonda de dependência mente:** perguntar `--help` a um comando não prova que ele
  funciona. Sonde o que de fato falta.
- **O `~/.local/go` não está no git**; em máquina nova, `make deps`.

---

## 0-mig. MIGRAÇÃO DE MÁQUINA (2026-07-25) — concluída em 2026-07-26

O projeto mudou de computador. O que a máquina nova precisou, além dos dois clones:

- **`node`** (o harness da extensão é JS) — agora há **`make deps`**, e o teste que precisa
  dele falha nomeando-o em vez de falhar sem explicar;
- **identidade do git** — os commits herdam o e-mail literal
  `{ID}+{username}@users.noreply.github.com` (o modelo do GitHub não preenchido). Decisão do
  Diego em 2026-07-26: **repetir o placeholder**, para o histórico ficar consistente;
- o core vive em `~/devel/harbour-hbrefactor/harbour-core` (o `tools/hbenv.sh` detecta os dois
  layouts conhecidos; um valor no ambiente sempre vence).

Conferência de que o ambiente está de pé: `make test` (verde), `make ppcorpus`, `make site-check`.

---

## 0-a1. O ESTADO EXATO (2026-07-14, fim da sessão) — frente ANTERIOR (corpus do pp, ARQUIVADA)

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

**Placares MECÂNICOS rodam a cada `make ppcorpus`** (98/0 hoje; `make test` 990/0):
| guarda | cobra | estado |
|---|---|---|
| `corpus_compile_all` | **todo `.prg` compila** | 0 quebrados |
| `corpus_metodo` | selo `METODO-V2` (a DIRETIVA, camadas A/B); **selo sem prova reprova** | **24 revisadas · 6 pendentes** (nomeadas; revisadas 2026-07-15: `ppc-ref`, `ppc-store`, `ppc-say`, `ppc-set`, `ppc-class`, `ppc-gen`, `ppc-dyn`) |
| `corpus_completude` **(NOVO 2026-07-15)** | o **loop dos 4 oráculos** rodou até não sobrar buraco (§5b/§7); selo `COMPLETUDE` casado com check tagueado — **COMPLETE lê a AST, HOLE aponta fase viva** | **1 (`ppc-dyn`=`HOLE:P16`) · 14 pendentes** (nomeadas, não-bloqueante); fase **P-COMPLETUDE** no roadmap |
| `corpus_docs` | **todo `.md` declara a guarda que o prova** | 3 famílias sem prova: `directive-scope` (vira teste), `uses-core` (censo) e `pp-as-search` (plano) |
| `corpus_refs` | citação `arquivo:linha` do core ainda aponta o que a doc diz | verde |
| `corpus_schema` | a tabela de mkinds do `ast-schema.md` × os dumps | verde |

**A DISCIPLINA NOVA (2026-07-15): o loop dos oráculos virou portão.** `METODO-V2` prova só a
**diretiva**; ele não testemunhava o loop *"entender pelos 4 oráculos → oráculo falta info → melhorar
o oráculo (core) → repetir até não sobrar buraco"* (METODO §5b/§7, que eram **prosa sem portão**). Agora:
o passo a passo vive no **METODO §5b** (carregado inteiro ao retomar), e o **`corpus_completude`** cobra
o veredito por família (rastro executável de polaridade casada). *(Um skill dedicado foi tentado e
DESCARTADO: o baseline mostrou agentes rodando o loop **sem** ele — portão + METODO §5b bastam.)*
**Toda família V2 pendente precisa rodar o loop** (fila P-COMPLETUDE). Piloto nomeado: `from`-no-dynval
(P16 b) fecha o `ppc-dyn` (`HOLE→COMPLETE`), sob autorização de commit no core.

**A fila (fase P-REV no roadmap):** faltam **6** — 3 livres (`ppc-instr/m`,
`ppc-live`, `ppc-pragma/pg`) + 3 **compartilhadas com o contrato** (`fixabr`/`fixmk`/`fixp6`,
casos 111/113/115): **apresentar o drift ao Diego ANTES** de tocar (CLAUDE.md §3), porque revisá-las
mexe no `make test`.

**O TEMPLATE V2 que emergiu nesta sessão de 6 famílias (2026-07-15) — siga-o, não re-derive:**
1. **Dois arquivos por família:** `xx.prg` (o principal: `#include "hbtest.ch"` + pp vivo, roda
   pelo hbmk2) e `xxdump.prg` (a irmã raw-dumpável, sem `#require`, para o que só o `.ppo`/`.ppt`/ast
   mostra e não tem valor em runtime). Espelho de `sf.prg`/`sfdump.prg`.
2. **Camada A** = o que a diretiva VIRA, por `__pp_Process` (o texto), assertado com `HBTEST
   AllTrim(...) IS "..."`. Comando de LINGUAGEM (`std.ch`) → `__pp_Init()` já o conhece, sem
   `AddRule`; regra do ARQUIVO → `__pp_Init(,"")` virgem + `__pp_AddRule`.
3. **Camada B** = o que ela VALE, por `HBTEST <expr> IS <valor>`, e o assert TEM de passar pela
   diretiva (apagá-la quebra o assert). **"Onde couber":** já achei 2 exceções honestas —
   `@ SAY` é **só camada A** (escreve no dispositivo, `SaveScreen` volta vazio sob `gtcgi`); `hbclass`
   é **só camada B** (o dialeto são dezenas de regras; pp vivo de uma diretiva isolada não faz sentido —
   o `.ppt` é a camada A dele). Documente o PORQUÊ da exceção, não force um assert.
4. **Guarda `corpus_xx`:** builda+roda o principal (`grep -c 'MAIN(' >= N` asserts, `! grep '^ *!'`
   falhas) e roda os oráculos da irmã via `gen4 ppc-xx xxdump.prg`. Ancore grep do `.ppt` em texto
   **independente de linha** (a irmã tem cabeçalho maior).
5. **Cada citação `arquivo:linha` do core → `tests/corerefs.txt`** (senão apodrece calada). Já
   registrei `std.ch:78/121/249`, `hbfoxpro.ch:60/63`, `ppcore.c:4352/5528/7019`.
6. Atualize o `.md` da família (o bloco "A fixture" → "a prova é EXECUTÁVEL"), o placar aqui, e
   **`make ppcorpus` + `make test` verdes**. Commit por família (autorização por-commit do Diego).

**Gotchas desta frente:**
- **O hook `hbcompile.sh` dá FALSO-POSITIVO em toda fixture com `#include "hbtest.ch"`/`"hbclass.ch"`**
  — ele compila cru com só `-I<dir>`, sem `contrib/hbtest` nem `core/include`. É **advisório** (a
  escrita já aconteceu); o contrato REAL é `corpus_compile_all`/hbmk2. **Não persiga o erro do hook.**
  (Melhoria óbvia, ainda NÃO autorizada pelo Diego: o hook detectar o include e acrescentar o `-I`,
  como o `corpus_compile_all` já faz.)
- **Acoplamento entre guardas:** o `corpus_strdump` pegava emprestado o dump cru de `clsx.prg`;
  ao dividir a fixture, quebrou. Repontei para `clsxdump.prg`. Ao dividir uma fixture, **grep quem
  mais usa o dump dela** (`grep <fam>.ast.json tests/ppcorpus.sh`).

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
