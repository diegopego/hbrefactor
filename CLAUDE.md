# hbrefactor

Refatoração automatizada para Harbour sobre a AST do compilador
(dump `.ast.json` do branch feature/compiler-ast-dump). Fontes de verdade:
docs/roadmap.md, docs/ast-schema.md e o Makefile — LER antes de codar.

**Este arquivo é a lei; `docs/cicatrizes.md` é a jurisprudência** — cada regra aqui é
um imperativo curto com uma linha de porquê, e o erro concreto que a comprou está lá,
datado (as referências `[cic §N]` apontam para a seção). Antes de achar que uma regra é
excesso de zelo, leia a cicatriz dela. Regra nova entra AQUI; a narrativa dela, lá.

---

## 1. A REGRA DO FATO — o princípio central

**Meta: ZERO INFERÊNCIA.** O hbrefactor age só sobre FATO produzido por compilação.
Nada de heurística, nada de réplica de gramática, nada de TRIAGEM (ajuda probabilística
para conferência manual não é produto). Quando o fato não existe, o caminho é
(a) **estender o core** para o fato passar a existir, ou (b) **usar ferramenta do core**
como oráculo (compilador-biblioteca, hbmk2, `.ppt`, tabelas DECLARE) — **nunca**
construir inferência. *(Diego, 2026-07-08.)*

- **CORE = qualquer coisa oficial do projeto Harbour**, não só o compilador: hbrun,
  hbmk2, hbpp, RTL/VM, utilitários, a árvore inteira. Estender ou usar qualquer um deles
  vence qualquer esperteza na ferramenta.
- **O princípio vale para TODO construto** (função, local, var, método, marker, palavra
  de DSL) — **classes são só um caso**. O Harbour se apoia em diretivas para criar açúcar
  sintático: DSLs e comandos novos, do core ou inventados pelo programador no próprio
  aplicativo. O hbrefactor refatora QUALQUER código, com ou sem açúcar, **sem ajustes**
  quando diretivas criam açúcar novo. Fato faltante → fato de compilação ou relato honesto
  (`possible`/recusa com rollback); nunca ajeito, nunca árvore quebrada.
- **Prova executável**: casos 64 e 72-74 (régua: nenhuma palavra de DSL de fixture em
  `src/hbrefactor.prg`). Capacidade entregue sobre hbclass só conta como genérica com
  prova adversarial em DSL inventada NÃO-espelho — régua de `docs/revisao-generalidade.md`
  (revisão concluída em 2026-07-07; o doc segue como régua para trabalho futuro).
- **Nunca editar o não-verificável**: a ferramenta só aplica o que o oráculo prova e a
  recompilação verifica. Conteúdo sem verificação (strings, dados, comentários) recebe
  detecção e relato preciso, **jamais** edição automática — nem com opt-in.
- **Genérico > específico**: comando dedicado só com razão forte (o `usages-dsl` foi
  absorvido pelo `usages`); ao consumir fatos de pp, operar sobre o genérico
  (cabeça/kind/marker), nunca por DSL/família conhecida.

### 1.1 A AUTORIZAÇÃO POR-CASO — a ordem não se pula

Heurística e réplica são **PROIBIDAS por padrão**, e a exploração do core vem **ANTES**
de projetar a solução. *(Diego, 2026-07-12; a regra já existia e eu a quebrava assim
mesmo — o que faltava não era regra, era um mecanismo que RECUSA. [cic §1.1])*

1. **Explore primeiro se o core pode dar o fato.** Projetar a solução na ferramenta e só
   depois perguntar isso é ordem invertida: quando a solução já está desenhada, a
   heurística já venceu.
2. **Se o core pode → o core faz.**
3. **Se o core NÃO pode → isso é uma RECUSA**, e recusa exige varredura registrada (§1.3).
4. **Só então, e SÓ COM AUTORIZAÇÃO EXPLÍCITA DO DIEGO PARA AQUELE CASO**, pode existir
   heurística no hbrefactor. Autorização POR-CASO, igual à de commit: aprovar uma não
   aprova a próxima.

**Como pedir:** (a) o fato que falta, (b) a varredura feita no core, (c) por que o core
não pode dar, (d) a heurística proposta e **onde ela erra**.
**É PROIBIDO** implementar "provisoriamente" e pedir depois — o código provisório é o que
fica.
**O portão é executável:** o hook `.claude/hooks/anti-heuristica.sh` (PreToolUse/Bash)
intercepta o `git commit` e recusa o diff staged de `src/hbrefactor.prg` que cheire a
gatilho. Autorizado, sela-se a linha com
`// FATO-OK(diego,AAAA-MM-DD): <por que o core não pode dar este fato>` — e o selo só se
escreve **depois** do "ok" dele. Auditoria periódica: `docs/prompt-revisao-anti-heuristica.md`.

### 1.2 GATILHOS — os cheiros que obrigam a parar e ir ao core

Ao escrever QUALQUER uma destas linhas, **PARE** e pergunte "o core sabe isto e não me
conta?". *(Catálogo de erros, 2026-07-12 — cada gatilho tem um cadáver embaixo: [cic §1.3])*

1. **Comparação de TEXTO para decidir PAPEL/IDENTIDADE** (`Upper(a) == Upper(b)`, prefixo,
   `Left()`, `$`) quando o dump já tem número/id/índice.
2. **Constante mágica de gramática** (`>= 4`, `Len() > N`) — é réplica de regra do
   compilador. **NADA VERIFICA ISTO** *(Diego, 2026-08-07: "apague")*: o hook tinha uma
   regra e ela foi medida — acusava **54 linhas do fonte, nenhuma heurística** (contagem de
   `aArgs`, de `aAtParts`, de listas), e o alvo dela já estava morto (a aritmética de
   abreviação dBase virou pergunta ao pp, no `PpHeadHit`). **Portão que erra em 100% dos
   casos não protege — treina a contorná-lo, e leva os outros gatilhos junto.** Aqui a régua
   é minha atenção, e é o gatilho mais frágil da lista por causa disso.
