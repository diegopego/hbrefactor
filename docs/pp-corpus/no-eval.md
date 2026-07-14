<!-- guarda: corpus_noeval -->
# Família O QUE O PP **NÃO** FAZ — ele não avalia, e não acumula estado por passada

> **O conhecimento mora em [`tests/ppc-eval/ev.prg`](../../tests/ppc-eval/ev.prg)** (6 asserts).
> Guarda: `corpus_noeval`. *(Exercício pedido pelo Diego, 2026-07-14: "LLMs costumam achar que a
> cada passada o preprocessador faz algum tipo de eval, como se pudesse acumular estado".)*

## O que ensina

**O pp substitui TEXTO.** Ele não soma, não compara, não conhece valor de variável, não executa
nada. O que ele entrega ao compilador é texto — e é o **compilador** que depois decide o que
aquilo significa.

**A armadilha que prova isso** (e que morde de verdade, em código real):

```harbour
#define N  2 + 3
? N * 2        // o compilador recebe `2 + 3 * 2`  ->  8, e não 10
? ( N ) * 2    // o compilador recebe `( 2 + 3 ) * 2`  ->  10
```

`#define N 2 + 3` **não define o número cinco**: define **três tokens**. Se o pp avaliasse,
`N * 2` seria `5 * 2 = 10`. Dá **8** — a precedência é do *compilador*, aplicada ao texto colado.

**A exceção, e ela é única:** a **condição de diretiva**. O `#if 2 + 3 == 5` **é avaliado**, pelo
calculador interno do pp (`hb_pp_calcOperation`). Então a frase correta não é *"o pp não avalia
nada"* — é: **o pp não avalia o SEU CÓDIGO; ele avalia a condição das PRÓPRIAS diretivas.**

## Vale para TODAS as diretivas

Não é privilégio do `#define`. Um `#xcommand CALC <a> <b> => s_n := <a> + <b>` recebe `2 3` e
entrega **`s_n := 2 + 3`** — três tokens, nenhuma soma. O `#xtranslate` idem. *(A diferença
entre eles é **onde casam** — comando só no começo do comando, translate em qualquer lugar —
nunca **o que fazem**: colar texto.)*

## E o "estado"? — a pergunta do Diego, respondida por assert

**Numa cadeia de transformações (`P1 → P2 → P3`), o que atravessa?**

| | |
|---|---|
| valores | **NÃO** — o pp não avalia |
| acumuladores | **NÃO** — não há onde guardar |
| **a TABELA DE REGRAS** | **SIM — e é a única coisa** |

Uma regra **pode emitir uma diretiva**, e a diretiva **muda a tabela**. Provado:
`#xcommand GRAVA <n> => #define GRAVADO <n>` — a linha `GRAVA 9` **não produz código nenhum**
(a expansão é a string vazia), mas **a partir dali** o texto `GRAVADO` passa a valer `9`.
**É o único "estado" que uma transformação grava.**

## E o estado do arquivo

**Não existe estado acumulado por passada.** O estado do pp é a **tabela de regras** — e ela muda
quando ele encontra uma **linha de diretiva**. Consequência: **a posição da diretiva é
semântica**. Antes do `#define`, o token passa **intacto**; depois dele, casa; depois de um
`#undef`, volta a passar intacto. *(O tempo de vida da regra é a família
[directive-scope.md](directive-scope.md); o laço de passes é a [pass-cycle.md](pass-cycle.md) —
ali o pp **reprocessa a linha até ninguém casar**, mas cada passe é substituição de texto, não
avaliação.)*
