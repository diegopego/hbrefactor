# Corpus do PP — índice

## ⚠️ A INTENÇÃO — o que este corpus É *(Diego, 2026-07-13, palavras dele)*

> *"Quando você junta procurar explicar com precisão o que diretivas fazem, com
> código, `.ppo`, `.ppt`, ast, etc., e alterando o core para coletar mais
> informação sob necessidade, aí você cria um **corpus de compreensão completo do
> pp**."*

**É esta a meta, e ela ordena tudo o mais.** Não é uma lista de famílias a vencer,
não é caça a bug, não é medição por medição. É **compreensão completa**, e cada
peça do método serve a ela:

- **explicar com PRECISÃO o que a diretiva FAZ** — não o que eu acho que ela faz;
- **com CÓDIGO** — fixture real que compila, nunca exemplo de cabeça;
- **com os QUATRO oráculos** (`.ppo` + `.ppt` + ast dump + o código compilável) —
  cada um mostra uma face, e onde eles discordam mora o achado;
- **alterando o CORE quando o fato não existe** — a informação faltante não é
  limite, é **tarefa**: o pp sabe e não conta → faça-o contar (`ast-13`…`ast-17`);
- **e o USO, não só a definição** — as diretivas nas `.ch` são metade; a outra é
  como o Harbour REALMENTE escreve código com elas ([uses-core.md](uses-core.md)).

Os bugs que aparecem no caminho (e aparecem) são **subproduto**: prove, marque,
siga (§ classificação de lacuna abaixo). O produto é a **compreensão**.

### Por que o material de estudo é o PRÓPRIO HARBOUR *(Diego, 2026-07-13)*

> *"Estudar as diretivas de pp que existem no próprio Harbour é o ideal."*

Não é conveniência (o código está à mão) — é que **não existe material melhor**, e
por quatro razões que se somam:

1. **Elas SÃO a linguagem.** `SET EXACT`, `@…SAY`, `STORE`, `CLASS`/`METHOD`/`VAR` não
   são "recursos de pp": são o Harbour que o programador escreve todo dia. Estudar a
   diretiva do core é estudar o que o código do mundo real É.
2. **Foram escritas por quem conhece o pp a fundo** — e por isso **usam os cantos**:
   o guarda anti-recursão, a abreviação dBase, a regra que gera regra, o `#<x>`, o
   `#ifdef` com duas regras rivais. Exemplo que eu invento nunca chega nesses cantos:
   eu só invento o que já entendi. **O core me ensina o que eu não sabia perguntar.**
3. **É o código que a ferramenta TEM de aguentar.** Se ela quebra no core, quebra em
   tudo. O corpus vira, de graça, a régua adversarial mais dura que existe — e não
   escrita por mim (o autor do código não estava pensando em me agradar).
4. **Vem com oráculo executável embutido**: o core compila. Toda afirmação sobre uma
   diretiva dele pode ser conferida na hora, nos quatro oráculos — nada fica no
   "eu acho".

*(É o mesmo princípio do CLAUDE.md § 3: **corpus de maturação = código do CORE**.
Aqui ele se aplica ao conhecimento, não só à validação.)*

---

Fonte de conhecimento viva (fase P, P-DOC): o que o preprocessador do Harbour
REALMENTE faz, provado em diretivas REAIS do core/contribs. Método, formato e
critério: [../spec-pdoc-corpus-pp.md](../spec-pdoc-corpus-pp.md). Guarda
executável SEPARADA do contrato: **`make ppcorpus`** (o `make test` fica
byte-idêntico). Cada família casa a diretiva com os **QUATRO oráculos** — `.ppo`
(expandido) + `.ppt` (traço) + ast dump (mkinds/roles) + fixture COMPILÁVEL — e
explica bilíngue (técnico + programador Harbour).

## ⚠️⚠️ O CORPUS MORA NO `.prg`, NÃO NO MARKDOWN *(ordem do Diego, 2026-07-14 — VIRADA DE MÉTODO)*

> *"Estes textos markdown vão apodrecer. Por isso o código sendo teste, junto com os
> oráculos do core, vira informação de ouro. O melhor dos mundos: uma explicação em
> linguagem natural e comprovação via asserts, juntas, em `.prg`s. Use markdown o
> mínimo possível para o pp-corpus, preferindo uma **superfície markdown mínima** e
> **cobertura máxima com `.prg`s bem explicados e assertados**, usando os oráculos do
> core (dump da AST, `.ppo`, `.ppt`, etc)."* — Diego