3. **"se não é X, então é Y"** sem um fato que SEPARE X de Y.
4. **Re-implementar resolução/busca que o core faz** (achar include, casar nome, expandir).
5. **Casar arquivo por BASENAME** em vez de caminho canônico.
6. **Escolher o canal MAIS BARATO**: *"tem que usar o canal CORRETO, não apenas o mais
   barato"* (Diego). Barato ≠ correto.
7. **OBSERVAR o core em vez de PERGUNTAR a ele** — raspar log, saída de trace, efeito
   colateral de build. O que se observa é o que a ferramenta do core **estava fazendo**;
   o que se pergunta é o **fato**. Se não há canal de pergunta, **crie-o no core**.
   *(Custou o `LoadProject` inteiro: [cic §1.3c])*

**Falta de informação → VÁ AO CORE, IMEDIATAMENTE.** A missão é fazer o core gerar o
MÁXIMO de informação necessária. **"Zero mudança no core" NÃO é virtude — é sinal de
alerta**: se um conserto precisou de esperteza na ferramenta, quase sempre o fato faltava
no core e a esperteza é o sintoma. *(Diego, 2026-07-12. [cic §1.2])*

**ESTENDER O CORE É O CAMINHO PADRÃO, NÃO A EXCEÇÃO** *(Diego, 2026-07-13)*: identificada
uma necessidade, a pergunta certa é *"como o core passa a responder isto?"* — e não *"como
eu me viro com o que ele já dá?"*. **É isto que temos que fazer ao máximo possível.**
- **Para PROJETO, o hbmk2 é SEMPRE a fonte de verdade** — build, quais arquivos compõem o
  projeto, includes, flags. Ele é core. Nada de parse nosso, nada de inferência.
- **Ao estender: NUNCA mude a saída de um comando existente — crie um comando NOVO**
  *(Diego, 2026-07-13)*. Quebrar quem já consome o core é inaceitável, e o PR morre.
  *(Foi assim que nasceu o `hbmk2 --hbproject`: o `--hbinfo` ficou byte-idêntico.)*

### 1.3 Nunca declare IMPOSSÍVEL sem VARRER a superfície do core

Toda recusa ("o pp não consegue X") é uma **afirmação sobre o CORE** e exige varredura
ANTES, com o que foi varrido **registrado na spec**: (a) `harbour`/`hbmk2` `--help`
inteiro (flags existem e são esquecidas: `-gd`, `-sm`, `-u`, `-p`/`-p+`); (b) a **API
pública** (`include/hbpp.h` e afins); (c) **`tests/` do core** — é lá que a API viva
aparece; (d) ChangeLog.
**Silêncio de busca minha NÃO é evidência de ausência**; "não achei" quase sempre é "não
procurei". *(Custou um veredito errado publicado: [cic §1.4])*

**E vale para SONDA, não só para busca** *(2026-07-27)*: sonda que responde silêncio exige
**controle positivo** antes de virar afirmação — `which bison` mudo virou "bison não está
instalado, nenhuma rota compila", e o bison 3.8.2 estava em `/usr/bin`, no PATH. É o mesmo
princípio do `TestExtrai` em `tests-go/docs/`: *guarda cujo extrator emudece passa verde sem
verificar nada*. Eu escrevi esse controle para o código e não o apliquei a mim. *([cic §1.3e])*

### 1.4 Editar o harbour-core não é permissão — é DEVER

A ferramenta age só sobre fato da AST; a AST é produzida pelo core; logo **moldar a AST**
— estendendo o core para o fato existir — faz parte da definição da ferramenta. Uma
ferramenta que não pode construir a AST de que precisa está amputada do próprio princípio.
*(Diego, 2026-07-09.)*

Permissão **total e esperada** de editar o clone do core — **onde ele está quem diz é
`sh tools/hbenv.sh --print HB_CORE`**, a fonte única (caminho cravado aqui envelhece: já
apontou para um diretório inexistente, e a `additionalDirectories` do `settings.json` foi
junto) — (branch
`feature/compiler-ast-dump`, acesso no `.claude/settings.json`). O único freio é o de
sempre: **commit no core continua sob autorização por-commit do Diego** — não editar ≠
não commitar.

### 1.5 Não existe compatibilidade para trás — a ferramenta está sendo INVENTADA

O dump é gerado **na hora**, a cada comando, pelo `harbour` do `HB_BIN`. Logo **não existe
"dump antigo"**: existe **toolchain fora de passo**, que é erro de build — e erro de build
se **BERRA**, nunca se degrada. *(Diego, 2026-07-13. [cic §2.1])*

- O schema é **EXATO** (`AstSchema()`, um só lugar), não piso e jamais lista enumerada —
  divergiu, recusa alta nomeando as duas versões.
- **Nenhuma DEGRADAÇÃO por versão** ("dump sem o canal X degrada para possible"):
  degradar rebaixaria o **VEREDITO** por causa de um build velho, **calado**.
- A suíte **sempre roda no schema corrente**; o **caso 122** fica vermelho no instante em
  que core e ferramenta divergirem.

### 1.6 A IA é CONSUMIDORA de fato — jamais FONTE de fato

*(Diego, 2026-07-13. Fase A no roadmap; spec: `docs/spec-a-oraculo-para-agentes.md`.)*

**O agente propõe a INTENÇÃO; a ferramenta decide o que é PROVÁVEL, executa verificando, e
recusa com MOTIVO.** LLM é máquina de **heurística**; o hbrefactor é máquina
**anti-heurística**. Não é contradição — é **complementaridade**, e é ela que dá sentido ao
produto: o programador vai pedir a um LLM *"renomeie este método no projeto inteiro"*, o LLM
vai fazer isso por **substituição de texto** — com confiança, e errado —, e **esse é
exatamente o modo de falha que esta ferramenta existe para eliminar**. O agente não é "mais um
consumidor": é o que **mais precisa** de um oráculo de fato.

- **NÃO-OBJETIVO:** a ferramenta **não tem modelo, não tem chave de API, não fala com rede, e
  NUNCA pergunta nada a um LLM**.
- **Tratar IA como cidadã de primeira classe muda a SUPERFÍCIE, jamais o motor** — saída
  estruturada, código de motivo na recusa, o verificador exposto. Nenhum princípio desta seção
  cede em nome de "ser AI-first"; se ceder, o rótulo virou **cavalo de Troia da heurística**.
