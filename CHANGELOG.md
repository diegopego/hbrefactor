# Changelog

Escrito para o **programador Harbour final**: o que cada entrega muda no
seu dia a dia, com exemplos e limites honestos. O "como" interno (fases,
specs, decisões) vive em [docs/roadmap.md](docs/roadmap.md) e nas specs
de `docs/`.

## 2026-07-11 — renomear um DATA/VAR member de classe

Antes, se você tentasse renomear um dado de classe (`VAR`/`DATA`) a ferramenta
recusava ("é VAR/DATA, não método"). Agora funciona: renomear o membro atualiza a
**declaração**, todas as **leituras** (`::nSaldo`, `oConta:nSaldo`) E todas as
**escritas** (`::nSaldo := x`) de uma vez, mais o registro interno da classe.

```harbour
CLASS Conta
   VAR nSaldo INIT 0
   METHOD Mostra()
ENDCLASS
METHOD Mostra() CLASS Conta
   ::nSaldo := ::nSaldo + 1
   RETURN ::nSaldo
```

Ponha o cursor em `nSaldo` (na declaração `VAR nSaldo`) e renomeie para `nTotal`:
a declaração, o `::nSaldo := ::nSaldo + 1` (escrita E leitura) e o `RETURN
::nSaldo` viram `nTotal`, e a classe passa a registrar `"nTotal"` — tudo
verificado por recompilação (se algo não fechar, desfaz com rollback).

**Salvaguarda:** se DUAS classes do projeto têm um membro com o MESMO nome
(`Conta:nSaldo` e `Poupanca:nSaldo`), a ferramenta **recusa** e nomeia a outra
classe — porque o acesso `:nSaldo` é dispatch dinâmico e o rename seria ambíguo.
É a mesma regra que já vale para métodos homônimos.

**Limites honestos (fatia 1):** cobre `VAR`/`DATA` simples. `VAR` com
`ACCESS`/`ASSIGN` (getter/setter que você escreve como método) e DATA herdada de
uma superclasse ficam para uma próxima fatia. Nome de CLASSE continua fora do
escopo.

## 2026-07-11 — rename certo com nome repetido; DSL que cria DSL agora renomeia

Duas situações que antes davam errado (uma recusava confuso, a outra nem
existia) agora simplesmente funcionam.

### 1. O valor do seu marker coincide com o nome de uma função real

```harbour
#xtranslate LABEL <n> => RegLabel( <"n"> )

PROCEDURE Main()
   LABEL Vendas        // 'Vendas' aqui é rótulo (vira a string "Vendas")
   ? Vendas()          // 'Vendas' aqui é a FUNÇÃO real, homônima
   RETURN

FUNCTION Vendas()
   RETURN 42
```

Renomear o rótulo (`rename app.hbp a.prg:5:10 Receita`) agora edita **só a
linha do LABEL** e prevê a string derivada — a chamada `? Vendas()` e a
função ficam intactas. Antes, a ferramenta arrastava a chamada da função
homônima junto, a verificação percebia o estrago e desfazia tudo com uma
mensagem confusa; agora ela sabe, por fato do compilador, **a qual dono cada
ocorrência pertence**. O inverso também: renomear a FUNÇÃO (pela chamada ou
pela definição) não toca os sites de DSL homônimos.

### 2. Sua DSL define OUTRA DSL — e o nome no meio agora renomeia

```harbour
#xcommand DEFREGRA <n> => #xcommand USA <n> => ? Marca( <"n"> )

PROCEDURE Main()
   DEFREGRA Ponto      // cria, em tempo de pp, a regra `USA Ponto`
   USA Ponto           // usa a regra criada
   RETURN
```

Renomear `Ponto` — em QUALQUER das duas posições — agora edita os dois
sites juntos e prevê a string derivada:

```
$ hbrefactor rename app.hbp a.prg:5:13 Marco
rename-pp-marker: Ponto -> Marco
  a.prg:5:13
  a.prg:6:8
  predicted string: "Ponto" -> "Marco" (a.prg)
verified: 2 edit(s); derived artifacts renamed as predicted
```

Antes a posição do `DEFREGRA` recusava ("não consigo classificar"). O que
destravou: o compilador do branch agora registra a **genealogia** — quando
uma regra de pp é criada pela expansão de outra, o dump diz de qual
aplicação ela nasceu — e a ferramenta consome esse fato. Vale para o
hbclass real (é assim que `METHOD` funciona por dentro) e para qualquer
DSL sua, existente ou inventada.

### 3. Renomear uma palavra de DSL que ao mesmo tempo CONSTRÓI e REFERENCIA

Uma palavra do seu marker às vezes faz duas coisas na mesma regra: **constrói**
um nome novo (colando `w_<n>`, ou virando a string `"<n>"`) E **referencia** algo
que já existe (uma chamada, uma variável). Exemplo:

```harbour
#xcommand WRAP <n> => FUNCTION w_<n>() ;; RETURN <n>()

WRAP Soma           // gera FUNCTION w_Soma() que chama a Soma() real

FUNCTION Soma()
   RETURN 42
```

Ao renomear `Soma` no `WRAP Soma`, a ferramenta re-deriva TUDO que vem daquela
palavra — o nome colado, a string, a referência. E você fica seguro dos dois
lados, sem surpresa silenciosa:

- se o novo nome **não existe** (`WRAP Soma → WRAP Multiplica`, e não há função
  `Multiplica`), a recompilação percebe a referência quebrada e **desfaz tudo**
  (rollback) — nada de código torto;
- se o novo nome **existe**, compila e a diretiva passa a operar sobre ele — que
  é o que "renomear o argumento da diretiva" quer dizer.