**A inversão:** o `.md` deixa de ser o corpus e passa a ser **índice + ponteiro**. O
conhecimento — a explicação **e** a prova — mora no **`.prg`**, que **compila, RODA e
se AFIRMA**. Markdown envelhece calado; um `.prg` que roda **berra** quando a verdade
muda. *(Não é teoria: neste mesmo dia, seis citações `arquivo:linha` das minhas docs
apodreceram em silêncio quando eu editei o core — e uma citação antiga apontava, havia
sessões, para código sem nenhuma relação.)*

**Como escrever a prova — os asserts são do CORE** *(ordem do Diego, 2026-07-14)*: use
o **`hbtest`** (`contrib/hbtest`, `HBTEST <expr> IS <esperado>`) sempre que possível.
*"O `hb_test` prova que o que você encontrou e comentou é verdade."* **E prova de
verdade**: na primeira fixture com asserts, ele **me desmentiu na hora** — o comentário
dizia que o `#<z>` preserva o literal `"&cAlvo"`, e o assert mostrou que em runtime
aquilo vira `"oi"` (string com `&var` é macro-expandida na execução). O `.ppo` sozinho
tinha me deixado acreditar no contrário. **Comentário sem assert é opinião.**

**Regra prática por família:**
1. **`tests/ppc-<fam>/<fam>.prg`** — o corpus de verdade: a diretiva REAL, o comentário
   que EXPLICA (em português, denso, com o `arquivo:linha` do core), e os **asserts
   `HBTEST`** que provam cada afirmação do comentário.
2. **`tests/ppcorpus.sh`** — a guarda: compila, **RODA** (nenhuma linha de falha do
   hbtest) e confere os oráculos (`.ppo`/`.ppt`/dump) para o que **não é observável em
   runtime** (posições, mkinds, derivação — aí o dump é o único juiz).
3. **`docs/pp-corpus/<fam>.md`** — **curto**: o que a família ensina em 5 linhas, o
   ponteiro para o `.prg`, e a seção **Lacunas** (que é decisão, não conhecimento).

**REVISÃO PENDENTE (ordem do Diego):** as famílias JÁ ENTREGUES nasceram no método
antigo (markdown gordo, prova por `grep` no `.ppo`). Elas serão **revisitadas** para
migrar o conhecimento ao `.prg` com asserts. Enquanto isso não acontece, **o `.md` de
uma família antiga vale menos que o `.prg` dela**.

## ⚠️ ORGANIZAÇÃO — instrução permanente (para o Claude do futuro)

**UM ARQUIVO POR FAMÍLIA** (`docs/pp-corpus/<familia>.md`), auto-contido — e agora
**ENXUTO** (ver a virada acima). Este README é só o ÍNDICE. **NUNCA concentrar tudo
num arquivo só** — o corpus cresce sem limite e um arquivo gigante estoura o contexto.
Fluxo de consumo futuro: leia este índice (pequeno) → ache a família pelo FATO que
precisa (coluna "ensina") → carregue o **`.prg`** dela (e o `.md` só se precisar da
decisão/lacuna). Ao adicionar família: crie o `.prg` **com asserts**, some um
`corpus_<fam>` em `tests/ppcorpus.sh`, e só então um `.md` curto + a linha na tabela.

## ⚠️ SER CRÍTICO — caçar o que NÃO vem (instrução permanente, ordem do Diego)

O corpus não é só descritivo. Em cada família, pergunte: *o que os quatro
oráculos NÃO mostram que um refatorador iria querer?* Toda família tem uma seção
**Lacunas** com essa análise, e cada item é classificado por FATO em UMA de duas:

1. **Consumo futuro** — o fato JÁ existe no dump/oráculos (derivável), só falta a
   ferramenta consumi-lo. NÃO pede mudança de core; vira item das fatias P3-P8.
2. **LACUNA real** — a informação NÃO está nos oráculos (nem derivável). Ao
   detectá-la: **PROVE, MARQUE e SIGA** *(regra nova do Diego, 2026-07-13 —
   substitui a anterior, que mandava PAUSAR a exploração e fazer o experimento de
   core na hora)*:
   **(a) PROVE** — repro executável, mínimo, colado (nada de "acho que"; a
   classificação é afirmação de fato e vale a régua do parágrafo abaixo);
   **(b) MARQUE** — vira **fase no `docs/roadmap.md`**, com o repro, a
   classificação (core × consumo) e **critério de pronto mecânico**;
   **(c) SIGA explorando** — o conserto é **fatia própria, sob autorização do
   Diego**, na ordem que ele decidir.

   **Por que a regra mudou** *(e a antiga não era boba — nasceu quando lacuna era
   rara, e foi ela que pariu o rename-DATA)*: a exploração dos **usos reais** produz
   lacuna mais rápido do que se conserta, e parar a cada uma **mata a exploração** —
   perde-se o mapa, que é o produto desta fase. Pior: consertar no calor do achado é
   exatamente como eu pulo o portão (implementar antes de pedir). **A ordem de
   conserto é decisão do Diego, e só se decide com o mapa na mão.**

   **Nada se perde: o que segura é a MARCA, não a pausa.** Lacuna marcada sem repro
   e sem critério de pronto é lacuna esquecida — aí sim o pecado. E **achado que a
   ferramenta usa para QUEBRAR código do usuário sobe na hora** (relato imediato ao
   Diego, ainda que a exploração continue): urgência de aviso ≠ urgência de conserto.

