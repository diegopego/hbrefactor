<!-- guarda: corpus_markers -->
# Família MARKERS — os 15 tipos de `<x>` do pp

Índice: [README.md](README.md). Ensina: **um `<x>` de diretiva não é uma coisa
só** — o pp tem 6 tipos de marker no MATCH e 9 no RESULT, cada um com sintaxe e
comportamento próprios. Guarda: `corpus_markers`; fixture `tests/fixmk/`
(DSL inventada não-espelho que exercita todos os escrivíveis).

Sintaxe tirada do PARSER do core (`hb_pp_matchMarkerNew` / `hb_pp_resultMarkerNew`,
`src/pp/ppcore.c`), não de memória. Vocabulário: `include/hbpp.h`.

## MATCH — o que a regra ACEITA (6 tipos)

| sintaxe | mkind | o que casa |
|---|---|---|
| `<x>` | `regular` | uma expressão |
| `<x,...>` | `list` | uma lista separada por vírgula (os itens chegam individualmente) |
| `<x: A, B>` | `restrict` | **só** um dos valores listados — nada mais casa |
| `<*x*>` | `wild` | qualquer coisa, até o fim do comando |
| `<(x)>` | `extexp` | expressão estendida (aceita parênteses) |
| `<!x!>` | `name` | só um identificador válido |

## RESULT — o que a regra EMITE (9 tipos)

| sintaxe | mkind | o que emite |
|---|---|---|
| `<x>` | `regular` | o valor, como veio |
| `<"x">` | `strstd` | o valor virado STRING — **menos sobre MACRO**, onde ele DESFAZ o `&` e emite CÓDIGO → [stringify-family.md](stringify-family.md) |
| `<(x)>` | `strsmart` | *smart-quote*: palavra nua vira string; **STRING** passa crua (expressão TAMBÉM vira string!); e **MACRO vira código** → [stringify-family.md](stringify-family.md) |
| `<{x}>` | `block` | o valor **embrulhado num codeblock** |
| `<.x.>` | `logical` | `.T.`/`.F.` — se o marker casou. **O VALOR não é emitido** |
| `<-x->` | `nul` | **nada** — o valor é descartado |
| `<@>` | `reference` | o guarda anti-recursão → [reference-guard.md](reference-guard.md) |
| `#<x>` | `strdump` | o **NOME ESCRITO** virado string (não o valor) — e o `%s` do stream (`#pragma __text`) é o outro caminho para o mesmo mkind → [strdump.md](strdump.md) |
| — | `dynval` | **não escrivível** — canal interno do pp para `__FILE__`/`__LINE__` (ppcore.c:5501/7253) |

## A fixture (`tests/fixmk/`) — compila limpo sob `-w3 -es2`

```harbour
#xcommand M_RST <x: LIGA, DESLIGA>  => QOut( <(x)> )         // restrict + smart
#xcommand M_WLD <*x*>               => QOut( "wild" )        // wild, DESCARTADO
#xcommand R_BLK <x>                 => QOut( Eval( <{x}> ) ) // block
#xcommand R_LOG <x>                 => QOut( <.x.> )         // logical
#xcommand R_NUL <x> <y>             => QOut( <y> <-x-> )     // nul
```

## O `.ppo` — cada um se revela na expansão

```
M_REG n                  ->  QOut( n )                  // regular: passa o valor
M_LST 1, 2, 3            ->  QOut( 1, 2, 3 )            // list
M_RST LIGA               ->  QOut( "LIGA" )             // restrict + smart-quote
M_WLD qualquer coisa aqui->  QOut( "wild" )             // wild: o valor SUMIU
M_EXT ( n )              ->  QOut( ( n ) )              // extexp
M_NAM Fulano             ->  QOut( "Fulano" )           // name + strstd
R_BLK n + 1              ->  QOut( Eval( {|| n + 1} ) ) // block: virou codeblock!
R_LOG n                  ->  QOut( .T. )                // logical: o valor SUMIU
R_NUL n 42               ->  QOut( 42 )                 // nul: o valor SUMIU
```

Três deles (`wild` não-usado, `logical`, `nul`) **consomem o que você escreve e
jogam fora** — repare que `n` some da saída.

## O pp NÃO limita quantas vezes um marker aparece no destino

O mesmo `<x>` pode ser usado **quantas vezes você quiser** no resultado — colado,
stringificado e passado adiante, tudo de uma vez:

