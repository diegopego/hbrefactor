# Changelog

Escrito para o **programador Harbour final**: o que cada entrega muda no
seu dia a dia, com exemplos e limites honestos. O "como" interno (fases,
specs, decisões) vive em [docs/roadmap.md](docs/roadmap.md) e nas specs
de `docs/`.

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
