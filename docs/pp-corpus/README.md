# Corpus do PP — índice

Fonte de conhecimento viva (fase P, P-DOC): o que o preprocessador do Harbour
REALMENTE faz, provado em diretivas REAIS do core/contribs. Método, formato e
critério: [../spec-pdoc-corpus-pp.md](../spec-pdoc-corpus-pp.md). Guarda
executável SEPARADA do contrato: **`make ppcorpus`** (o `make test` fica
byte-idêntico). Cada família casa a diretiva com os **QUATRO oráculos** — `.ppo`
(expandido) + `.ppt` (traço) + ast dump (mkinds/roles) + fixture COMPILÁVEL — e
explica bilíngue (técnico + programador Harbour).

## ⚠️ ORGANIZAÇÃO — instrução permanente (para o Claude do futuro)

**UM ARQUIVO POR FAMÍLIA** (`docs/pp-corpus/<familia>.md`), auto-contido. Este
README é só o ÍNDICE enxuto. **NUNCA concentrar tudo num arquivo só** — o corpus
cresce sem limite e um arquivo gigante estoura o contexto. Fluxo de consumo
futuro: leia este índice (pequeno) → ache a família pelo FATO que precisa (coluna
"ensina") → carregue SÓ aquele arquivo. Cada família ~60-140 linhas; se passar
muito, divida em sub-arquivos. Ao adicionar família: crie o `.md` próprio, some
uma linha na tabela abaixo, some um `corpus_<fam>` em `tests/ppcorpus.sh`.

## ⚠️ SER CRÍTICO — caçar o que NÃO vem (instrução permanente, ordem do Diego)

O corpus não é só descritivo. Em cada família, pergunte: *o que os quatro
oráculos NÃO mostram que um refatorador iria querer?* Toda família tem uma seção
**Lacunas** com essa análise, e cada item é classificado por FATO em UMA de duas:

1. **Consumo futuro** — o fato JÁ existe no dump/oráculos (derivável), só falta a
   ferramenta consumi-lo. NÃO pede mudança de core; vira item das fatias P3-P8.
2. **LACUNA real** — a informação NÃO está nos oráculos (nem derivável). Aqui vale
   a regra dura do Diego: **a lacuna PAUSA a exploração**. Ao detectá-la: (a) crie
   um todo imediatamente; (b) faça o EXPERIMENTO já — tente resolver ESTENDENDO o
   fonte do Harbour (`.ppt`/`.ppo`/dump mais ricos, permissão #7 do adr-004);
   (c) só siga a exploração após a tentativa. Vira `ast-N` + caso se destravar,
   ou recusa documentada se a prova mostrar que não compensa.

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

## ⚠️ ANTES DE RETOMAR: leia o [ROADMAP.md](ROADMAP.md)

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
| **ABREVIAÇÃO dBase** | ppcore.c:2533 | `#command` casa a keyword **pela metade** (>= 4 letras) — e por que só o pp sabe qual palavra é qual (`ast-15`/`ruletok`) | [abbreviation.md](abbreviation.md) |
| **PP como INSTRUMENTO** | hbpptest.prg | os **canais do core** (`.ppo`/`.ppt`/`-u`/`-gd`/`-x`/`__pp_process`): o que cada um dá e o que **destrói** | [pp-as-instrument.md](pp-as-instrument.md) |
| **PP como ENGENHO DE BUSCA** | *(plano — P12)* | casar para **ACHAR**, não para transformar: busca estrutural, lint e codemod na linguagem que o usuário já sabe | [pp-as-search.md](pp-as-search.md) |
| **ESCOPO DE DIRETIVA** | ppcore.c:6394 | `#uncommand`/`#xuntranslate`: a regra tem **tempo de vida**. Um BUG e uma LACUNA (`ast-16`) já provados | [directive-scope.md](directive-scope.md) |
| **STRDUMP** | std.ch:255 | o **`#<x>`**: o NOME escrito vira string que o programa USA em runtime (`ReadVar`, memvar). Derrubou um veredito do corpus; BUG aberto | [strdump.md](strdump.md) |

Planejadas (ver [ROADMAP.md](ROADMAP.md)): `TEXT … ENDTEXT` (a maquinaria de
*stream* — o `%s`, o **outro** caminho do `strdump`); `#define` dinâmico
(`__FILE__`/`__LINE__`, o `dynval`, o único mkind ainda com recusa documentada).
**O `hbct` saiu da lista**: medido, ele não tem UMA diretiva de comando — é
biblioteca de funções (só `#define` de constante).