```harbour
#xcommand SNAP <n> => FUNCTION g_<n>() ;; RETURN <"n"> ;; FUNCTION h_<n>() ;; RETURN <"n">

SNAP Preco   ->   FUNCTION g_Preco() ;; RETURN "Preco" ;; FUNCTION h_Preco() ;; RETURN "Preco"
```

Uma palavra escrita **uma vez** virou dois símbolos colados (`g_Preco`, `h_Preco`)
e duas strings. Não há teto: o `.ppt` mostra um passo `(concatenate)` por colagem.
Consequência para o refatorador: renomear o marker tem de re-derivar **todas** as
formas — e a ferramenta prevê cada uma (ver [spec-p § P2](../spec-p-pp-refatoracao.md),
onde isso foi exaurido: a segurança é ESTRUTURAL, indiferente à multiplicidade).

## O fato do dump (ast-5 + **ast-14**)

O `mkind` de cada marker vem no `match[]`/`result[]` da regra. E — canal **ast-14**
— **todo marker de match é numerado**, então o recheio dele nos tokens consumidos
vem **ligado ao marker** (`marker: N`), enquanto `marker: 0` significa **uma coisa
só**: palavra literal da própria regra.

Antes do ast-14 não era assim: um marker casado mas **não usado no result** não
recebia índice, e o pp **descartava o casamento** (`hb_pp_patternMatch` só registra
quando `pMatch->index` está setado). O recheio chegava com `marker: 0` — igual a
uma keyword da regra. O comentário do core afirmava isso e estava errado:
*"everything not covered by a marker result is a literal word of the rule itself"*.

## Explicação

**Para o programador Harbour.** Quando você escreve `<x>` numa diretiva, está
escolhendo um COMPORTAMENTO, não só um nome. `<x: A, B>` recusa qualquer coisa fora
da lista (é como um enum). `<{x}>` transforma o que você escreveu num **codeblock**
— por isso `R_BLK n + 1` vira `Eval( {|| n + 1} )`: a expressão foi congelada, não
avaliada. `<.x.>` só quer saber **se** você escreveu algo (emite `.T.`/`.F.`), e
`<-x->` engole e joga fora. Saber disso muda como você lê (e escreve) as diretivas
do seu app.

## Lente de refatoração

- **`restrict`**: a ferramenta lê as alternativas e **valida** — renomear para um
  valor fora da lista é recusado ANTES de editar (a regra deixaria de casar).
- **`wild` não-usado / `logical` / `nul`**: o que você escreveu ali **não chega ao
  compilador**. Nenhum fato o liga a um símbolo, então a ferramenta **não edita** —
  mas **relata** ("consumido e DESCARTADO pela diretiva"), para o fonte não ficar
  incoerente em silêncio.
- **`block`/`strstd`/`strsmart`/`regular`/`extexp`/`name`/`list`**: o valor É
  emitido → é símbolo ligado de verdade, renomeável pelo fato normal.
- **`strdump` (`#<x>`)**: o NOME vira string que o **programa usa em runtime** (o
  `MENU TO` do `std.ch` cria um memvar com aquele nome e o expõe em `ReadVar()`).
  Renomear MUDA o comportamento — família própria, com o limite e um BUG aberto:
  [strdump.md](strdump.md).

Provas: **caso 111** (suíte, fixture `fixmk`) + `corpus_strdump` +
[ast-schema § mkind](../ast-schema.md).

## Lacunas (o que os oráculos NÃO mostram)

> Classificação por FATO (VERIFICADO rodando). Regra em [README.md](README.md).

- **[RESOLVIDA — canal `ast-14`, 2026-07-12] O recheio de marker não-numerado era
  indistinguível de palavra da regra.** LACUNA REAL (o dado NÃO estava nos
  oráculos — o pp descartava o casamento). Primeiro tentei remendar na ferramenta
  comparando TEXTO; o Diego pegou, e o furo se provou em uma linha: `ANOTA ANOTA`
  (com `#xcommand ANOTA <*x*>`) classificava o conteúdo do usuário como palavra de
  regra. **Conserto no CORE**, onde o fato tinha de nascer: todo marker de match
  passa a ser numerado (gated por `fTrackPos`; `lexdiff` 0 — a expansão não muda).
  É a regra do CLAUDE.md em ação: *falta de informação → vá ao core*.
