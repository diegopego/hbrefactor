# Família STRDUMP — o `#<x>`, e o nome que vira STRING VIVA

Índice: [README.md](README.md). Ensina: **o `#<x>` estringifica o que você
escreveu** — e quando o que você escreveu é uma VARIÁVEL, o nome dela vira uma
string que o programa **usa em tempo de execução**. É o mkind que o corpus dava
como inexistente. Guarda: `corpus_strdump`; fixture `tests/ppc-strdump/`
(DSL inventada, não-espelho) + a diretiva REAL do core.

## O veredito que estava ERRADO (2026-07-13)

Até esta família, quatro documentos e três comentários de teste afirmavam:

> `%s` | `strdump` | **não existe em regra** — só na maquinaria de stream
> (`#pragma __text`, o `TEXT…ENDTEXT`)

**As duas metades são falsas**, e a medição derrubou as duas:

1. **A sintaxe não é (só) `%s`** — é o **`#<x>`**. O parser do core decide em
   `ppcore.c:4262`: `type = fDump ? HB_PP_RMARKER_STRDUMP : HB_PP_RMARKER_REGULAR`,
   onde `fDump` é o prefixo `#`. (O `%s` é o *outro* caminho para o mesmo mkind,
   `ppcore.c:3215`, esse sim da maquinaria de stream. Uma coisa não exclui a outra.)
2. **Ele existe em regra, e no header mais fundamental da linguagem.** Rodando o
   dump sobre os 33 headers do ecossistema que declaram diretiva (4.582 regras
   distintas, deduplicadas por arquivo+linha — sem isso o `std.ch`, auto-incluído,
   se conta em todo dump): **31 regras** emitem `strdump`, em 42 markers. Entre
   elas, **6 do próprio `std.ch`** — que não precisa de `#include` nenhum:

   | diretiva | arquivo:linha |
   |---|---|
   | `MENU TO <v>` | `std.ch:255` |
   | `SET COLOR TO [<*c*>]` | `std.ch:168` |
   | `RELEASE ALL LIKE <p>` / `ALL EXCEPT <p>` | `std.ch:268-269` |
   | `RUN <*cmd*>` | `std.ch:296` |
   | `JOIN … FOR <for>` | `std.ch:456` |
   | `ASSOCIATE CLASS <c> WITH TYPE <type>` | `hbclass.ch:576` |
   | `HBTEST <x> IS <result>` | `hbtest.ch:50` |
   | `MENU TO <v> [<l:COLD>]` | `hbnf/ftmenuto.ch:67` |

   O repositório já sabia e ninguém leu: `tests/fixb4g/forja.ch:25` diz, desde a
   B4g, *"wild no match + strdump `#` no result"*, e os dumps da suíte já traziam
   `"mkind": "strdump"` vindo do `hbclass.ch:576`.

**Como o erro passou:** o veredito foi escrito por RACIOCÍNIO (o `%s` do stream é
mesmo stream) e nunca foi medido contra o corpus real. É o pecado que o
[README.md](README.md) proíbe em letras maiúsculas — *a classificação em si tem de
ser PROVADA* — cometido no documento que a proíbe. **Só a medição pega isso.**

## A fixture (`tests/ppc-strdump/`) — compila limpo sob `-w3 -es2`

```harbour
#xcommand SELO <v> AFERIDO => <v> := sd_Afere( #<v> )   // regular + strdump
#xcommand LAVRA <*txt*>    => sd_Lavra( #<txt> )        // wild -> strdump, só
```

## O `.ppo` — o que foi ESCRITO vira string

```
SELO nLastro AFERIDO   ->  nLastro := sd_Afere( "nLastro" )
LAVRA fundo de reserva ->  sd_Lavra( "fundo de reserva" )
LAVRA nLastro          ->  sd_Lavra( "nLastro" )          <-- COLISÃO (ver abaixo)
```

No `SELO`, o `nLastro` aparece **duas vezes** na expansão: uma como a variável de
verdade (o `<v>` regular) e outra como a **string do nome dela**. Uma escrita, dois
artefatos, naturezas diferentes.

## A COLISÃO — e o fato que a resolve (o coração da família)

`SELO nLastro` e `LAVRA nLastro` são a **mesma palavra** no mesmo programa, e no
dump chegam com o **mesmo fato de aplicação**: `marker: 1`, `generates: true`.
Mas são opostos: no `SELO` a palavra **é** o `LOCAL`; no `LAVRA` ela é **texto que
só PARECE** o nome — nunca vira símbolo, nunca chega ao compilador. Um refatorador
que editasse "todo `nLastro` que o pp gerou" corromperia a string do `LAVRA`, que é
**dado**, por pura coincidência de nome.

**O `generates` NÃO separa os dois.** Quem separa é a **op da derivação**
(`tokens[].from[].op`), e ela está no dump:

```jsonc
// SELO: o MESMO byte de fonte carrega as DUAS derivações
{ "line": 25, "col": 8, "text": "nLastro", "from": [ { "marker": 1, "op": "clone"     } ] },
{ "line": 25, "col": 8, "text": "nLastro", "from": [ { "marker": 1, "op": "stringify" } ] },

// LAVRA: stringify e MAIS NADA -> a palavra não é símbolo nenhum
{ "line": 34, "col": 9, "text": "nLastro", "from": [ { "marker": 1, "op": "stringify" } ] }
```