Isso vale por mais complexa que seja a diretiva: a mesma palavra pode ser colada
**várias vezes** e o pp não põe limite — a ferramenta prevê todos os artefatos e,
se errasse algum, a verificação desfaz. **A garantia não depende de a ferramenta
"entender" a sua DSL** — ela confere o resultado COMPILADO: ou bate com o previsto
(rename correto), ou desfaz (rollback). Nunca deixa um rename pela metade.

### O que a ferramenta continua NUNCA fazendo

- Editar por coincidência de nome: cada edição precisa de um fato do
  compilador ligando a ocorrência ao alvo.
- Deixar árvore quebrada: toda aplicação recompila e verifica; qualquer
  divergência desfaz tudo (rollback byte-exato).

### Limites honestos

- Exige o toolchain atualizado do branch `feature/compiler-ast-dump`
  (schema `ast-13`) — harbour E hbmk2 rebuildados.
- Se um MESMO símbolo do módulo mistura os dois papéis de um jeito que a
  contagem de símbolos não separa (o nome cru do marker vira símbolo E
  existe função homônima), a ferramenta continua recusando com rollback —
  ambiguidade real não vira adivinhação.

## 2026-07-11 — os oito `rename-*` foram REMOVIDOS (fica só o `rename`)

Na entrega anterior o `rename` unificado chegou e os oito comandos antigos
(`rename-local`, `rename-param`, `rename-static`, `rename-memvar`,
`rename-function`, `rename-method`, `rename-dsl`, `rename-pp-marker`) ficaram
**descontinuados**. Agora eles **saíram de vez**.

### O que muda pra você

- Use **`rename <projeto> <arq:linha:col> <novo>`** (na extensão, **Rename
  Symbol**, o F2). Um comando só, o kind vem do fato sob o cursor.
- Se você digitar um comando velho, a ferramenta **avisa e redireciona** em
  vez de fazer algo errado:
  ```
  $ hbrefactor rename-local app.hbp a.prg Main x y
  hbrefactor: 'rename-local' foi removido na fase U - use `rename <projeto> <arq:linha:col> <novo>`
  ```
- **Nenhuma capacidade some.** O motor de cada rename continua lá por dentro
  (o `rename` delega a ele); só o comando por-espécie foi tirado da linha de
  comando e da paleta do VSCode.

### Se você tem scripts

Troque `rename-<kind> <projeto> ... <velho> <novo>` por `rename <projeto>
<arq:linha:col> <novo>`, apontando a posição do símbolo. É a mesma edição
verificada, com o mesmo relato.

## 2026-07-11 — um só `rename`: você aponta, a ferramenta descobre o que é

### O problema de todo dia

Para renomear, você tinha de saber ANTES que espécie era o alvo e escolher
o comando certo: `rename-local`, `rename-param`, `rename-static`,
`rename-memvar`, `rename-function`, `rename-method`, `rename-dsl` ou
`rename-pp-marker`. Oito comandos, e a pergunta "isto é um local ou um
static? um método ou uma função?" é exatamente o que o compilador já sabe.

### O que mudou

Agora há **um verbo**, que recebe a POSIÇÃO do cursor:

```
hbrefactor rename <projeto> <arq:linha:col> <novo> [--force] [--edit-rules] [--dry-run]
```

Você aponta o cursor no nome e diz o novo nome. A ferramenta olha o FATO da
árvore naquele ponto e descobre sozinha o que renomear — local, parâmetro,
STATIC, memvar (PRIVATE/PUBLIC), função, método, palavra de diretiva ou nome
de marker de pp — e faz exatamente o que o comando específico faria (mesma
edição, mesma verificação por recompilação, mesmo rollback). Na extensão
VSCode isso vira um único **"Rename Symbol"** (o F2 de sempre).

```
# antes: você tinha de saber que era um método e a classe:
hbrefactor rename-method app.hbp Caixa:Info Mostra
# agora: cursor em cima do Info, em qualquer uso ou na implementação:
hbrefactor rename app.hbp c1.prg:17:8 Mostra
```

### O que a ferramenta NUNCA faz aqui

