# ADR 001 — B4g: a diretiva como fonte de primeira classe (portão do ast-5)

Data: 2026-07-07. Status: **APROVADA pelo Diego** (sim às três decisões:
1. volume de core do schema ast-5 autorizado; 2. `match[]` na ordem
ARMAZENADA pelo pp, com documentação e fixture — opção (a); 3. fixtures do
probe promovidas à suíte). Contexto executável:
[spec-b4g-diretiva-fonte.md](spec-b4g-diretiva-fonte.md) (fatos 1-13),
[roadmap.md](roadmap.md), [ast-schema.md](ast-schema.md).

Este documento é o REGISTRO HISTÓRICO da explicação apresentada ao Diego
no portão, preservada como foi dada (pedido dele: "grave o que me explicou
em um documento histórico de decisão arquitetural"). Duas partes: a
explicação longa do portão e o esclarecimento sobre a forma das três
decisões.

---

## Parte 1 — a explicação do portão

### O problema que a B4g resolve

O hbrefactor funciona sobre fatos que o compilador exporta no dump
`.ast.json`. Hoje o dump conta muita coisa sobre as **aplicações** das
regras de preprocessador — quando você escreve `FORJA oIt TAMANHO 42`, o
dump registra qual regra casou, quais tokens foram consumidos, de qual
marker veio cada pedaço do resultado. Isso foi o trabalho das fases B4 até
B4f.

Mas a **regra em si — o texto da diretiva
`#xcommand`/`#xtranslate`/`#define` — continua opaca**. O dump só registra
sobre ela: arquivo, linha, palavra-cabeça e a *contagem* de markers. Nada
sobre o que existe dentro dela. Isso produz quatro limitações concretas,
todas já sentidas na suíte:

1. **Caso 74**: você tem `#command DOBRA <k> => <k> := Dobro( <k> )` e
   pede `rename-function Dobro`. A ferramenta recusa — corretamente,
   porque o nome `Dobro` vive dentro da diretiva e renomear só os outros
   sites quebraria o programa (o oráculo de recompilação pega a
   divergência). Mas a recusa é **cega**: a ferramenta não sabe dizer "o
   nome está na diretiva tal, linha tal, coluna tal", e muito menos
   oferecer a edição. Ela sabe *que* não pode, mas não sabe *onde* está o
   impedimento.
2. **`rename-dsl` só renomeia a cabeça**. Numa regra
   `FORJA <x> TAMANHO <n>`, a palavra `TAMANHO` (keyword secundária) não é
   renomeável, porque não existe como fato com posição. O mesmo para
   palavras de restrição como `<modo: RAPIDO, LENTO>` — `RAPIDO` e `LENTO`
   são palavras da sua DSL, e são invisíveis.
3. **`usages` não enxerga dentro de diretivas**: se uma função é citada no
   corpo de uma regra, o `usages` dessa função nem lista o site como
   `possible`. É o último esconderijo de um nome no projeto.
4. **A cabeça editada hoje é reancorada por busca textual**: o pp registra
   a regra com a linha da *última* linha física da diretiva (convenção
   dele), então o `rename-dsl` procura para trás, textualmente, a linha
   que começa com `#xcommand`. Funciona, mas é o último resquício de busca
   textual num sistema onde tudo o mais é posição-fato.

O ponto crucial — e é por isso que a spec diz que a lacuna é "de
exportação, não de conhecimento" — é que **o pp já sabe tudo isso**.
Quando ele parseia `#xcommand FORJA <oIt> TAMANHO <nTam>`, ele classifica
cada token: `FORJA` é literal, `oIt` é marker regular nº 1, `TAMANHO` é
literal, e assim por diante. Essa informação existe em memória,
estruturada, no momento do registro da regra. Ela só não chega ao dump. A
B4g é: exportá-la, como `match[]` e `result[]` dentro de `ppRules[]` — um
item por token, com papel, tipo de marker e posição byte-exata. Isso vira
o schema **ast-5**.

### Por que probes antes do código

Isso mexe no **core** do Harbour (o fork), que está limpo há três eras e
cujo contrato é "zero impacto sem `-x`". O Diego pediu — e a spec
registrou como ordem de serviço — que nenhum volume de código fosse
escrito antes de provar, com experimento, que o desenho se sustenta. O
desenho depende de cinco fatos sobre o interior do pp que existiam por
leitura de código, mas não por prova executada. Cada probe testa um desses
fatos, e cada um tinha um plano B caso falhasse.

O método: um patch de ~40 linhas em `ppcore.c`, no ponto onde toda regra é
registrada (`hb_pp_trackRuleAdd` — um gancho que **já existe** no fork,
usado pelo `ppRules` atual). O patch caminha os tokens da regra
recém-registrada e imprime, para cada um: tipo, índice de marker, texto, e
o que a tabela de posições responde. Esse patch é instrumentação
descartável — foi revertido; a árvore do harbour ficou limpa e os binários
foram recompilados pristinos.

### O que cada probe perguntou e o que saiu

**P1 — "As posições dos tokens da regra ainda existem quando a regra é
registrada?"** Contexto: na B0 nós criamos a posTbl, uma tabela que anota
a posição fonte de cada token no instante em que o tokenizador o corta da
linha. O risco: entre o corte e o registro da regra, o pp faz várias
transformações (converte `<oIt>` em marker, remove a sintaxe `< >`, etc.)
— se alguma delas trocasse o *valor* do token, a entrada na tabela morreria
(ela tem um cheque de identidade justamente para não mentir).
**Resultado: as entradas estão vivas e byte-exatas.** Conferido manualmente
contra o `.ch`: `TAMANHO` na linha 8, coluna 22 — é exatamente onde a
palavra está no arquivo. A única exceção encontrada no caminho inteiro é o
marker exótico `<@>`, cujo valor o pp troca por `"~"` — esse sairá com
posição nula, o que é o relato honesto.

**A descoberta colateral mais importante da sessão** veio daqui: a posTbl
**guarda coluna para tokens de qualquer arquivo, includes incluídos**
(fato 8). O dump atual emite coluna nula para tokens vindos de include
(`prov 'i'`), e a suposição era que fosse limitação da tabela — não é; é
decisão do emissor. Isso importa porque **as regras de verdade vivem em
`.ch` incluídos** (hbclass.ch, os `.ch` de projeto). Sem coluna nos
includes, o critério "match[] byte-exato contra o `.ch`" seria impossível.
Com ela, é direto.

**P2 — "O token que sobrevive à conversão de marker é o do nome, e a
posição aponta o nome?"** Quando o pp converte `<nTam>` em marker, ele
libera os tokens `<` e `>` e mantém só o token `nTam`, mudando-lhe o tipo.
A pergunta era se a posição desse sobrevivente aponta o nome no `.ch`.
**Resultado: sim, para todos os seis tipos de marker do match** (regular,
lista `<a,...>`, restrição `<m: A, B>`, wild `<*x*>`, extexp `<(x)>`, name
`<!x!>`) **e os quatro do result** testados (regular, stringify `#<x>`,
`<"x">`, `<(x)>`). E um bônus não previsto na spec: as alternativas de
restrição (`RAPIDO`, `LENTO`) ficam penduradas no token do marker **com
posições próprias** — ou seja, o rename de palavra de restrição, que era
item "desejável", tem posição-fato de graça.

**P3 — "Numa diretiva continuada por `;` em três linhas físicas, cada
token sabe sua linha real?"** Isso é o que mata a reancoragem textual: se
`match[0]` (a cabeça) carrega linha e coluna físicas reais, o `rename-dsl`
para de procurar `#xcommand` textualmente. **Resultado: sim.** No probe,
os tokens do match saíram nas linhas 8, 9 e 10 e os do result na 11, cada
um na sua coluna — enquanto o registro da regra diz "linha 11" (a
convenção do pp de usar a última). A âncora byte-exata existe.

**P4 — "Grupos opcionais `[...]` têm estrutura recuperável?"** O pp
representa o grupo opcional como um token especial que carrega o conteúdo
do grupo numa lista lateral (`pMTokens`). **Resultado: confirmado** — os
tokens internos (a keyword `ROTULO`, o marker `cRot`) estão lá,
posicionados. O desenho do schema (achatar com pseudo-itens
`opt-open`/`opt-close`, como já fazemos em `blocks[]`) funciona.

**A surpresa da sessão** também veio daqui (fato 12), e é o assunto da
decisão nº 2 — explicada em separado abaixo.

**P5 — "Regra definida dentro da expansão de outra regra: as posições
mentem?"** É o padrão do cstruct do xhb (caso 73): um `#xcommand` cujo
*resultado* é outra diretiva. A regra interna nasce de tokens
sintetizados, e o medo era posições nulas em tudo, ou pior, posições
erradas. **Resultado: melhor que o previsto — as posições são reais e
rastreáveis.** A cabeça da regra interna aponta para onde ela está escrita
*dentro do result da diretiva-mãe*; o pedaço que veio do marker aponta
para onde o usuário o escreveu no site de uso. Nada mente. A única
ressalva: a posição pode viver num arquivo diferente do arquivo registrado
para a regra (a posTbl não guarda nome de arquivo, só linha/coluna). Isso
não quebra nada, porque a política de edição da ferramenta sempre confere
byte a byte o texto no arquivo antes de editar — se a posição não pertence
àquele arquivo, a conferência falha e a edição é recusada com relato. É o
padrão "editor ≠ verificador" de sempre.

Também foi testado o caso degenerado: regras builtin (as compiladas dentro
do binário, tipo o `?` do std.ch) saem com arquivo nulo e posições nulas —
relato honesto, nenhum crash.

### A surpresa dos opcionais consecutivos (decisão nº 2)

Quando uma regra tem dois grupos opcionais consecutivos e o **primeiro**
não contém nenhuma keyword — por exemplo `#xcommand TEMPERA [<n>]
[GRAU <g>]` — o pp, **no momento do registro**, troca os grupos de lugar
internamente: armazena `[GRAU <g>]` antes de `[<n>]`. É código deliberado
do Harbour (há até um comentário no fonte explicando: sem isso, o
casamento com concatenação de palavras teria um bug sério —
ppcore.c:3796-3800). Consequência: a ordem dos tokens que o snapshot vê
**não é a ordem em que o programador escreveu** — é a ordem que o pp usa
para casar.

As duas opções:

- **(a) Emitir a ordem armazenada e documentar** (o que está no draft). A
  favor: o dump relata o fato como ele existe no pp — se um dia um
  consumidor precisar entender *por que* uma aplicação casou como casou, a
  ordem armazenada é a verdadeira semântica de casamento. E a ordem do
  fonte não se perde: cada token interno tem posição, então reordenar por
  posição é trivial para quem precisar (o round-trip byte-exato não sofre,
  porque ele confere token a token por posição, não por sequência).
  Contra: um consumidor ingênuo que percorra `match[]` esperando "a ordem
  da diretiva como escrita" vai se surpreender nesse caso raro.
- **(b) Reordenar no emissor para a ordem do fonte.** A favor: `match[]`
  fica visualmente igual ao `.ch`. Contra: o dump passaria a relatar algo
  que **não é** o que o pp tem nas tabelas — esconderia a semântica real
  de casamento, e o custo de reordenar migraria para dentro do core (mais
  lógica no snapshot, mais superfície para errar num arquivo que queremos
  mínimo para o PR upstream). E o consumidor que quisesse a ordem de
  casamento não teria como recuperá-la.

Recomendação: a **(a)**, pelo princípio da casa: o dump transporta fatos
do compilador 1:1, e interpretação é trabalho da ferramenta. Ponto fraco
admitido: é o tipo de detalhe que alguém esquece; a mitigação é
documentá-lo no ast-schema.md e cobri-lo com fixture na suíte — a regra
`TEMPERA` do probe existe exatamente para virar esse teste.
**→ Diego escolheu a (a).**

### O que a decisão nº 1 autoriza

"Volume de core" significa, concretamente:

- **No pp do fork** (`ppcore.c` + accessors em `hbpp.h`): no instante do
  registro de cada regra — o gancho `hb_pp_trackRuleAdd` já dispara lá,
  zero ganchos novos — copiar texto, papel, tipo de marker e posição de
  cada token de `pMatch`/`pResult` para uma tabela lateral da regra. É o
  padrão "cópia no instante" da B4d: depois disso, nenhuma mutação futura
  do token nos afeta. Tabela limpa em `hb_pp_reset`, tudo gated por
  `fTrackPos` (só liga com `-x`).
- **No compast.c**: emitir as seções `match[]`/`result[]` dentro de
  `ppRules[]` e versionar o schema para **ast-5**.
- **Prova de zero impacto** (o mesmo protocolo das eras anteriores):
  varredura de `src/` com e sem `-x` produzindo `.hrb` byte-idênticos, em
  `-w0` **e** `-w3`; relink duplo de `harbour` e `hbmk2` conferido por
  `strings`.
- **Na ferramenta** (hbrefactor, sem mexer no core): `usages` nomeando
  sites dentro de regras; caso 74 passando a recusar *apontando*
  diretiva+posição, com `--edit-rules` opt-in para editar e re-verificar
  pelo oráculo; `rename-dsl` estendido a keyword secundária e palavra de
  restrição; morte da reancoragem textual; extensão VSCode recebendo o que
  fluir pelo canal textual. Fixtures novas: as do probe promovidas + os
  casos adversariais listados na spec (homônimo por papel, `#define` com
  corpo, regra builtin recusando edição, etc.).

Riscos, ditos honestamente: é a maior adição ao core desde a B4d, e cresce
o arquivo que um dia vira PR upstream (a B6). O que o contém: o protocolo
de zero impacto é mecânico e já pegou regressão antes; a lógica nova é
toda write-only (snapshot + emissão), sem tocar nenhum caminho de decisão
do pp; e os probes provaram que não há nenhuma incógnita de dados no
desenho — as cinco perguntas abertas viraram fatos numerados (8-13 na
spec).

### Decisão nº 3

A promoção das fixtures é: `forja.ch`/`forja.prg` (que exercitam todos os
tipos de marker, continuação, opcionais consecutivos, restrição) e
`molde.prg` (regra dentro de expansão) saem do scratchpad — que é volátil
— e viram casos da suíte quando o volume começar, com asserts campo a
campo contra o dump ast-5.

---

## Parte 2 — o esclarecimento das três decisões

(Contexto: o Diego perguntou se, entre as três decisões, a recomendação
era somente a nº 2.)

Não — a confusão é minha culpa, deixa eu desfazer. **As três não são
alternativas concorrentes entre si** (não é "escolha 1, 2 ou 3"). São três
perguntas **independentes**, do tipo sim/não, sobre o mesmo caminho — e a
recomendação é **sim nas três**. A aparência de que só a 2 foi recomendada
veio de um detalhe: a decisão 2 foi a única que tinha duas alternativas
*internas* (a vs. b), então foi a única onde a palavra "recomendação"
apareceu explicitamente.

**Pergunta 1 — "Começo a escrever o código do ast-5 no core?"** É a
decisão principal; as outras duas são detalhes dela. A spec encomendada
dizia: nada de código antes dos probes provarem o desenho. Os probes
rodaram e as cinco incógnitas viraram fatos confirmados — nenhum plano B
foi necessário. Ou seja: a condição que o DIEGO estabeleceu para liberar o
trabalho foi cumprida. **Recomendação: sim, autorizar.** O argumento a
favor: o desenho está de pé sobre fatos provados, os consumidores já estão
esperando (caso 74 acionável, rename de palavra secundária, usages
completo), e o protocolo de zero impacto é o mesmo que já funcionou nas
eras anteriores. O argumento contrário honesto: é a maior adição ao core
desde a B4d e engorda o futuro PR upstream — se a preferência fosse
digerir a B6 antes de crescer o fork, adiar seria legítimo. A recomendação
foi não adiar: o risco técnico é baixo (código write-only, gated, com
prova mecânica) e o valor na ferramenta é imediato.

**Pergunta 2 — "Dentro do ast-5, o `match[]` sai na ordem que o pp
armazena ou na ordem que o programador escreveu?"** Essa só existe se a 1
for "sim". É a única com duas opções de verdade; recomendada a ordem
armazenada (com documentação e fixture), pelas razões da Parte 1: o dump
transporta fato 1:1, e a ordem do fonte é recuperável pelas posições — o
contrário não seria.

**Pergunta 3 — "As fixtures do probe viram casos da suíte?"** Essa é quase
burocrática; recomendação **sim** sem hesitação: as fixtures já existem,
já compilam limpas, cobrem exatamente os cantos difíceis (todos os tipos
de marker, diretiva continuada, opcionais reordenados, regra dentro de
expansão), e viviam no scratchpad — que evapora entre sessões. Promovê-las
custa quase nada e transforma o que os probes provaram em contrato
executável permanente. O único cenário para "não" seria querer fixtures
com outro vocabulário ou outra organização — decisão estética do Diego,
por isso foi perguntado em vez de assumido.

Em resumo: **recomendado sim na 1, opção (a) na 2, e sim na 3** — e as
três juntas formam um pacote coerente: "faça a B4g como especificada".

**Desfecho: o Diego aprovou as três em 2026-07-07.**
