<!-- guarda: PENDENTE (hoje so' o contrato prova, caso 117/fixun) -->
# Família ESCOPO DE DIRETIVA — `#uncommand`/`#xuntranslate` e o tempo de vida da regra

Índice: [README.md](README.md). Fatia **P13**. **Ideia do Diego (2026-07-12)**:

> *"assim como é possível usar os comandos de pp para criar novos escopos de
> diretivas, é possível controlar coisas avançadas como injeção de diretivas em um
> bloco, e depois desativar as diretivas."*

Ensina: **uma diretiva não vale para o arquivo inteiro — ela tem TEMPO DE VIDA
LÉXICO.** Vale do `#xcommand` até o `#xuncommand`. A exploração já achou um **bug
real** e uma **lacuna do core**, ambos provados.

---

## 1. O fato: as três famílias, e a remoção (VERIFICADO no core)

`ppcore.c:6394-6444` — cada diretiva chama a **mesma** `hb_pp_directiveNew()`,
variando dois argumentos: o **modo de comparação** e um flag de **remoção**
(que desce até `hb_pp_directiveDel()`):

| criar | remover | modo | casamento |
|---|---|---|---|
| `#define` | **`#undef`** | (nome exato) | a CONSTANTE também tem tempo de vida |
| `#command` / `#translate` | `#uncommand` / `#untranslate` | `HB_PP_CMP_DBASE` | abreviado (≥ 4 letras) |
| `#xcommand` / `#xtranslate` | `#xuncommand` / `#xuntranslate` | `HB_PP_CMP_STD` | **exato** |
| `#ycommand` / `#ytranslate` | `#yuncommand` / `#yuntranslate` | `HB_PP_CMP_CASE` | exato **e case-sensitive** |

São **TRÊS** famílias de remoção, não duas — o `#undef` conta, e foi a que eu esqueci
na primeira volta (o Diego pegou).

A sintaxe do `#un*` de regra é a **mesma da diretiva** (`match => result`) — não é só o nome.
Uso real no core: `include/hblang.hbx:73` (`#uncommand DYNAMIC <fncs,...> =>
EXTERNAL <fncs>`), `contrib/xhb/hbcompat.ch:281` (`#xuntranslate NetName( =>`).

**A família `y` existe mesmo** (o Diego duvidou, com razão — eu também), e é
case-SENSITIVE. Probado com o pp vivo: regra escrita `Pinta`, o site `PINTA` **não
casa**; com `#xcommand` casaria. **Zero uso** dela em toda a árvore do core: é
curiosidade, não ferramenta.

E o `#un*` **remove de verdade** (pp vivo):

```
antes do #yuncommand:   Pinta 9  -->  ww_( 9 )
depois do #yuncommand:  Pinta 9  -->  Pinta 9      (código cru: a regra sumiu)
```

## 2. O BUG que isto expôs no hbrefactor (VERIFICADO)

O `rename` de cabeça de DSL **ignora o `#un*`**. Fixture:

```harbour
#xcommand PINTA <x> => ww_( <x> )
PROCEDURE Main()
   PINTA 1
   RETURN
#xuncommand PINTA <x> => ww_( <x> )    // a partir daqui a regra está DESLIGADA
```

`hbrefactor rename un.hbp un.prg:4:4 COLORE` → **exit 0**, com
`verified: .ppo and .hrb byte-identical`. Mas o `#xuncommand PINTA` ficou **órfão**:
ele tenta desligar uma regra que não existe mais, e a regra **VAZA**.

Prova, comparando o `.ppo` do que o programador escreveu (A) com o que o rename
deixou (B) — o uso **depois** do ponto de desligamento:

```
A (original):     PINTA 5   -->   PINTA 5      // cru: a regra estava DESLIGADA
B (pós-rename):   COLORE 5  -->   ww_( 5 )     // EXPANDIU: a regra vazou
```

O rename mudou a semântica de código que ele **nem tocou**. E a rede
`.ppo`/`.hrb` não pega, porque no fixture original nada depois do desligamento usa
a palavra — **o mesmo ponto cego** do sequestro de cabeça (ver
[abbreviation.md](abbreviation.md)).

## 3. A LACUNA DO CORE — **FECHADA: `ast-16`** (2026-07-12, caso 117)

O dump **não enxerga o `#un*`**. Compilando a fixture acima com `-x`, o `ppRules`
traz **uma só** regra:

```jsonc
"ppRules": [
  { "id": 0, "kind": "xcommand", "head": "PINTA", "file": "un.prg", "line": 1 }
]
// o #xuncommand da linha 7: AUSENTE. Nenhuma entrada, nenhuma chave.
```

Chaves disponíveis numa regra hoje: `file · head · id · kind · line · markers ·
match · result`. **Nada sobre remoção, nada sobre tempo de vida.**

**O pp SABE** — ele executou a remoção (o `.ppo` do § 2 prova). O dump **descarta**.
É a **mesma omissão do `ast-14` e do `ast-15`**, pela terceira vez: *fato que o core
sabe e não exporta é lacuna DO CORE.* → **`ast-16`**.

> ⚠️ **O que NÃO fazer** (o anti-padrão do CLAUDE.md): procurar `#xuncommand` por
> TEXTO no fonte. Seria réplica de gramática — e cega para as 6 grafias
> (`#un`/`#xun`/`#yun` × `command`/`translate`), para a abreviação (`#UNCOMM` casa!)
> e para o `.ch` incluído.

### O que o `ast-16` passou a exportar

Compilando a fixture do § 2 com `-x`, agora (**VERIFICADO**):

```
id=0 kind=xcommand     head=PINTA        line=1  removed=True
id=1 kind=ycommand     head=Seca         line=2               ← era "command"!
id=2 kind=xuncommand   head=PINTA        line=9  undoes=0     ← vínculo por ID
id=3 kind=xuncommand   head=NUNCAEXISTIU line=10 undoes=None  ← ÓRFÃO
```

Quatro fatos, e o `id=1` é um **bug de schema pré-existente** que caiu junto: o modo
de comparação era guardado num **booleano** (`é x?`), então a família `y`
(case-sensitive, exata) saía rotulada `"command"` — o dump **afirmava que uma regra
exata casa abreviado**. Agora o `kind` carrega a família como o pp a vê.

O `undoes: null` do `id=3` é o **`#un...` órfão**: ele não remove regra nenhuma. É
código morto silencioso — e é exatamente o que o rename desatento **produzia**.

### O conserto do bug do § 2: **zero linha de lógica nova**

Este é o argumento mais forte que a fase P produziu a favor da REGRA DO FATO. Com a
remoção virando **uma regra como outra qualquer** em `ppRules` — com `head` e com
`match[]` **posicionado** —, a maquinaria que a ferramenta já tinha ("renomeie por
posição toda regra cuja cabeça é a palavra velha") passou a editar o `#xuncommand`
**sozinha**:

```
$ hbrefactor rename un.hbp un.prg:4:4 CIFRA
rename-dsl: LACRA -> CIFRA
  un.prg:4:4
  un.ch:6:11
  un.prg:8:13          ← o #xuncommand, acompanhando
verified: 1 application site(s) + 2 directive occurrence(s); .ppo and .hrb byte-identical
```

E o desligamento **sobrevive**: um uso depois do `#xuncommand` renomeado continua
saindo **cru** do pp. *O fato era o problema inteiro.*

## 4. Usos que o escopo de diretiva PROMOVE — **EXPLORAR (P13, ordem do Diego)**

> Pedido do Diego (2026-07-12), textual: *"dar uma atenção especial a explorar casos
> de uso que os **`#undefine`**, **`#xuntranslate`**, **`#xuncommand`** podem
> promover. (…) assim como é possível usar os comandos de pp para criar novos
> escopos de diretivas, é possível controlar coisas avançadas como **injeção de
> diretivas em um bloco, e depois desativar as diretivas**."*
>
> **Isto é EXPLORAÇÃO A FAZER, não trabalho feito.** O `ast-16` só entregou o
> *fato* (o dump vê a remoção); o que estes verbos **habilitam** ainda não foi
> sondado. As três famílias de remoção — **`#undef`** (de `#define`),
> **`#un[x|y]command`** e **`#un[x|y]translate`** — contam igual.

1. **É o mecanismo que faltava para o P12** ([pp-as-search.md](pp-as-search.md)):
   injetar a regra de **consulta**, deixá-la casar, e **removê-la** — a consulta não
   vaza para o build. Melhor e mais direto que a regra no-op com `<@>` que eu tinha
   hipotetizado.
2. **Codemod com escopo**: ligar a regra de migração para um bloco/região e
   desligá-la depois — migrar por região, não pelo módulo inteiro.
3. **Refatoração nova**: *"estreitar o escopo desta diretiva"* — hoje impossível de
   fazer com segurança, porque a ferramenta não vê o escopo.
4. **Diagnóstico**: `#un*` órfão (que não desliga regra nenhuma) é **código morto
   silencioso** — e o exemplo do § 2 mostra que ele nasce de um rename.
5. **`#undef` como escopo de CONSTANTE** (a família que eu tinha esquecido): um
   `#define` que vale só num trecho é um idioma real de higiene — e o `#undef` de um
   define que ninguém definiu é igualmente órfão. O mesmo vazamento vale aqui, e o
   `ast-16` agora o cobre.
6. **A pergunta em aberto**: dá para injetar diretiva num **bloco arbitrário** de
   código (não só "do ponto X ao ponto Y do arquivo")? O pp é linha-a-linha, então
   *escopo* aqui é **posicional**, não sintático. Sondar o limite honesto disso é
   parte da fatia.

---

## Lacunas (VERIFICADO)

- **[FECHADA — `ast-16`, caso 117]** O dump exporta a remoção (`kind` de `un...`), o
  vínculo `undoes` (por **id**), o `removed` da regra que morreu, e a família real
  (`x`/`y`/dBase). O vazamento de escopo do `rename` está consertado. `lexdiff` 0.
- **[Consumo futuro]** O **`#un...` órfão** (`undoes: null`) é fato disponível e
  **ainda sem consumidor**: dá um diagnóstico honesto de código morto (*"esta
  diretiva não desliga nada"*). Cabe no P12 (o pp como inspeção).
- **[A explorar — P13]** O escopo como **mecanismo** (injetar regra, casar, remover)
  para o P12 e para codemod por região: **não sondado ainda**.
- **[Fato, não lacuna]** A família `y` (`#ycommand`/`#ytranslate`, case-sensitive)
  **não tem UM uso** em toda a árvore do core. Existe, agora o dump a reporta
  corretamente, e provavelmente ninguém a usará.
