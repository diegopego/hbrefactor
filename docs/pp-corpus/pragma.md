<!-- guarda: corpus_pragma -->
# Família `#pragma` — o compilador muda no meio do arquivo

Índice: [README.md](README.md). Ensina: o `#pragma` **não** é substituição de texto —
ele muda o **estado do compilador** a partir da linha em que aparece, e o **mesmo
texto-fonte** passa a gerar pcode **diferente**. Guarda: `corpus_pragma` em
`tests/ppcorpus.sh`; fixture `tests/ppc-pragma/pg.prg`. Origem:
`harbour/tests/pragma.prg` (o teste que os autores do pp escreveram para a superfície
`#pragma`, indicado pelo Diego).

## O sujeito certo — os oráculos DISCORDAM

O pp **substitui texto**; quem muda de comportamento é o **compilador**. Cada oráculo vê
uma face:

- **`.ppo`** (o texto que o compilador recebe): os dois `IF .F. .AND. Efeito( ... )`
  chegam **idênticos**, letra por letra, módulo o nome do local. O pragma **não deixa
  rastro no texto** — o pp não o "aplica", só o anota.
- **`.ppt`** (o traço): é o **único** oráculo que enxerga o pragma — uma linha de trace
  por sítio (`#pragma Shortcut set to 'On'` / `'Off'`).
- **runtime**: o mesmo texto, comportamento **oposto** — e só o assert, executado, revela
  qual.

## O nome MENTE

`#pragma Shortcut=On` **não** liga o curto-circuito: ele liga o switch `/Z`, e `/Z` quer
dizer "**sem** shortcut". Cadeia no fonte do core:
[`src/pp/ppcore.c:3779`](../../../harbour-core/harbour/src/pp/ppcore.c) (`SHORTCUT` vira o
switch `"z"`) → [`src/compiler/ppcomp.c:211`](../../../harbour-core/harbour/src/compiler/ppcomp.c)
(`z+` faz `supported &= ~HB_COMPFLAG_SHORTCUTS`). Logo `Shortcut=On` ⟹ `.AND.` avalia os
dois lados; `Shortcut=Off` ⟹ para no primeiro `.F.` (o normal). A fixture prova, rodando:
com `On`, `.F. .AND. Efeito()` **chama** `Efeito()` (`=1`); com `Off`, não (`=0`).

## Lacunas

- **P19** *(docs/roadmap.md)* — o dump **não exporta pragma nenhum** (`grep pragma
  pg.ast.json` = 0; os hits de `Shortcut` são só nomes de local). A ferramenta não sabe que
  uma região do arquivo compila com outra semântica: mover código entre regiões (o
  `extract-function` joga a função nova no **fim** do arquivo) pode mudar o pcode do código
  movido, **em silêncio**. É decisão de produto, não conhecimento — a resposta é o fato que
  permite **recusar com motivo**, não editar.
