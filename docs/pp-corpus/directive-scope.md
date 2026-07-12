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
| `#command` / `#translate` | `#uncommand` / `#untranslate` | `HB_PP_CMP_DBASE` | abreviado (≥ 4 letras) |
| `#xcommand` / `#xtranslate` | `#xuncommand` / `#xuntranslate` | `HB_PP_CMP_STD` | **exato** |
| `#ycommand` / `#ytranslate` | `#yuncommand` / `#yuntranslate` | `HB_PP_CMP_CASE` | exato **e case-sensitive** |

A sintaxe do `#un*` é a **mesma da diretiva** (`match => result`) — não é só o nome.
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

## 3. A LACUNA DO CORE (VERIFICADO — é `ast-16`)

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

## 4. Usos que o escopo de diretiva PROMOVE [A PROVAR — P13]

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

---

## Lacunas (VERIFICADO)

- **[LACUNA real — `ast-16`, em aberto]** O dump não exporta o `#un*`: nem a
  diretiva de remoção, nem o tempo de vida da regra. Enquanto isso, **o `rename` de
  cabeça de DSL corrompe o escopo em silêncio** (§ 2). Pausa a exploração e vira
  experimento de core — é a regra do Diego ("lacuna pausa e experimenta").