- **Não adivinha.** Cursor num ponto sem símbolo de compilação (comentário,
  espaço, coluna torta), ou num caso genuinamente ambíguo, ela **recusa
  nomeando o motivo** — nunca renomeia a coisa errada em silêncio. Resolve
  pelo que o compilador *liga* naquele ponto: uma variável usada dentro de
  um comando (`? x`, `@..SAY`) continua sendo aquela variável; uma chamada
  `Foo(...)` é a função mesmo que exista um local `Foo` homônimo; um campo
  de RDD (`FIELD`) — que nenhum verbo cobre — é recusado, não confundido
  com uma função de mesmo nome; e um nome que a sua diretiva **transforma em
  código** (que ela cola num nome de função, ou vira uma string) é tratado
  como o comando/marker que ele é — renomeá-lo carrega os artefatos que ele
  gera — sem se confundir com um local que a própria expansão por acaso crie
  com o mesmo nome. (Esses cantos foram fechados por **duas** rodadas de
  revisão externa cruzada antes da entrega — e o critério "gera código ×
  só passa adiante" virou um fato explícito do compilador.)
- **Não perde nenhuma capacidade** dos comandos antigos: o `--edit-rules`
  (nome citado dentro de diretiva) e o `--force` (strings/`HB_FUNC` iguais
  ao nome) continuam valendo, agora pedidos num ponto só.
- **Não renomeia classe** (o nome de uma `CREATE CLASS`) nem colapsa
  `extract`/`reorder` — uma posição não basta para dizer um trecho a extrair
  ou uma nova ordem de parâmetros; esses seguem com seus argumentos.

### Aviso de descontinuação

Os oito `rename-*` específicos seguem funcionando nesta versão, mas estão
**descontinuados** — o `--help` já os marca. Passe a usar `rename
<arq:linha:col>`; uma versão futura remove os antigos. A extensão já traz o
comando unificado como o principal.

### Detalhe interno

Verbos unificados (fase U, fatia 1) — [docs/roadmap.md](docs/roadmap.md) § U,
[docs/spec-u-verbos-unificados.md](docs/spec-u-verbos-unificados.md),
[docs/adr-002-rename-unificado.md](docs/adr-002-rename-unificado.md).

## 2026-07-11 — `usages`/find-references enxerga o receptor DENTRO das propriedades delegadas (`VAR ... IS/IN`)

### O problema de todo dia

O dialeto Class(y) tem um atalho pra criar uma propriedade que **repassa**
pra outra — um apelido, ou uma delegação pra um membro/objeto interno:

```
CREATE CLASS Gizmo
   VAR nRaw  INIT 0
   VAR oPart INIT NIL
   VAR nEcho AS Numeric IS nRaw              // apelido: ler nEcho lê nRaw
   VAR nVia  AS Numeric IS nCount TO oPart   // delega pro membro oPart
END CLASS
```

Cada `VAR ... IS`/`IN` gera, escondido, **duas** mini-funções: uma pra ler
(`Self:nRaw`) e uma pra gravar (`Self:nRaw := valor`). Ao pedir as
referências de `Gizmo:nRaw` (ou de `Gizmo:oPart`), os usos DENTRO dessas
mini-funções saíam como **`possible` (receiver unknown)** — ruído, porque
o `Self` ali é gerado pela diretiva e os dois blocos caem na mesma linha
do seu fonte, o que a ferramenta não sabia desempatar.

### O que mudou

Agora esses usos saem **`confirmed`**. Vale para as quatro formas do
Class(y) — `VAR x IN Super`, `VAR x IS y`, `VAR x IS y IN Super`,
`VAR x IS y TO oObj` — e para o **getter E o setter** de cada uma:

```
usages Gizmo:nRaw
// ANTES: g1.prg:15: possible send (... receiver unknown, codeblock)   (x2)
// AGORA: g1.prg:15: confirmed send (receiver declared AS CLASS GIZMO, codeblock)  (x2)
```

Fecha o buraco irmão do que a entrega anterior (métodos `INLINE`) resolveu:
lá era um bloco por linha; aqui são dois (ler + gravar), e o compilador
passou a anexar a cada bloco a lista dos **próprios parâmetros** — então a
ferramenta tipa o receptor pelo bloco exato, sem confundir os dois.

### O que a ferramenta NUNCA faz aqui

- Não altera nada gerado: continua sendo **detecção e relato**; nenhuma
  edição automática dentro dessas mini-funções.
- **Custo zero**: o `.c` compilado (inclusive com `-kt`) fica byte-idêntico
  — o fato novo mora só no dump de análise, não no seu executável.
- Só confirma o `Self` do bloco: um send encadeado depois dele
  (`Self:oPart:nCount` → o `:nCount`) segue precisando do fato do próximo
  elo; o que vira `confirmed` é o envio ancorado no `Self`.

### Detalhe interno

Rota da diretiva / completude M-B — [docs/roadmap.md](docs/roadmap.md) § RD-c;
canal `"params"` no nó do bloco em [docs/ast-schema.md](docs/ast-schema.md) (schema `ast-11`).

## 2026-07-10 — `usages`/find-references enxerga o receptor DENTRO de um método `INLINE`

### O problema de todo dia

Você usa `INLINE`, `OPERATOR`, `ACCESS ... INLINE`, `ASSIGN ... INLINE` nas
suas classes (ou uma DSL sua que gera codeblocks parecidos):

```
CREATE CLASS Moeda
   METHOD Total INLINE ::Soma( 0 ):nCents
   OPERATOR "+" ARG nQ INLINE ::Soma( nQ )
END CLASS
```

Aquele `::Soma()` DENTRO do `INLINE` é uma chamada real ao método `Soma` da
`Moeda`. Mas ao pedir as referências de `Moeda:Soma` (comando `usages` ou o
"find all references" da extensão), esse site saía como **`possible`
(receiver unknown)** — ruído, porque o receptor do bloco é **gerado pela
diretiva** e não tem um token escrito no seu fonte para a ferramenta ancorar.

### O que mudou

Agora esse send sai **`confirmed`**. O compilador passou a registrar a
classe do receptor do bloco `INLINE` como **FATO** (um canal novo do
`hbclass.ch`). Com isso a ferramenta resolve `::Soma()` pela regra da
linguagem, sem chute:

```
oJ:Total()              // confirmed - já funcionava (receptor oJ tipado)
// e agora, DENTRO do próprio INLINE:
METHOD Total INLINE ::Soma( 0 ):nCents
//                     ^^^^ ANTES: possible (receiver unknown)
//                          AGORA: confirmed (receiver declared AS CLASS MOEDA, codeblock)
```

Vale para **qualquer** construto que gere esse tipo de bloco — não só o
`hbclass`. Uma DSL SUA que registra comportamento como codeblock com um
receptor tipado recebe o mesmo tratamento, sem ajuste na ferramenta.

### O que a ferramenta NUNCA faz aqui

- **Nunca vira `guaranteed`, nem sob `-kt`**: o receptor de um `INLINE` é
  sempre da própria classe (o Harbour garante o despacho), então impor um
  cheque de runtime nele seria custo redundante. A ferramenta entrega a
  promessa do tipo declarado (`confirmed`) e **para aí** — **zero overhead
  de `-kt`** adicionado ao seu build (provado byte-a-byte).
- **Não adivinha**: se o bloco não é gerado por um construto que declara a
  classe do receptor (um codeblock comum com parâmetro sem tipo), o send
  continua **`possible`** (honesto).
- **Não edita nada**: é só análise; o seu fonte fica intocado.

O "como" interno (RD "rota da diretiva", canal `_HB_INLINESELF`) vive no
[roadmap](docs/roadmap.md) § RD.

## 2026-07-10 — `usages Classe:Método` deixa de mostrar homônimos de outras classes

### O problema de todo dia

Duas classes do seu projeto têm um método de mesmo nome — `Paint()` na
`Janela` e `Paint()` no `Relatorio`, `Soma()` na `Conta` e na `Outra`.
Você pede as referências de `Janela:Paint` (pelo comando ou pelo "find
all references" da extensão) e no meio dos acertos legítimos aparecem
`oRel:Paint()`, `oOutra:Soma()` — chamadas que **nunca** são da classe
que você consultou, só têm o nome igual. Ruído em toda busca, e perigoso
num rename.

### O que mudou

Agora, quando a ferramenta **prova** que o send vai para o método de
OUTRA classe, ela o **exclui** do resultado — e a prova é FATO, não
chute. O compilador passou a registrar no dump **quem herda de quem**
(um canal novo de parentesco). Com esse fato, a ferramenta resolve o
despacho pela regra do próprio Harbour (método próprio vence o herdado;
com herança múltipla, o primeiro pai da cláusula vence) e sela a
exclusão:

```
// Janela e Relatorio, ambas com Paint() próprio, sem parentesco
oJ := Janela():New()
oR := Relatorio():New()
oJ:Paint()   // referência de Janela:Paint
oR:Paint()   // ANTES: aparecia como "possível"; AGORA: EXCLUÍDO por fato
```

O relatório nomeia o motivo: `excluded send within the declared class
graph (dispatches to RELATORIO:PAINT)`. Na extensão, o "find all
references" simplesmente **não lista** mais esses sites.

Continua distinguindo o que é uso real: se `oFilho:Paint()` e `Filho`
**herda** `Paint` de `Janela` (sem sobrescrever), esse send É referência
de `Janela:Paint` — segue no resultado. Só o que sobrescreve, ou é de
classe sem parentesco com a consultada, sai.

### O que a ferramenta NUNCA faz aqui

- **Não exclui por chute**: só quando o tipo do receptor é conhecido
  (declarado, ou imposto por `-kt`) E a cadeia de herança está toda no
  projeto. Receptor sem tipo, pai de fora do projeto, ou classe montada
  em runtime → continua **`possible`** (honesto), nunca excluído.
- **Não confunde herança com homônimo**: um filho que herda o método da
  classe consultada continua sendo referência dela.
- Quem já usa `-kt` ganha a exclusão com a força do cheque de runtime
  por trás; sem `-kt`, vale a promessa do tipo declarado (o de sempre).

O "como" interno (RE.6, canal `_HB_SUPER`, schema `ast-10`) vive na
[spec](docs/spec-re6-parentesco-declarado.md).

## 2026-07-10 — `.hbp` complexo (container, sub-projetos) reconhecido por inteiro

### O problema de todo dia

Seu `.hbp` não é um projeto simples de um alvo só. Ele é um **container**
(`-hbcontainer`) que junta vários sub-projetos, ou referencia outro
`.hbp`, ou usa `-target=` para gerar mais de um binário. Você abre um
`.prg` que pertence ao **segundo** (ou terceiro) desses alvos, roda um
comando na extensão e a ferramenta age como se aquele `.hbp` não fosse o
dono do seu arquivo — ou o picker nem oferece o projeto certo.

Exemplo:

```
# app.hbp
-hbcontainer
gui/gui.hbp      <- 1º alvo
srv/srv.hbp      <- 2º alvo
```

Abrindo um `.prg` de `srv/`, o `app.hbp` era ignorado como dono.

### O que mudou

A ferramenta agora lê **todos os alvos** que o seu `.hbp` produz, não só
o primeiro. Ela continua sem ler o `.hbp` na unha: pergunta ao **hbmk2**
(o builder oficial) qual é a linha de compilação de **cada** alvo e junta
as fontes de todos. Resultado: um `.prg` que pertence a qualquer alvo do
projeto é reconhecido como fonte daquele `.hbp`.

De quebra, tudo que o hbmk2 já resolvia por baixo continua valendo de
graça, porque a ferramenta lê o comando **já resolvido**:

- `.hbm` (coleção de opções incluída no projeto),
- `.hbc` (pacote/lib),
- `-i<path>` de include, variáveis `${hb_name}`/`${hb_targetname}`,
- filtros de plataforma `{win}` / `{!win}`.

Antes: só o primeiro alvo do `.hbp` era enxergado; o resto sumia.
Depois: todos os alvos contam; o `.hbp` é reconhecido como dono de
qualquer fonte sua.

### O que a ferramenta NUNCA faz aqui

Não interpreta o `.hbp`/`.hbm`/`.hbc` por conta própria e não adivinha
flags: quem resolve macros, filtros, includes e sub-projetos é o hbmk2. A
ferramenta só usa o que o builder oficial reportou.

### Limite honesto

Se dois alvos do mesmo `.hbp` compilam módulos com o **mesmo nome de
arquivo** em pastas diferentes (ex.: `gui/util.prg` e `srv/util.prg`), a
posse funciona, mas a análise fina (usages/rename) pode confundir os dois
na hora de casar o dump — some no `-hbcontainer` com nomes repetidos. Caso
apareça no seu uso, avise. Detalhe interno: B5.1 em
[docs/roadmap.md](docs/roadmap.md).

## 2026-07-10 — O picker acha o `.hbp` certo sozinho (o mais próximo primeiro)

### O problema de todo dia

Você abre um `.prg`, roda **Find usages** (ou qualquer comando) na
extensão e cai numa lista de vários `.hbp` — às vezes o mesmo repetido —
e, pior, o `.hbp` que está no **próprio diretório do seu arquivo** nem
aparece. Num projeto grande (o hbrefactor tem 158 `.hbp`/`.hbc`) isso
era regra, não exceção.

### O que mudou

Agora, com um arquivo em foco, a extensão **descobre o projeto sozinha**:
ela pergunta ao CLI, que **caminha do diretório do seu arquivo para cima**
(o `.hbp` de um projeto lista as fontes por caminho relativo, então o
dono está quase sempre ali ou logo acima), pergunta ao **hbmk2** qual
projeto de fato compila o seu arquivo, e responde com o dono.

- **Dono único → entra direto, sem perguntar.** Era esse o objetivo do
  picker desde sempre; o teto de 32 resultados é que sabotava (cortava o
  `.hbp` certo antes de decidir). O teto morreu.
- **Precisou perguntar? O mais próximo vem no topo.** Quando um arquivo é
  fonte de mais de um projeto (fonte compartilhada), ou quando ele ainda
  não está em nenhum, a lista sai **ordenada por proximidade**, com nome
  do `.hbp` + diretório legíveis — nada de caminho absoluto cru repetido.
- **Sem duplicatas.**

Antes: lista de 32 `.hbp` fora de ordem, o do seu diretório sumido.
Depois: entra no projeto certo sem perguntar — ou, no máximo, escolhe
entre os donos reais com o mais perto em primeiro.

### O que a ferramenta NUNCA faz aqui

- **Não adivinha o dono pela proximidade.** Quem decide "este projeto
  compila este arquivo" é o hbmk2, por fato. A proximidade só **ordena**
  a lista e a ordem de busca; o `.hbp` mais próximo do arquivo **não** é
  escolhido automaticamente se o hbmk2 não confirmar que ele é o dono
  (um `.hbp` vizinho que não lista o seu arquivo aparece na lista, mas
  não é auto-selecionado).
- **Não lê o conteúdo do `.hbp`.** Ele só lista os nomes dos arquivos de
  projeto nos diretórios; quem expande e resolve é o hbmk2.
- **`.ch` não é alvo.** Um header é dependência `#include`-ada, controlada
  pelo `.prg`/`.hbp`/`.hbc` — não um projeto ao qual um arquivo "pertence".

### Limites honestos

- Se o seu arquivo não é dono de nenhum projeto ancestral, a ferramenta
  amplia a busca varrendo a raiz do workspace (caso raro; um teto de
  segurança avisa no log se a árvore for enorme).
- Se você fixou `hbrefactor.project` nas configurações, nada disso roda —
  a sua escolha manda.

### Detalhes técnicos

Modo DESCOBERTA do `projects-of` (walk-up ancestral + `RankByProximity`,
proximidade só como apresentação) — [docs/roadmap.md](docs/roadmap.md),
seção B5; provas no caso 102 da suíte e no harness do caso 71.

## 2026-07-10 — `exec-registry`: o retrato das classes que só existem em runtime

### O problema de todo dia

Se o seu sistema monta classes em tempo de execução — uma DSL própria
sobre `__clsNew`, nomes de classe calculados, registro dentro de um
INIT — nenhuma análise de fonte consegue vê-las. E mesmo em classes
comuns de hbclass, o VM cria mensagens que não estão escritas em lugar
nenhum: os *casts* de superclasse (`o:MinhaBase:Campo`). Para a
ferramenta, tudo isso era "receiver unknown".

### O que mudou

```
hbrefactor exec-registry projeto.hbp
```

compila o seu projeto com um driver mínimo (nunca o seu `Main`), RODA
só as funções de registro de classes — encontradas por fato: quem chama
`__clsNew`/`__cls*` no código compilado, mais os INITs, mais o que você
indicar com `--run F1,F2` — e grava o retrato da tabela viva de classes
num `.astr.json`: cada classe com nome, seletores (com tipo — método,
inline, cast), ancestrais e a PROVENIÊNCIA ("registrada pela execução
de F()").

- **Nada é editado**: o comando só observa e grava o retrato.
- **Cada chamada é protegida**: função de registro que exige argumento
  quebra em isolamento e sai no relatório como "falhou" — o resto da
  colheita continua. Argumentos nunca são inventados.
- **Sandbox com a mesma contenção que o `--apply` já usa**: processo
  separado, timeout, diretório de trabalho isolado. (Honestidade: I/O
  que o SEU código de registro fizer não é bloqueado — o comando é
  opt-in justamente por isso, e na extensão VSCode pede confirmação.)
- **Funciona em biblioteca** (`-hblib`): o driver vira o executável.
  Efeito colateral útil: o link de executável denuncia método declarado
  e nunca implementado — no próprio hbhttpd ele achou um.
- **Retrato determinístico**: duas execuções produzem o mesmo arquivo
  byte a byte.

### O que a ferramenta NUNCA faz

- Rodar o seu `Main` ou o programa inteiro — só registradores.
- Tratar o retrato como verdade estática: o que rodou com aqueles
  caminhos é evidência CONDICIONAL. O retrato SUGERE; quem sela é o
  cheque `-kt` em execução real (errou o retrato → erro nomeando site
  e tipos).
- Editar fonte a partir do retrato — a escrita automática foi MEDIDA e
  descartada por ora: no código bem escrito do core, casting é 0-1%
  dos sends e classe invisível ao fonte é nicho de inicialização; o
  retrato vale como inventário/diagnóstico, e a escrita só volta se o
  uso real pedir.

### Limites honestos

- Classe registrada só em caminho condicional (config, ambiente) pode
  não aparecer no retrato — a ausência nunca vira veredito.
- Função de registro `STATIC` não tem símbolo chamável de fora: fica
  de fora COM relato (mova o registro para função pública ou use um
  INIT).
- Medição nos corpora reais (detalhe em docs/): o ganho está nos
  seletores de CAST (38% dos sends do corpus de tortura de casting os
  usam); em código sem casting nem registro dinâmico o retrato não
  acrescenta site nenhum.

(Interno: B9 fatia 4, F4.1+F4.2 —
[docs/spec-b9-fatia4-execucao-controlada.md](docs/spec-b9-fatia4-execucao-controlada.md).)

## 2026-07-10 — o `annotate` aprendeu a anotar parâmetro de codeblock

### O problema de todo dia

A entrega anterior fez o `-kt` conferir parâmetros de codeblock — mas
quem ESCREVIA a anotação era você, à mão. E o lugar mais valioso para
ela é justamente o menos óbvio de anotar:

```harbour
bPar := {| oPar | oPar:Soma( 2 ) }     // que classe é oPar?
Eval( bPar, Moeda():New() )
```

### O que mudou

`annotate --apply` agora escreve `AS CLASS` também em parâmetro de
bloco, no ponto exato do nome:

```harbour
bPar := {| oPar AS CLASS MOEDA | oPar:Soma( 2 ) }
```

- **Onde ele prova, ele escreve**: o bloco registrado como membro
  inline de uma classe (o primeiro parâmetro é o receptor — vale para
  hbclass e para QUALQUER DSL sua) e o bloco cujos `Eval` visíveis
  concordam na classe. A verificação continua a mesma tripla de sempre:
  a edição é inerte sem `-kt` (bytecode idêntico), compila limpa, e o
  projeto RODA sob `-kt` com os cheques passando — qualquer falha
  desfaz tudo byte a byte.
- **Classe criada em runtime não é obstáculo**: se a classe da sua DSL
  não existe em compilação, o `annotate` insere junto o registro puro
  de uma linha (`_HB_CLASS MinhaClasse`) que a torna conhecida do
  módulo — sem prometer nenhum membro.
- **A escrita acerta o alvo mesmo nos casos traiçoeiros**: nome do
  parâmetro repetido na mesma linha (declaração + uso), statement
  continuado com `;`, variável com o mesmo nome da classe. Isso porque
  o compilador agora informa no dump a posição exata do token escrito
  de CADA declaração — a ferramenta não adivinha posição, lê.
- Depois de anotado, o `usages` decide por fato: os sends dentro do
  bloco saem `confirmed`/`guaranteed` em vez de "possible (receiver
  unknown)".

### O que a ferramenta NUNCA faz

- Anotar sem prova: bloco que sai da função, parâmetro reescrito no
  corpo, `Eval` que divergem de classe, segundo parâmetro sem fato de
  dispatch — nada disso recebe anotação; o relato honesto fica.
- Editar o que não foi escrito por você: o corpo que uma diretiva
  gera (ex.: `METHOD x INLINE ...` do hbclass, cujo `Self` é criado
  pela regra) não tem onde receber anotação no SEU fonte — a
  ferramenta reconhece e deixa em paz.

### Limites honestos

- A sugestão nasce de análise; a VERDADE é do cheque imposto: se o
  retrato estiver errado, o programa aborta nomeando o ponto
  (`BASE/3012`) — e o `--apply` já desfez edições assim no passado
  (é o comportamento desenhado, não um acidente).
- O cheque de parâmetro de bloco roda a cada `Eval` — em laço muito
  quente isso tem custo; `-kt` continua opt-in por projeto.

## 2026-07-10 — `-kt` alcança codeblocks (e um segfault de 20 anos morre no caminho)

### O problema de todo dia

Codeblock é onde o Harbour vive — callbacks, `AEval`, `dbEval`, filtros.
E era exatamente onde o fail-fast do `-kt` parava:

```harbour
LOCAL oConta AS CLASS Conta := Conta():New()
LOCAL bPaga  := {|| oConta := PegaDeAlgumLugar() }   // mentira aqui PASSAVA
Eval( bPaga )
```

A escrita dentro do bloco não era checada — a anotação prometia, o
runtime não conferia. E pior: anotar o *parâmetro* do bloco
(`{| oX AS CLASS Conta | ... }`) **derrubava o compilador** — um
segfault que está no Harbour de estoque até hoje (o upstream crasha
igual). Ou seja: a forma mais idiomática da linguagem era um ponto cego
do cheque.

### O que mudou

- **`{| oX AS CLASS Conta | ... }` agora compila** (o segfault morreu) e
  a anotação vale: a cada `Eval`, o valor recebido é conferido — classe
  errada, kind errado ou NIL aborta na hora nomeando função e parâmetro
  (`MAIN:OX`). Subclasse passa (é-um), classe montada em runtime passa
  pelo nome.
- **Escrita dentro de bloco a uma local anotada é checada** — o exemplo
  acima aborta no ponto da mentira (`expected S:CONTA, got C: MAIN:OCONTA`)
  em vez de estourar três telas depois.
- **O selo `guaranteed` do `usages` agora vem de FATO do compilador**:
  o próprio compilador marca no dump cada escrita que ele checou e cada
  parâmetro cujo prólogo ele emitiu. A ferramenta parou de deduzir
  cobertura por regra própria — ela lê a marca. Sites de bloco que eram
  "confirmed (promessa)" viram `guaranteed` porque SÃO.

### O que continua fora (medido, não chutado)

- Passagem por referência (`F( @x )`): o cheque não cobre — e a medição
  no corpus real mostrou **zero** variáveis-objeto passadas por `@`
  (tudo string/número/array). Fica fora com o registro; o rótulo nunca
  diz `guaranteed` nesses sites.
- `PARAMETERS x AS ...` (estilo legado): segue promessa não imposta.
- Cheque em bloco roda a cada `Eval` — em laço muito quente é custo;
  `-kt` continua opt-in.

## 2026-07-10 — `annotate --apply`: a garantia de rollback agora tem prova de fogo

### O problema de todo dia

Toda ferramenta que edita seu fonte promete "se der errado, eu desfaço".
A pergunta que importa: **e se a mentira estiver nas suas declarações,
não no código?** Um `_HB_MEMBER Acha() AS CLASS Moeda` escrito há anos
promete que o método devolve uma `Moeda` — mas a implementação devolve
um número. Isso compila limpo, roda limpo, e nenhuma análise estática
do mundo distingue a promessa do fato. Se o `annotate` confiar nela (e
deve — declaração É o canal de fatos da linguagem), a anotação que ele
escrever estará errada.

### O que mudou

Agora a suíte contém exatamente esse cenário, fabricado de propósito
(fixture nova): a declaração mente, o `annotate --apply` escreve a
anotação que a mentira justifica, e o passo de **execução com `-kt`**
— o único oráculo capaz de pegar isso — estoura no lugar certo. O que
você vê:

```
hbrefactor: padrão-ouro FALHOU após anotar locais: cheque de tipo
declarado FALHOU na execução sob -kt: Error BASE/3012  declared type
check failed: expected S:MOEDA, got N: MAIN:X
```

E os seus fontes voltam **byte a byte** ao que eram — provado por
comparação binária no teste, não prometido. A recusa nomeia variável,
tipo esperado e tipo recebido, tirados do próprio erro de runtime: você
descobre de graça que aquela declaração antiga mente.

Um esclarecimento de leitura que este trabalho rendeu (e vale para o
seu código): em `_HB_MEMBER Acha() AS CLASS Moeda`, o *pertencimento*
do método vem da POSIÇÃO da linha (ela gruda na última classe
declarada acima); o `AS CLASS` é o **tipo de RETORNO** do método — o
mesmo `AS <tipo>` que você escreveria no `METHOD Acha() AS ...` dentro
da classe.

### Também nesta entrega

- **Todas as topologias de classe provadas em suíte** (uma por
  fixture): classe noutro módulo, classe no mesmo módulo, módulo
  multi-classe (cada declaração gruda na classe certa), fábrica com
  `DECLARE` antes da definição, e DSL que monta classe só em runtime.
  Em todas, o site que era "talvez" termina `guaranteed` quando o
  projeto compila com `-kt`.
- **Registro puro de classe**: quando só falta *registrar* a classe no
  módulo (para o `AS CLASS` não degradar), a ferramenta agora escreve
  `_HB_CLASS <Classe>` — registra sem prometer nenhum método. Antes ela
  escreveria um `DECLARE <Classe> New() ...` que promete um `New` que
  talvez não exista.
- **Falha sua não vira culpa da edição**: se o seu projeto JÁ quebra em
  execução (ou é um servidor que nunca termina), o `--apply` detecta
  isso ANTES de editar e pula o passo de execução avisando "execução já
  falhava SEM edição" — em vez de recusar o trabalho culpando a própria
  anotação. As demais verificações (binário idêntico, compilação limpa)
  continuam valendo.
- Num projeto real (hbhttpd, 14 classes): `--apply` escreveu **31
  declarações + 7 anotações** verificadas em ~3 segundos, e o
  re-relatório zera — tudo que era declarável foi declarado; o que
  sobra é o que só inferência alcançaria, e esse a ferramenta não
  escreve.
- **Projeto que já compila com `-kt` agora anota** (era o último
  bloqueio para quem adotou o fail-fast): a prova de "binário
  idêntico" passou a comparar compilações sem a flag — com ela a
  anotação muda o binário *de propósito*, é ela emitindo os cheques.
  Bônus de quem já é `-kt`: a anotação recém-escrita sai `guaranteed`
  na mesma hora no `usages`, sem passo extra.

### Limites que continuam (honestos, declarados)

- Parâmetros de função ainda não são anotados — só locais. E quando
  vierem, a maioria continuará apenas RELATADA: o tipo de um parâmetro
  quase nunca decorre de declaração (é união de quem chama = palpite,
  e palpite a ferramenta não escreve).
- No send encadeado (`oM:Soma( 1 ):Soma( 2 )`), o rótulo fica
  `confirmed via declared types` mesmo quando `oM` está anotado num
  projeto `-kt` — a resolução em cadeia prefere subdeclarar a
  exagerar. O `guaranteed` aparece nos sites de receptor direto.

Detalhes internos: [docs/spec-b9-fatia2-materializacao.md](docs/spec-b9-fatia2-materializacao.md)
§ "Entregue (F2.4-complemento + F2.5)".

## 2026-07-09 — `annotate`: seu código sem tipos vira código tipado, com prova

### O problema de todo dia

Código Harbour típico não diz o tipo de nada:

```harbour
LOCAL oMenu := UWMenu():New()
oMenu:AddItem( "Sair" )
```

Você sabe que `oMenu` é um `UWMenu`. O compilador, não — ele registra e
segue em frente. A consequência aparece nas ferramentas: qualquer busca
de referências ou rename sobre `AddItem` não tem como afirmar *de qual
classe* é aquele send. Ou a ferramenta chuta (e um dia renomeia o método
errado num homônimo), ou é honesta e te devolve "talvez" — que é o que o
hbrefactor faz: sem fato, o site sai `possible`, e conferência manual é
com você.

O detalhe que quase ninguém usa: **a linguagem já tem como dizer os
tipos**. `DECLARE`, `_HB_MEMBER` e `AS CLASS` existem desde sempre,
custam **zero** no programa compilado (nenhum pcode a mais) e alimentam
exatamente o canal que as ferramentas leem. Ninguém escreve porque é
chato, verboso e fácil de errar.

### O que o comando faz

`hbrefactor annotate <projeto>` analisa o projeto inteiro e classifica
cada variável e cada retorno numa escada de certeza:

- **nível 1** — o tipo já decorre do que está declarado; só falta
  escrever o `AS CLASS`.
- **nível 2** — falta *uma linha de declaração* no lugar certo (ex.: o
  `New` herdado que nenhuma classe declara). A ferramenta diz exatamente
  qual linha e onde.
- **nível 3** — a ferramenta até *conclui* o tipo olhando o projeto
  (todos os callers passam `Peca`), mas não existe declaração que
  transforme isso em fato. **Aí ela não escreve nada** — relata e a
  decisão é sua.

Com `--apply`, ela escreve por você — na ordem certa e com verificação
em cada passo:

1. escreve as declarações que faltam (`DECLARE`, `_HB_MEMBER`);
2. **prova que nada mudou no programa**: recompila e exige o binário
   byte-idêntico ao de antes (declaração é compile-time puro — se
   aparecesse um byte de diferença, é rollback automático);
3. prova que o projeto continua compilando limpo com `-w3 -es2`;
4. recompila com `-kt` e **executa** — os cheques de runtime confirmam
   que as anotações dizem a verdade;
5. só então anota as variáveis (`LOCAL oMenu AS CLASS UWMENU := ...`),
   e verifica tudo de novo.

Qualquer falha em qualquer passo: seus fontes voltam byte a byte ao que
eram, com o motivo nomeado.

### O que você ganha

**Antes** (o send encadeado é o exemplo clássico):

```
q1.prg:75: possible send (dynamic dispatch, receiver unknown)  | oM:Soma( 1 ):Soma( 2 )
```

**Depois** de `annotate --apply`:

```
q1.prg:79: confirmed send (receiver class MOEDA via declared types)  | oM:Soma( 1 ):Soma( 2 )
```

Na prática:

- **Rename e usages confiáveis** — sites que eram "talvez" viram fato;
  homônimos param de poluir suas buscas.
- **Documentação de graça** — `LOCAL oMenu AS CLASS UWMenu` conta ao
  próximo programador (e a você daqui a seis meses) o que a variável é,
  sem custar nada em runtime.
- **Fail-fast opcional** — se você compilar com `-kt`, cada anotação
  vira invariante checada: atribuir a coisa errada estoura na hora,
  nomeando variável, esperado e recebido — em vez de um erro de método
  inexistente três telas depois.
- **Seu código continua o mesmo programa** — provado byte a byte, não
  prometido.

No VSCode: `hbrefactor: Annotate report` (só relatório) e
`hbrefactor: Annotate apply` (pede confirmação antes de escrever).

### A mudança no compilador (por que ela foi necessária)

Havia um caso sem saída: método **já declarado** que só precisava ganhar
o tipo de retorno — o `METHOD Soma( n )` dentro do `CREATE CLASS`
declara o método, mas sem tipo. A linha que completa
(`_HB_MEMBER SOMA( n ) AS CLASS MOEDA` depois da classe) sempre
funcionou — o compilador foi *projetado* para a última declaração
prevalecer — mas emitia o warning **W0019 "Duplicate declaration of
method"**, e quem compila com warnings-como-erro (`-es2`) via o build
falhar por causa de uma linha que não muda nada.

A alteração (branch `feature/compiler-ast-dump`, commit `00ccbc20b3`) é
uma condição de cinco linhas: **completar um tipo que ainda não existia
não é duplicata** — segue silencioso. Continua warnando o que deve
warnar: re-declarar um método cujo tipo *já era conhecido* (conflito
real), classe duplicada, função duplicada. Num corpus real (hbhttpd),
18 métodos estavam presos só nesse warning — era o maior bloqueio do
projeto inteiro, e caiu com essa condição.

### O que o comando *nunca* faz

- Não escreve palpite: o nível 3 (só inferência) sai no relatório com o
  motivo, nunca no seu fonte.
- Não toca string, comentário ou dado — só declarações e anotações que
  a recompilação verifica.
- Não edita nada sem `--apply` (e na extensão do VSCode ainda pede
  confirmação antes).
- Não deixa estrago: falhou qualquer verificação, o rollback restaura
  tudo.

### Limites desta entrega (honestos, declarados)

- Parâmetros de função ainda não são anotados — só locais (a assinatura
  pede idioma próprio; fatia futura).
- Projeto que **já** compila com `-kt` fica para a fatia do strip no
  baseline (a prova de byte-idêntico exige compilar sem `-kt`).
- O rollback está exercido por falha real de build, mas o caso provocado
  ("anotação que mente e o `-kt` pega") ainda vira fixture própria —
  **entregue em 2026-07-10 (entrada acima)**.

Detalhes internos: [docs/spec-b9-fatia2-materializacao.md](docs/spec-b9-fatia2-materializacao.md)
§ "Entregue (F2.4)" e [docs/plano-b9-fatia2-escada.md](docs/plano-b9-fatia2-escada.md).