**`clone` = chegou ao compilador** (é símbolo). **Só `stringify` = virou dado.**
Verificado: o `rename` do `LOCAL nLastro` edita a declaração, o sítio do `SELO` e a
leitura — e **não toca a linha do `LAVRA`**. A ferramenta já usa este fato; a fixture
agora o **prova** (antes ela só o afirmava, com uma DSL cujo conteúdo eu escolhera
para não colidir — o que é uma leitura minha disfarçada de teste).

O core sempre soube: `ppcore.c:5414` registra o `'s'` (stringify) no ramo do
STRDUMP, e é ele que acende o `generates` do ast-12. **O canal de fato estava
completo o tempo todo — quem estava errado era a doc.**

## Explicação

**Para o programador Harbour.** `#<v>` não passa o *valor* da variável: passa o
**nome que você digitou**, como texto. Em `MENU TO nEscolha` o Harbour te devolve
`__MenuTo( {|…| … }, "nEscolha" )` — e o `"nEscolha"` ali **não é decoração**. Veja
o que o core faz com ele (`src/rtl/menuto.prg`):

- `__mvExist( cVariable )` / `__mvPublic( cVariable )` — se não houver variável com
  aquele nome, ele **cria uma PUBLIC chamada assim**;
- `ReadVar( hb_asciiUpper( cVariable ) )` — é esse nome que um bloco de `SET KEY`
  ou uma validação lê quando pergunta *"em qual variável eu estou?"*;
- `__mvXRelease( cVariable )` no fim.

Ou seja: **o nome da sua variável é dado do programa**, e não só rótulo do
compilador. É o que torna esta família diferente de todas as outras do corpus.

## Lente de refatoração — e o LIMITE que ela revela

Renomear `nEscolha` num `MENU TO nEscolha` **muda o comportamento do programa**:
a string derivada muda junto, e o programa pode observá-la (`ReadVar()`, o nome do
memvar criado). Não existe rename byte-a-byte-preservador aqui — e a ferramenta
**está certa em não fingir que existe**. O que ela tem hoje:

- ela **prevê** a derivação (`predicted string: "nEscolha" -> "nOpcao"`) — o fato do
  ast-12 chega ao usuário;
- e o verificador **recusa e reverte**, porque o pcode muda. Fonte byte a byte
  intacto, nenhuma árvore quebrada.

**O que está ERRADO hoje** está registrado como bug abaixo — não é a recusa, é
*como* se chega nela.

## Lacunas (o que os oráculos NÃO mostram)

> Classificação por FATO (VERIFICADO rodando). Regra em [README.md](README.md).

- **[BUG — VERIFICADO, a resolver] O rename a partir do SÍTIO da diretiva atribui o
  nome ao MARKER e perde o LOCAL do programador.** Em Harbour puro (zero include):

  ```
  $ hbrefactor usages menu.prg --at menu.prg:6:12
  menu.prg:6:12: nEscolha - marker name (no identifiable owner)
  1 result(s) for 'nEscolha'          <-- a declaração (linha 2) e a leitura (linha 8) SUMIRAM
  ```

  O `nEscolha` é um `LOCAL` declarado pelo programador (o dump o traz em
  `declarations[]`), e a ferramenta o chama de *"marker name (no identifiable
  owner)"*. O `rename` então edita **só** o sítio da DSL, o verificador vê a
  contagem de símbolos mudar e reverte. **Recusa falsa, e por resolução errada.**

  Causa: [src/hbrefactor.prg:2106](../../src/hbrefactor.prg#L2106) — `generates`
  *"vence QUALQUER binding homônimo"*. A regra foi escrita para o local que a
  **própria expansão fabrica** (`REGISTRO <n> => LOCAL <n>`), e ali está certa; ela
  só não distingue esse caso do local que a diretiva apenas **referencia**. É um
  *"se não é X, então é Y"* sem fato que separe X de Y (CLAUDE.md §1.2, gatilho 3).

  **O fato que separa JÁ ESTÁ NO DUMP** — e são DOIS eixos, os dois verificados:

  | eixo | fato | exemplo | dono |
  |---|---|---|---|
  | o recheio vira símbolo? | `from[].op` tem **`clone`** | `SELO nLastro` | é símbolo → siga |
  | …ou é só dado? | **só `stringify`** | `LAVRA nLastro` | ninguém: **não editar** |
  | quem declarou o símbolo? | `declarations[].nameLine`/`nameCol` **coincide** com o recheio | `REGISTRO <n> => LOCAL <n>` | o **marker** (fabricado) |
  | | **não coincide** | `LOCAL nEscolha` + `MENU TO nEscolha` | o **LOCAL** ← *o bug: hoje diz marker* |

  Identidade posicional contra `ppApplications[].tokens[]` e ops de derivação — zero
  comparação de texto. O eixo do `clone` a ferramenta **já respeita** (o rename do local
  não toca o `LAVRA`); o que falta é o segundo. Logo: **lacuna de CONSUMO, não de core.**

- **[Decisão de PRODUTO — do Diego] Provado o dono, o rename ainda muda o pcode.**
  Resolvido o bug acima, o rename edita as 3 posições e o `.hrb` **muda mesmo** (a
  string derivada é outra) — o verificador reverte, corretamente. A pergunta é de
  produto, não de fato: um rename cuja mudança de comportamento é **prevista, exibida
  e derivada** é recusa honesta ou opt-in explícito? (O CLAUDE.md §1 é duro aqui: o
  não-verificável recebe *"detecção e relato preciso, jamais edição automática — nem
  com opt-in"*. Mas isto **não é** não-verificável: a derivação é FATO do ast-12, e o
  que muda é exatamente o que a ferramenta previu.) **Não decidido — não implementar
  antes da ordem.**