**A classificação em si tem de ser PROVADA, não afirmada** (lição de 2026-07-12, o
Diego pegou): dizer "[Consumo futuro] — é derivável do `ppApplications`" SEM rodar
o dump e mostrar a evidência é raciocínio, não fato — o mesmo pecado que a REGRA DO
FATO proíbe no motor. Todo item de Lacuna traz o rótulo **VERIFICADO** e a
evidência colada (o trecho do dump que prova que o dado está — ou não está — lá).
Sem evidência, o item é uma hipótese, não uma classificação.

Distinguir 1 de 2 é uma decisão de FATO (o dado é derivável dos oráculos, sim ou
não?), não de conveniência — não rotular consumo-futuro como "sem lacuna" para
evitar o experimento, nem inventar lacuna onde o dado é derivável. Uma lacuna de
CAPACIDADE da ferramenta (info existe, verbo não) é decisão de produto do Diego,
não experimento de core (foi o caso do rename-DATA: info presente, verbo ausente →
portão → capacidade). Anotar tudo NO CORPUS/roadmap, nunca na memória.

## A tese (o achado que motiva o corpus)

**Grande parte do que parece "a linguagem Harbour" é COMANDO criado por DIRETIVA
de preprocessador.** `SET EXACT ON`, `@ 1,1 SAY x GET y`, `STORE … TO`, o dialeto
OO inteiro (`CLASS`/`METHOD`/`VAR`) são regras `#command`/`#xcommand` nas `.ch`,
não gramática do compilador. Entender o pp = entender o que a maioria do código
Harbour É — a mesma camada universal (o FATO de derivação) em que o hbrefactor age.

### Vocabulário (do core — `doc/pp_prg.txt`)

**diretiva de pp** = a regra `#command`/`#xcommand`/`#translate`/`#define` (o core
chama de *rule*); **comando** = o que o programador escreve (`SET EXACT ON`);
**marker** `<x>` = o coringa; **match** = o que casa; **result** = o que emite.

Como ler o `.ppt`: pares `arquivo(linha) >entrada<` / `#tipo >saída<`; aplicações
em cascata (uma regra sobre o resultado de outra) aparecem em sequência — é o
multi-passe visível. O `(concatenate)` é a colagem (paste) anotada por linha.

## ⚠️ ANTES DE RETOMAR: cole o [METODO.md](METODO.md)

**O processo do estudo, em 10 passos, com um exemplo REAL em cada um** — é prompt,
para colar inteiro. Ele existe porque o método não sobrevive à sessão: sem ele eu
reconstruo tudo por leitura, executo plano com premissa velha e derivo para caça a
bug. Depois dele, o [ROADMAP.md](ROADMAP.md):

Estado da exploração, plano das fatias **e o CHECKLIST ANTI-ERRO** (sete regras,
cada uma nascida de um erro real). A exploração do pp é longa — o roadmap existe
para não me perder e para não repetir erro.

## Famílias