- **A recusa tem de ser legível para o agente RELATAR, não para CONTORNAR.** Recusa que o
  agente não entende não protege ninguém — ele volta a **editar o texto na mão**. Todo código
  de recusa diz o que FAZER: *"pare e conte ao humano"* × *"repita com a flag"* × *"seu projeto
  não compila"*.
- **Corolário do lado da CRIAÇÃO:** contra o modo de falha de um contribuidor heurístico (que é
  o que eu sou), o que funciona neste repo é **PORTÃO**, não documento — o hook
  `anti-heuristica.sh`, a régua-grep do caso 64, o schema que berra. **Regra nova sem portão
  novo é regra que eu vou violar de novo.**

  > **PORTÃO, definido — e a palavra é RESERVADA a isto** *(Diego, 2026-08-07: "o próprio
  > termo portão parece estar criando confusão")*: **um mecanismo que RODA e REPROVA.** Hook
  > que barra o commit, teste que fica vermelho, alvo do `make` que sai não-zero, compilador
  > que recusa. Três perguntas, e as três têm de ser sim: *roda sozinho? falha quando a regra
  > é violada? já vi essa falha acontecer?*
  >
  > **Se precisa de adjetivo, não é portão.** "Portão executável" é redundante; "portão de
  > degradação" (um caminho que DEIXA passar) e "portão de autorização" (um protocolo entre
  > mim e o Diego) eram a mesma palavra para conceitos opostos, e foi assim que eu escrevi
  > *"não tem portão executável"* — contradição em termos — dias depois de escrever esta
  > seção. **A palavra não era o problema: eram três conceitos num rótulo só.** Os outros dois
  > perderam a palavra; regra sem mecanismo diz **"nada verifica isto"**, que é exato e mais
  > duro.

### 1.7 A lei vale para o MEU RACIOCÍNIO, não só para o código da ferramenta

*(Diego, 2026-07-27: "o quanto eu tive que guiar o claude a investigar com precisão". Quatro
empurrões numa sessão, os quatro mudaram a resposta. [cic §1.3e])*

A ferramenta não pode inferir sobre o código do usuário; **eu não posso inferir sobre o
core**. É a MESMA regra, e eu vinha aplicando só de um lado: dentro de `src/hbrefactor.prg`
eu paro no gatilho, mas ao **projetar** uma extensão de core eu lia o fonte, deduzia e
propunha — que é exatamente a heurística que o projeto existe para matar, feita por mim.

