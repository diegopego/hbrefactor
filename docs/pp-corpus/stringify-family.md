<!-- guarda: corpus_strfam -->
# Família OS QUATRO ESTRINGIFICADORES — e o MACRO

> **O conhecimento desta família mora em [`tests/ppc-strfam/sf.prg`](../../tests/ppc-strfam/sf.prg)**
> — que **compila, RODA e se afirma** (20 asserts do `hbtest`, guarda `corpus_strfam`).
> Este `.md` é só o índice e a decisão. *(Virada de método, Diego, 2026-07-14: markdown
> apodrece; o `.prg` berra.)*

**Origem:** `harbour/tests/pp.prg` — o teste que os autores do pp escreveram para o pp.

**O que ensina, em cinco linhas:**

1. `<z>`, `<"z">`, `<(z)>` e `#<z>` concordam sobre **palavra nua**; só divergem diante de
   uma **string** e de um **MACRO**.
2. Sobre **macro puro**, o `strstd`/`strsmart` **não estringificam**: o pp **desfaz o `&`**
   e emite o **símbolo, como código** (`ppcore.c:5254-5256`; derivação `clone`). Logo o
   nome dentro do macro **é símbolo de verdade** — e **não é "a parede do macro"**: não há
   macro em runtime, o pp o desfez ao compilar.
3. O `#<z>` (o core o chama de **DUMB**) preserva o literal `"&x"` **na expansão**…
4. …**mas esse literal é MACRO VIVO em runtime** — uma string que contém `&nome` é
   reavaliada a cada execução e vale o **valor do memvar**. *(As duas coisas são verdade,
   em camadas diferentes. Foi o assert que me desmentiu — o `.ppo` sozinho mentia.)*
5. **Consequência para o produto:** renomear um memvar muda o comportamento de **qualquer
   string** que mencione `&nome`. String é DADO — não se edita (§1) — mas **tem de ser
   relatada**. É o que o `usages` já faz (*"possible reference in string"*), e agora se sabe
   por quê.

## Lacunas

> Regra: PROVE, MARQUE e SIGA ([README.md](README.md)).

- **[LACUNA REAL — fase P18]** o símbolo que o pp tira de dentro do macro **chega sem
  posição** (o recheio `&cAlvo` tem linha/coluna; o símbolo emitido não, e o `at` da
  derivação aponta o `&`). Verificado: o `usages` acerta, mas o `rename` edita só a
  declaração e o verificador reverte — **recusa falsa** num rename que seria legítimo. A
  ferramenta **não pode se virar sozinha**: deduzir "pule 1 caractere" é réplica de
  gramática (§1.2/2). O core **acabou de calcular `value + 1`** e não conta.
  Prova viva: a guarda `corpus_strfam` **assere a lacuna** — quando o P18 for resolvido,
  ela quebra, e é assim que avisa.