| Família | origem | Ensina (o FATO principal) | Arquivo |
|---|---|---|---|
| SET EXACT | std.ch:121 | marker `restrict` + result `strsmart` (smart-quote); multi-passe com `#define` | [set-exact.md](set-exact.md) |
| `@ … SAY` | std.ch:249 | grupos OPCIONAIS (`opt-open`/`opt-close`) + seleção de forma | [say.md](say.md) |
| STORE | std.ch:78 | grupo opcional que REPETE (multi-atribuição) | [store.md](store.md) |
| hbclass | hbclass.ch:235+ | o dialeto OO É pp: paste do nome, diretiva que gera diretiva, `AS CLASS Self` | [class.md](class.md) |
| **MARKERS** | hbpp.h / ppcore.c | **os 15 tipos de `<x>`** (6 match + 9 result): sintaxe, o que cada um faz, veredito de consumo/recusa | [markers.md](markers.md) |
| **`<@>`** | hbfoxpro.ch:63 | **o guarda anti-recursão**: como uma regra emite a própria palavra que casa sem loop infinito | [reference-guard.md](reference-guard.md) |
| **regra que gera regra** | gen.ch / hbclass.ch | genealogia (`ast-13`) + os LIMITES do pp: `#xtranslate` gerado **não registra**; keyword colada não casa | [generated-rules.md](generated-rules.md) |
| **DERIVAÇÃO** | ast-3/12/13 | **`clone` × `paste` × `stringify`**: o que a diretiva FAZ com o nome (atravessa × vira código). A distinção que explicou 3 bugs diferentes | [derivation.md](derivation.md) |
| **ESTRUTURA da regra** | fixp6 | regra **sem cabeça**; grupos opcionais **fora de ordem**; **multi-passe** (regra que expande em regra) e o limite da palavra emitida | [rule-structure.md](rule-structure.md) |
| **ABREVIAÇÃO dBase** | ppcore.c:2725 | `#command` casa a keyword **pela metade** (>= 4 letras) — e por que só o pp sabe qual palavra é qual (`ast-15`/`ruletok`) | [abbreviation.md](abbreviation.md) |
| **PP como INSTRUMENTO** | hbpptest.prg | os **canais do core** (`.ppo`/`.ppt`/`-u`/`-gd`/`-x`/`__pp_process`): o que cada um dá e o que **destrói** | [pp-as-instrument.md](pp-as-instrument.md) |
| **PP como ENGENHO DE BUSCA** | *(plano — P12)* | casar para **ACHAR**, não para transformar: busca estrutural, lint e codemod na linguagem que o usuário já sabe | [pp-as-search.md](pp-as-search.md) |
| **ESCOPO DE DIRETIVA** | ppcore.c:6394 | `#uncommand`/`#xuntranslate`: a regra tem **tempo de vida**. Um BUG e uma LACUNA (`ast-16`) já provados | [directive-scope.md](directive-scope.md) |
| **STRDUMP** | std.ch:255 | o **`#<x>`**: o NOME escrito vira string que o programa USA em runtime (`ReadVar`, memvar). Derrubou um veredito do corpus; BUG aberto | [strdump.md](strdump.md) |
| **USO REAL (os espécimes)** | `rddtst.prg`, `gtwvg/class.prg`, `clsscope.prg` | como o Harbour **de fato escreve** com pp — por ARQUIVO e LINHA, não por porcentagem: a DSL de teste do RDD (duas regras rivais sob `#ifdef`), o módulo que gera 285 regras ao compilar, o `.prg` que redefine o `?` da linguagem. Sonda que escolhe o espécime: `tools/pp-uses.sh` | [uses-core.md](uses-core.md) |
| **CICLO DO PP** | ppcore.c:6587 | o pp **esgota o comando** (define → translate → command, voltando ao início a cada substituição) e só então avança de linha. Teto de 4096 passes, configurável por `#pragma RECURSELEVEL`; estourado, é E0022 | [pass-cycle.md](pass-cycle.md) |
| **OS 4 ESTRINGIFICADORES** | tests/pp.prg (do core) | `<z>` × `<"z">` × `<(z)>` × `#<z>`: só diferem diante de **string** e de **MACRO** (o pp **desfaz o `&` e emite CÓDIGO**); e a string com `&nome` é **macro VIVO em runtime**. **O corpus é o [`.prg`](../../tests/ppc-strfam/sf.prg)** — 20 asserts | [stringify-family.md](stringify-family.md) |
| **DEFINE DINÂMICO** | ppcore.c:7253 | `__FILE__`/`__LINE__`, o mkind **`dynval`**: o valor depende de ONDE o código está. Mover código MUDA o programa — e está certo | [dynval.md](dynval.md) |
| **TEXT/ENDTEXT** | std.ch:221 | a maquinaria de **STREAM**: o fonte vira DADO. A fronteira entre editar e **relatar** — e a lacuna que virou `ast-17` | [text-stream.md](text-stream.md) |

**A lista de famílias acabou; a exploração NÃO** *(Diego, 2026-07-13)*. As três que
restavam foram fechadas (`strdump`, `TEXT/ENDTEXT`, `dynval`) e o `hbct` **saiu da
lista** (medido: não tem UMA diretiva de comando — é biblioteca de funções). Mas o
que se estudou até aqui foram as **diretivas** (a definição, nas `.ch`). Falta o
outro lado, e é onde o conhecimento real está: **os casos de USO reais no próprio
fonte do Harbour** — como o core *escreve* código com o pp, no dia a dia dele.
Próximas famílias saem **da medição dos sítios de uso**, não de uma lista minha.