> **É a [§1.8](#18-exercite-o-código-antes-de-opinar--e-experimente-para-matar-a-sua-tese)
> aplicada ao CORE** — lá está a regra geral; aqui, o que ela exige quando o alvo é o
> compilador, e os cadáveres que só aparecem nesse terreno.

1. **A TABELA DE SONDAS é a forma que a §1.8 toma aqui:** cada classe de caso × o que o
   core responde HOJE × o comando que produziu a resposta. Sem ela o mecanismo vai para a
   spec com cara de fato. *(Custou um mecanismo errado já escrito no roadmap: li
   `nBirthTok` como "o índice do token do nome", e um dump de 30 segundos mostrou que ele
   varia com o lookahead.)*
2. **"É caso raro" é afirmação sobre o mundo** — ou se mede no corpus, ou não se escreve.
   *(Classifiquei "sítio sem coluna" como canto; são 40% dos sítios, porque código real é
   construído sobre DSL.)*
3. **Ler o FONTE não substitui PERGUNTAR ao binário.** Comentário e struct dizem o que o
   autor pretendia; o dump diz o que sai. Discordando, manda o dump.
4. **Empurrão do Diego = sonda pulada.** Quando ele diz "investigue com precisão" ou
   "decida corretamente", a leitura certa **não** é "responda melhor" — é **"existe uma
   medição barata que eu não fiz"**. A resposta é rodar a sonda, não argumentar melhor.
   *(É prima da §1.3d: lá eu produzia defesa; aqui, prosa no lugar de medida.)*
5. **LISTA DE NOMES QUE EU ESCOLHO É HEURÍSTICA — mesmo quando cada nome é real.** O gatilho 1
   do §1.2 fala de comparar TEXTO; o disfarce é comparar **símbolo resolvido pelo compilador**
   contra uma lista que **eu** montei. O símbolo é fato; a lista não é. *(Flagrado 2026-07-27:
   propus trocar o casamento de string por `calls[].sym ∈ { __mvGet, Type, hb_macroBlock }` e
   chamei isso de "substituto honesto" — era a mesma heurística um nível acima do texto puro. O
   Diego cortou: **"me recuso a ter heurística nele"**.)* A pergunta que desarma: **quem é dono
   deste conhecimento?** Se é a RTL, o fato mora no core — e o core costuma já ter a casa
   (ali era a `s_stdFunc` do `hbfunchk.c`, onde o `TYPE` já estava). Se ninguém no core pode
   ser dono, **a ferramenta não suporta o caso e diz isso**.
6. **OS 5 PORQUÊS quando a causa não é óbvia** *(Diego, 2026-08-06)*. **O método dos 5 Porquês
   (5 Whys)** — criado na Toyota Motor Corporation por **Taiichi Ohno** — consiste em perguntar
   *"por quê?"* cinco vezes de forma consecutiva, cada resposta virando a pergunta seguinte,
   para ir **além do sintoma superficial e achar a CAUSA RAIZ** da falha. Usar quando:
   - um defeito reaparece (a correção anterior pegou o sintoma, não a raiz);
   - se vai propor REGRA, PORTÃO ou capacidade nova — a cadeia diz se a necessidade é real
     e onde ela nasceu, e às vezes mostra que a resposta certa é OUTRA (não a que eu já tinha
     desenhado);
   - se vai investir em algo caro, antes de investir.

   **A régua:** a cadeia termina numa causa **acionável**, não numa lamentação — e cada elo é
   FATO verificável, senão os cinco porquês viram cinco palpites empilhados, que é pior que
   nenhum (§1.7.3: o dump manda, não a dedução). Se a raiz for "não medi", a resposta não é
   escrever melhor — é **medir** (item 4 acima).
7. **"EU RODEI E PASSA" × "O TESTE REPROVA" → a primeira pergunta é sobre o INSTRUMENTO**
   *(2026-08-07)*. Antes de duvidar do dado, duvide de estar rodando o mesmo programa:
   `type -a <cmd>`. Neste ambiente o `grep` do shell interativo é uma **função** que delega
   para o `ugrep`, e o `make test` chama o `/usr/bin/grep` — os dois discordam em `-w` sobre
   acento, e eu relatei **seis medições seguidas** dizendo que a régua estava limpa enquanto
   o teste dizia o contrário. Vale para tudo que o shell intercepta (função, alias, wrapper,
   PATH), e **vale em dobro quando o meu resultado é o cômodo**: ali cada medição "limpa" me
   dizia que o problema era do teste. É prima da §1.3e com uma torção — não houve silêncio,
   houve resposta clara e errada, e o controle que faltava não era sobre o alvo, era sobre o
   instrumento. *([cic §5.1c])*

8. **PASTA DE SONDA É DE USO ÚNICO — a ferramenta EDITA os fontes** *(Diego, 2026-08-08:
   "precisa resolver este comportamento", depois da TERCEIRA contaminação no mesmo dia)*.
   Reusar um diretório de sonda faz o **"antes" da medição ser o "depois" da anterior**, e
   o modo de falha não é silêncio: é **resposta errada e confiante**. Os três cadáveres do
   dia: rodar `usages` onde um `rename` já havia editado; "restaurar" com `sed` e medir
   (o nome velho já era o novo); e copiar como modelo uma pasta que o script anterior
   editara. **A régua: toda sonda começa por um diretório NOVO com o estado inicial
   registrado**, nunca por um `mkdir` meu com nome escolhido a dedo:

   ```sh
   D=$(mktemp -d) && cp -r <fixture>/. "$D" && git -C "$D" init -q \
      && git -C "$D" add -A && git -C "$D" commit -qm base
   git -C "$D" diff --quiet   # intacto? então pode medir
   git -C "$D" status --short # depois: o que a ferramenta mexeu
   git -C "$D" checkout .     # e volta ao inicial, se precisar
   ```

   **Eu escrevi um `tools/probe.sh` para isto e ele foi DELETADO no mesmo dia** *(Diego,
   2026-08-08: "se já existe solução pronta ou precisa mesmo criar")*. Ele não fazia nada
   que `mktemp -d` + `git` não façam, e **causou a contaminação que existia para impedir**:
   um bug de zero à esquerda na aritmética do contador devolvia diretório VAZIO a partir da
   nona sonda, e `cd ""` deixa você onde já estava. Medido, reconstruindo a versão com bug.
   Ferramenta caseira num caminho de MEDIÇÃO é superfície nova de erro, e erro de medição
   não grita — ele responde.

### 1.8 EXERCITE O CÓDIGO ANTES DE OPINAR — e experimente para MATAR a sua tese

*(Diego, 2026-08-07, e o custo adicional é ACEITO de propósito: "vai custar mais, vai demorar
mais, mas vai trazer respostas assertivas com embasamento".)*

**Tudo que envolve código exige exercitá-lo antes** — ler código alheio, propor código novo,
corrigir, estimar, opinar, planejar. O ciclo é **experimente → veja se o prognóstico mudou →
decida se explora mais → só então apresente**; apresentar antes de medir é a ordem invertida
do §1.1 aplicada ao meu raciocínio. O escopo é largo de propósito: lista de casos que obrigam
seria só os erros da sessão que a gerou, e fronteira eu disputo de boa-fé.

**A postura é ADVERSARIAL:** o experimento existe para DERRUBAR o que eu ia dizer. Se ele só
confirma, quase sempre escolhi o errado — o certo é o que me contradiria. **Comando que não
podia dar outro resultado não é experimento, é enfeite.**

**Escolher e parar:** o mais barato que pode me contradizer, não o mais completo — e, havendo
suíte, **aplicar de verdade** (mude, rode, conte, reverta) é o mais honesto. **Pare quando o
prognóstico parar de mudar.** Ao apresentar: a afirmação, o comando, o resultado — e **dizer
o que caiu**, porque argumento derrubado é resultado, e é o que impede decisão sobre premissa
morta. *(Prima do §4: "anunciar" inclui a conversa em que se decide.)*

> **ESTA REGRA NÃO TEM PORTÃO — nada verifica isto, e ela é a mais frágil da §1.** Ela governa a minha
> prosa, que nada no repo verifica. Pelo §1.6 isso a torna uma regra que eu vou violar de
> novo — o único freio é eu apresentar o comando junto da afirmação, e o Diego notar quando
> não vier. *(Dois cadáveres de 2026-08-07: afirmei que uma IDE recorta `text[start:end]` e a
> extensão **nunca lê `text`** — o consumidor era invenção minha; e estimei "38 expectativas"
> onde eram **67**. Narrativa em [cic §1.8].)*

---

## 2. Core e toolchain

- **BUILD DO CORE É SEMPRE LIMPO — `make core`, e nada de incremental** *(Diego,
  2026-08-06: "não se deve usar a compilação incremental para evitar surpresas. isso se
  aplica ao harbour e ao hbmk2")*. O `make` do core **não rastreia `#include`**: editar
  um header — ou um `.c` que outro inclui, como o `include/hbexprb.c` — e rodar `make`
  sai **exit 0 sem recompilar nada**, e a medição seguinte responde do binário VELHO.
  Não é ruído: é o modo de falha que produz diagnóstico inventado, porque a ferramenta
  roda e responde. **Nunca `make` no core direto; nunca "apago só os `.o` que eu acho
  que mudaram".** *([cic §5.1])*
  - `make core` faz `make clean && make` e **CONFERE que `harbour` e `hbmk2` relincaram
    NESTE build** (mais forte que comparar com o fonte: a prova é um stamp tirado no
    início). O hbmk2 **EMBUTE** o compilador, por isso são os dois sempre.
  - **Limpo NÃO quer dizer sem compilador**: os binários de agora são guardados fora da
    árvore e devolvidos ao lugar logo após o `clean`, então seguem servindo durante todo
    o rebuild — e **um build que falha deixa os velhos de pé**. Antes eram ~2min30 sem
    `harbour`, e o sintoma para quem esbarrasse na janela era o enganoso *"o projeto não
    compila"* (§5.2). Medido: 90 compilações durante um `make core`, **0 falhas**.
  - **Mora no Makefile, não num script** *(Diego, 2026-08-06: "é preferível do que ter
    scripts espalhados")*. `make core-check` roda só as conferências, em 1s, e responde
    a pergunta cujo NÃO responder custou os dois diagnósticos: *o binário que eu estou
    medindo é o do fonte de agora?* É contra ele que os controles negativos rodam.
  - Ele também fecha a armadilha do parser: `HB_REBUILD_PARSER=yes` regenera o
    `obj/<plat>/harboury.c`, **não** os `harbour.yyc`/`.yyh` **commitados** (que são o
    que um checkout limpo usa). Mudou o `harbour.y`, o script regenera e regrava os dois
    — **commitar os três juntos** (`.y` + `.yyc` + `.yyh`).
  - **Controle positivo barato do ritual do parser**: rodar o bison **sem mudança
    nenhuma** e diferenciar contra o `.yyc` commitado; divergir só nos `#line` e no
    include guard prova que a sua versão é a que gerou o commitado. *([cic §5.1e])*
- **SÃO DOIS TOOLCHAINS, e QUAL SE USA QUANDO está escrito em CÓDIGO, não aqui**
  *(Diego, 2026-08-06: "mais importante ainda é que esteja escrito em código que se usa
  os dois toolchains e quando usar cada um")*. A fonte única
  [`tools/hbenv.sh`](tools/hbenv.sh) define os dois e documenta o papel de cada um no
  lugar onde todo consumidor lê:
  - **branch** (`HB_BIN`, `make core`) — compila, analisa e verifica: **todo** o
    trabalho. Reconhece-se por carregar `ast-N`;
  - **stock** (`HB_STOCK_BIN`, `make stock`) — worktree de `upstream/master`; **não
    trabalha**, existe para ser COMPARADO. Reconhece-se por **não** carregar `ast-N`.
  - **Confundir os dois não dá erro, dá VERDE FALSO** — medir o remendado contra ele
    mesmo prova nada e passa. Por isso o papel é **conferido em execução**, não confiado
    a quem chama: `make core-check`, `make stock-check`, e o próprio
    `pcode-identity.sh` **recusa** argumentos trocados. O `hbenv.sh` recusa `HB_STOCK ==
    HB_CORE`.
  - `make pcode-identity` constrói o stock se faltar e mede. Em 2026-08-06, com o parser
    regenerado e `%locations` ligado: **889/889 `.hrb` byte-idênticos, 0 divergentes**.
- **Exportar `HB_BIN` ao invocar a ferramenta fora do Makefile**: sem ele o `HbMk2Bin()`
  cai no hbmk2 do sistema e o sintoma é o enganoso "o projeto não compila". *([cic §5.2])*
- **Ferramenta do core: PROBE, nunca memória**: antes de consumir a saída de um utilitário,
  sonde ONDE ele escreve e O QUE reporta — com fonte em **subdiretório** (o caso que
  quebra). Não se adivinha o destino: manda-se (`-o<tmp>`). **Depois de qualquer comando
  que rode o compilador ao lado dos fontes, conferir `git status`** — `.d`/`.ppo`/`.c`
  vazam para o repo. *([cic §1.5])*
- **Chave OPCIONAL do dump: sempre `hb_HGetDef`** — campo que só existe em ALGUNS papéis
  (`marker`, `ruletok`, `from`, `generates`, `col`) acessado direto é BASE/1132 em
  produção, e a suíte não pega. Ler o contrato no ast-schema.md ANTES. *([cic §1.6])*
- **Reutilizar o hbmk2** (builder oficial) para projeto/flags/build: entende `.hbp`/`.hbc`,
  resolve `-I`/`-D` (`hbmk2 -trace` expõe a linha do harbour), repassa `-prgflag=`. Todo
  parsing paralelo é cópia degradada que diverge.
- Fluxos definidos vivem no **Makefile**; hbmk2 direto é só experimentação.

---

## 3. Testes, suíte e corpus

- **Contrato executável: `make test`** — deve permanecer verde.
  > *(Houve UM vermelho commitado de propósito entre 2026-08-06 e 08-07 — o TDD da P24,
  > porque untracked morre num `git clean -fdx` e perder o contrato é pior que um
  > vermelho conhecido. A entrega da P24 o tornou verde e a exceção morreu. O padrão
  > continua sendo o TDD ficar FORA do git até a entrega que o torna verde; quando a
  > frente for ficar parada, a troca acima é a que vale.)* Ele cobre `tests/run.sh`,
  `govet`, **`lexdiff`**, **`site-check`** e `gotest`, nesta ordem. *(Os dois do meio
  entraram em 2026-07-27: ao remover um comportamento eu enumerei os testes afetados
  rodando `make test`, reportei três, e **faltava um quarto** — o exemplo da landing page
  que anunciava ao leitor a proteção recém-removida. Ele só apareceu por acaso. Portão de
  afirmação-que-o-usuário-lê fora do contrato é portão que não existe. [cic §6.5])*
  **Portão novo nasce DENTRO do `make test`**, e antes do `gotest` se for barato: a cadeia
  para no primeiro erro, e um vermelho de TDD longevo emudece tudo o que vier depois.
- **FIXTURE EXPECTED, padrão TDD (casedir) onde couber** *(Diego, 2026-07-25)*: um `grep` de
  saída — mesmo migrado para campo estruturado (`tcheck enveq/envhas`) — é **FRÁGIL**: prova um
  pedaço, nunca o que a ferramenta **NÃO** disse. O caso declarativo (`tests/casedir.sh`:
  `before/` + `cmd` + `out` byte a byte [+ `after/`]) prova a saída **INTEIRA**. **Preferir
  casedir para toda asserção de saída de comando único**; reservar imperativo + helper
  estruturado só para o que casedir não modela (idempotência A→B→A, saída-de-programa idêntica,
  bateria multi-passo de recusa). *(A régua-canais — "a prosa não mostra fato que o JSON não
  tem" — só vale para o comando que ela EXERCITA: comando com prosa mais rica que `usages`
  simples merece o seu próprio caso, senão o gap volta calado. [achado no gap de usages-DSL])*
- **O FORMATO DE TESTE TEM SPEC PRÓPRIA: [`tests/README.md`](tests/README.md)** *(Diego,
  2026-07-26)* — todo teste novo a segue, e **teste que não couber vira PROPOSTA DE MUDANÇA
  LÁ, antes de ser escrito**. Ela é durável de propósito: não é handoff nem memória. O estado
  da migração fica no handoff/roadmap; o contrato, só lá.
- **A ORDEM É TDD, e ela não é detalhe** *(Diego, 2026-07-25/26)*: *"escreve os arquivos
  expected, depois escreve o arquivo que vai ser alterado, e compara a saída do actual vs
  expected"*. O `expected/`/`output` se escreve **À MÃO, ANTES**, do CONTRATO e da fixture —
  nunca se GRAVA de uma execução. Gravar produz um arquivo idêntico e um teste diferente:
  golden-file prova que nada **mudou**, TDD prova que está **certo**. **É PROIBIDO ferramenta
  que grave expected** (escrevi uma; foi deletada). Única exceção, estreita: o **retrato do
  `.ppo`/`.ppt` do core** (`make oracle`), onde a autoridade é o core e não nós. O que fica é
  a régua de derivação: **coluna se COMPUTA** do arquivo (§7), nunca se conta na cabeça.
  *([cic §6.4])*
- **Compile todo `.prg` (fixture, exemplo, teste) ANTES de usá-lo** —
  `$HB_BIN/harbour arquivo.prg -n -q0` ou o projeto via hbmk2. Fixture que não compila
  gera diagnóstico enganoso.
- **`make test JOBS=1` só ao mexer no RUNNER** *(Diego, 2026-07-10)*: o contrato "paralelo
  × JOBS=1 byte-idêntico" é propriedade da INFRA (bin/parrun, `--unit` do run.sh, join),
  não do conteúdo dos testes. Rodar JOBS=1 apenas quando a mudança tocar o runner ou
  introduzir saída potencialmente não-determinística (ex.: imprimir na ordem de iteração
  de um hash).
- **Drift em teste PRÉ-EXISTENTE → consultar o Diego** *(2026-07-10)*: o projeto é um
  experimento VIVO — há motivos legítimos tanto para adaptar o código aos testes quanto
  para **re-baselinar** os testes (contrato que evoluiu). **A premissa errada pode ser a do
  teste, e quem decide qual lado cede é o Diego**: apresentar o drift site a site (o que
  mudou, por quê, qual contrato está em jogo) ANTES de escolher o lado. Teste novo da
  própria entrega não precisa de consulta; re-rotular expectativa antiga, sim.
- **CORPUS DE MATURAÇÃO = código do CORE do Harbour** *(Diego, 2026-07-10)*: a ferramenta
  amadurece em código bem escrito e testado (`work/` = cópias de pastas do core; copiar
  mais pastas quando a fase pedir). O código do Diego (`~/devel/bravo-experimento*`) é
  bagunçado e pré-melhores-práticas — serve para exploração pontual e SÓ isso, **nunca**
  como régua de valor de fase nem alvo de entrega. *(Nuance da **xhb**: braço xHarbour,
  não-mantido — vale como corpus de MEDIÇÃO, mas número vindo só dela não justifica
  capacidade sozinho.)*
- **ESTUDAR CLASSE: os dois pontos de partida** *(Diego, 2026-07-13)* — vale para qualquer
  frente que toque OOP (tipo de receiver, rename de DATA/método, dispatch, herança):
  - `$(sh tools/hbenv.sh --print HB_CORE)/include/hbclass.ch` — a **DSL inteira** (`CREATE CLASS`,
    `METHOD`, `DATA`, `VAR`, `INLINE`, `DELEGATE`, escopos): é o açúcar que a ferramenta
    tem de atravessar, escrito em `#command`/`#translate` de verdade.
  - `$(sh tools/hbenv.sh --print HB_CORE)/utils/hbtest/rt_class.prg` — o **exercício** dela pelo
    core: as formas todas em uso, compilando, com oráculo executável.

  Continua valendo a régua do corpus: espécime é fonte do core, nunca exemplo que eu
  invento (§ acima) — e o que eu **entender** aqui não vira gatilho em `src/hbrefactor.prg`
  (§1: capacidade sobre hbclass só conta como genérica com prova adversarial em DSL
  inventada).

---

## 4. Medição e anúncio

- **O número que se ANUNCIA é o do PRODUTO rodando como o usuário roda** (comando
  completo, projeto real do corpus), nunca o do microbenchmark. O stress serve para achar
  a **curva** (quadrática × linear), não para dimensionar a notícia. *(Diego, 2026-07-13.
  [cic §3.1])*
  - **E "anunciar" INCLUI a conversa em que se decide** *(2026-08-07, reincidência)*: um
    número que sustenta *"vale a pena fazer isto"* já é anúncio, mesmo que morra no chat e
    nunca chegue ao CHANGELOG. Foi assim que um "28×" de microbenchmark (só a etapa de
    compilação, projeto que eu mesmo gerei) virou o argumento de uma fatia cujo ganho real
    é **1,6×** — e o Diego aprovou ouvindo o número inflado. Ler o §4 como regra de
    PUBLICAÇÃO é o erro: o estrago acontece antes, na priorização.
- **"Tamanho típico de aplicação real" é uma afirmação sobre o mundo** — ou se mede no
  corpus, ou não se escreve. Afirmar sem medir é a heurística vestida de manchete.
- **O projeto do benchmark tem de PASSAR**: conferir o **exit** E que ele **leu/analisou**
  de fato. Cronometrar processo não é medir trabalho — **comando que morre também gasta
  segundos**. *([cic §3.2])*
- **NÃO PUBLIQUE TABELA DE BENCHMARK**: ela não serve ao leitor (não é a máquina dele, nem
  o projeto dele) — serve ao autor, como defesa. No anúncio vai a **afirmação** + o
  **comando** para o leitor medir no projeto dele. *([cic §3.3])*
- **NENHUM NÚMERO NAS PÁGINAS — todo indicador vira COMANDO** *(Diego, 2026-07-13)*: nenhum
  tamanho de suíte, contagem de casos ou de schemas nas `site/index.html` (dos DOIS
  repositórios). O leitor recebe o comando que ele roda (`make test`,
  `tools/pcode-identity.sh`, `git diff --stat`) — e comando não envelhece. **Automatizar um
  número frágil é pior que não tê-lo.** *([cic §3.4])*
- **EXEMPLO NA PÁGINA: só o que se EXECUTA sozinho** *(Diego, 2026-07-12)*: nenhum bloco de
  fonte e nenhuma saída de terminal da `site/index.html` se escreve à mão. Os exemplos
  vivem em `tests/site/` (contrato em `tests/site/README.md`), `make site-examples`
  re-executa e regrava os blocos, e **`make site-check` FALHA** se a página divergir.
  Quatro portas por exemplo: o fonte ANTES compila limpo, o comando sai com o exit
  esperado, o fonte DEPOIS compila limpo, e recusa/relatório deixam o fonte **byte a byte
  intacto**. *([cic §3.5])*
  **Dívida aberta**: as seções profundas da página (rename de DATA, genealogia de regra,
  tempo de vida de diretiva, sequestro por abreviação) ainda têm transcript colado à mão —
  corretos hoje, mas FORA do portão; migrá-los para `tests/site/`.
- **Números em `docs/roadmap.md`, specs e mensagem de commit CONTINUAM** — lá são registro
  datado da entrega, não promessa viva ao leitor.
- **VERIFICAR A BASE antes de concluir dela**: antes de comparar contra qualquer ref,
  `git fetch` e conferir a que altura ela está — **o fato do diff é tão bom quanto a base
  dele**. Base do branch do core = `upstream/master`, nunca o `master` local. *(O `push` do
  `upstream` está **DISABLE** de propósito. [cic §3.6])*

---

## 5. Documentação, idioma e anúncio ao usuário

- **O PRODUTO É EM INGLÊS; a CONVERSA é em português** *(Diego, 2026-07-13)*. A régua não é
  o repositório, é **quem lê**:
  - **Inglês** (lido pelo usuário): mensagens da CLI, `docs/manual.md`, `site/index.html`,
    `CHANGELOG.md` e **toda string que a extensão VSCode mostra** (modais, placeholders,
    erros).
  - **Português** (nosso RACIOCÍNIO, não o produto): `CLAUDE.md`, `docs/roadmap.md`,
    specs e `tests/*/README.md`. *([cic §4.1])*
  - **REVISÃO (Diego, 2026-08-07): CÓDIGO e COMMIT são INGLÊS.** *"Este projeto,
    internamente, usa inglês."* Saem do lado português e passam para o inglês: os
    **comentários do fonte** (`src/hbrefactor.prg`, os testes Go) e a **mensagem de
    commit do hbrefactor** — que antes era a única exceção contra o core, e deixou de
    fazer sentido. A régua deixa de ser "quem lê" e passa a ser **o que é**: artefato do
    projeto é inglês; documento de raciocínio nosso é português; a conversa é onde você
    quiser.
    **Vale do 2026-08-07 em diante.** O acervo em português fica como está — converter em
    massa é decisão do Diego, não faxina de sessão. Arquivo misto durante a transição é
    esperado e não é defeito.
    *(Cuidado ao mexer nos testes Go: os IDENTIFICADORES da infra são portugueses
    (`registra`, `Projeto`, `Roda`, `Recusa`, `Aponta`). Renomeá-los é refatoração à
    parte; comentário novo em inglês ao lado deles é a transição, não inconsistência a
    "consertar".)*
- **TUDO no harbour-core é em INGLÊS**: código, comentário, documentação **e mensagem de
  commit** — o projeto é internacional e este branch é upstreamável (fase B6). *(Diego,
  2026-07-12. [cic §4.2])*
- **DOIS changelogs de USUÁRIO, um por repositório** — `CHANGELOG.md` aqui, **`NEWS.md`** no
  core *(a assimetria é deliberada e **não se re-litiga**: [cic §4.4])*. **Cada repositório
  com commit novo ganha a sua entrada.**
  - **O público é o PROGRAMADOR HARBOUR FINAL, nunca o contribuidor**: o problema de todo
    dia, o que muda na prática (antes/depois quando couber), o que a ferramenta NUNCA faz,
    e os limites honestos. **O changelog do contribuidor já existe e é o git.** A entrada só
    se justifica ao responder o que o git NÃO responde: *"o que eu passo a poder fazer, e
    onde isso me morde?"*
  - **Reprova o CORPO da entrada que contiver**: nome de função C / arquivo de
    implementação, nome de struct, jargão de build, número de caso da suíte, sigla de fase.
    *(Ponteiro para docs internos no FIM da entrada é permitido; citar a saída REAL da
    ferramenta é sempre permitido.)*
  - **Ponteiro de delta** no topo (`<!-- changelog-baseline: <repo>@<sha> -->`): o último
    commit já descrito. É o que torna o serviço **retomável** (`git log <baseline>..HEAD`
    diz o que falta). Fluxo e régua na skill `/update-manual`. *([cic §4.3])*
- **PIPELINE DO CORE: `commit → NEWS.md → landing page`** *(Diego, 2026-07-12)*. A
  `harbour-core/site/index.html` é uma **proposta aos MANTENEDORES** — é ela que decide se o
  PR (fase B6) é sequer avaliado. **Não é um log**: não ganha seção por commit nem lista
  schema; carrega o **conceito consolidado** (argumento central, forma do diff, os quatro
  canais, os bugs do stock que o branch conserta, o pedido ao mantenedor, e o que ainda não
  sabemos). Muda **só quando o conceito muda** — "não mudou" é resposta legítima. **Nenhum
  número nela sem medição na hora.** Checklist na skill `/update-manual` (§ 0.4b).
- **`docs/roadmap.md` é minha responsabilidade e vive preenchido**: fases futuras com escopo
  + critério de pronto ANTES de executá-las; concluída uma fase, atualizar o status na mesma
  sessão; trabalho novo entra como fase/item.
  **Plano ≠ spec** *(ordem do Diego)*: o **plano** (plan mode) decide *como* e *quais
  requisitos* — é o documento de análise/design/racional. A **spec executável** mora no
  `docs/roadmap.md`, no formato das fases existentes (`### Fase X — Título`, `**Escopo**`,
  `**Critério de pronto (mecânico)**`). Ao terminar um plano de código, transforme-o em
  spec e adicione ao roadmap — **não implemente no mesmo passo**, salvo pedido explícito.
- **Extensão VSCode sempre com os últimos recursos**: todo comando/capacidade nova do CLI
  tem que chegar à `extension.js` — expô-la é escopo da fase que a entrega, não fase
  adiável (é o consumidor de uso diário do Diego).

---

## 6. Processo

- **Commits só com autorização explícita do Diego PARA AQUELE commit** — concluir/aprovar o
  trabalho não autoriza o commit. Um pedido por commit, não encadear. **Sem push salvo
  pedido.**
- **GitHub é pelo `gh`** *(Diego, 2026-07-13)*: autenticação e operações via `gh` CLI
  (logado como `diegopego`, ssh), nunca o credential-manager do Windows. *([cic §5.4])*
- **Revisão externa via Codex (`/codex:rescue`)**: o brief é instrumento versionado em
  `docs/` e **não se contamina com o juízo do Claude**; achado externo é **HIPÓTESE** até
  verificação no fonte com arquivo:linha — nunca agir direto sobre o relato. **Tarefa Codex
  pode morrer em silêncio**: antes de esperar conclusão, conferir `ps -p <pid>`; morto =
  cancelar e re-executar com `--model` explícito. *([cic §5.5])*
- **`smoketest/hbrefactor-occ.prg` é a primeira encarnação, arquivada**: só leitura, nunca
  editar.
- **Regra/preferência durável deste repo vai AQUI** (versionado), não na memória privada do
  Claude (que não viaja com o repo); a memória fica para o que não pertence a um repo.

---

## 7. Harbour (linguagem) — armadilhas ao escrever fixtures/.prg

Os fixtures da suíte são `.prg` idiomático (o "caso 0" exige saída limpa sob `-w3 -es2`).

- **Código NOVO nosso usa `#xcommand`/`#xtranslate`, nunca `#command`/`#translate`**
  *(Diego, 2026-07-12)*: provado no dispatch do core (`ppcore.c`) que o `x` significa
  **exatamente e somente** "comparação EXATA" em vez do **dBase** (que casa a palavra
  abreviada a partir de 4 letras). Nenhuma capacidade se perde — e a família dBase é a
  origem de uma CLASSE INTEIRA de ambiguidade (sequestro de regra, recusa falsa, cabeças
  disputando prefixo); na família `x` esses bugs são **impossíveis**. Vale para fixture,
  exemplo, doc e sonda que EU escrever. *(Existe ainda a família `y` — exata E
  case-sensitive.)*
  **DUAS exceções, ambas obrigatórias:** (a) fixture cujo **assunto** é a abreviação dBase
  (`fixabr`/caso 115, `fixseq`/caso 116, o par de cabeças do `fixdsl`) — trocar para `x`
  faria o teste passar por **vacuidade**; (b) a **ferramenta** jamais pode abandonar
  `#command`/`#translate`: ela refatora o código dos OUTROS, e o `std.ch`, o `hbclass.ch` e
  toda a herança Clipper são dBase. **A política é sobre o que escrevemos, nunca sobre o
  que suportamos.**
- **Não nomear variável formando keyword em uppercase**: Harbour é case-insensitive e lê
  identificadores em uppercase — `LOCAL nIL` vira a reservada `NIL` (`E0030`). Evitar
  `nIL`, `cFor`, etc.
- **MEMVAR antes de PRIVATE/PUBLIC**: sem a declaração compile-time, W0002 na criação e
  W0001 em cada uso — com `-es2` o build falha. Idioma: `MEMVAR xCfg` / `PRIVATE xCfg := 7`.
- **`LOCAL x := 0` seguido de `x := <valor>` é DEAD STORE → W0032 → quebra sob `-es2`**: o
  Harbour avisa que o **inicializador** nunca é lido, mesmo que a variável seja lida depois.
  Idioma: declarar **sem** inicializador (`LOCAL nEdits`), ou usar `+=` (que LÊ). *(A
  mensagem "assigned but not used" engana. [cic §6.1])*
- **Comentário de linha `//` em .prg** (não `/* */`): um `*/` que apareça no conteúdo (ex.:
  `assert_*/`) fecha o bloco antes da hora. Aplicar em código novo/editado, sem conversão em
  massa.
- **A régua do caso 64 vale para COMENTÁRIO também**: ela é textual — citar a DSL de uma
  fixture num comentário de `src/hbrefactor.prg` QUEBRA a suíte, e está **certa** em
  quebrar. Ilustre o formato genericamente ("keyword secundária prefixo da cabeça"), nunca
  com as palavras da fixture. *([cic §6.2])*
- **Coluna de probe/teste: COMPUTAR, nunca contar na cabeça** — extrair sempre do arquivo no
  estado **corrente** (`python3 -c "...l.index('<n>')+1"`). Dump é 0-based, CLI é 1-based; o
  `col` de um marker aponta o **NOME**, não o `<`. *([cic §6.3])*
- **Verificar comportamento no fonte do Harbour ANTES de afirmar** (não teorizar): ler/grep
  o `src/` relevante. Ex.: `Empty(" ")` é `.T.` — usar `Len(c) == 0` para "vazia".
- **Diagnóstico do IDE ≠ veredito**: o lint do VSCode usa o harbour do **sistema**, sem os
  patches do branch. A régua é sempre o toolchain de `HB_BIN`. *([cic §5.3])*
