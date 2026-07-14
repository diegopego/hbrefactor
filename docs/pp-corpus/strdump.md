<!-- guarda: corpus_strdump -->
# Família STRDUMP — o `#<x>`, e o nome que vira STRING VIVA

> **O conhecimento mora nos `.prg`** — este `.md` é índice e decisão *(virada de método,
> Diego, 2026-07-14: markdown apodrece; o `.prg` berra)*:
> - **[`tests/ppc-strdump/sdrun.prg`](../../tests/ppc-strdump/sdrun.prg)** — RODA e se
>   afirma: o que a diretiva **vira** (pp vivo, `__pp_Process`) e o que ela **vale**
>   (`hbtest`).
> - **[`tests/ppc-strdump/sd.prg`](../../tests/ppc-strdump/sd.prg)** — o que só o **dump**
>   sabe: a **colisão** entre símbolo e dado, e a op de derivação que a resolve.
>
> Guarda: `corpus_strdump` (compila, **RODA** com zero falhas, e confere os oráculos).

## O que ensina

1. **`#<x>` estringifica o NOME ESCRITO, não o valor.** `SELO nLastro AFERIDO` vira
   `nLastro := sd_Afere( "nLastro" )` — a função recebe a **string do nome**.
2. **Um nome escrito UMA vez vira DOIS artefatos opostos**: a variável (derivação
   `clone` — chega ao compilador) e a string do nome dela (`stringify` — vira dado).
3. **A COLISÃO, e o fato que a resolve**: `SELO nLastro` e `LAVRA nLastro` chegam ao dump
   **idênticos** (`marker: 1`, `generates: true`) e são **opostos** — num a palavra **é** o
   local, no outro é texto que só **parece** o nome. **O `generates` não separa**; quem
   separa é a **op da derivação** (`clone` = símbolo; só `stringify` = dado). A ferramenta
   já respeita esse eixo: o rename do local **não toca** a linha do `LAVRA`.
4. **E o texto estringificado pode ser MACRO VIVO**: se contiver `&nome`, a string é
   reavaliada em runtime e vale o **valor do memvar** → [stringify-family.md](stringify-family.md).

## O veredito que estava ERRADO *(corrigido em 2026-07-13)*

O corpus afirmava, em 4 docs e 3 comentários de teste: *"`%s` | `strdump` | **não existe em
regra** — só na maquinaria de stream"*. **As duas metades eram falsas.** O `strdump` é o
**`#<x>`** (`ppcore.c:4277`, ramo `fDump`; o `%s` do stream é o *outro* caminho para o mesmo
mkind) — e **31 regras** do ecossistema o emitem, **6 no `std.ch`**: `MENU TO`,
`SET COLOR TO`, `RELEASE ALL LIKE`, `RUN`, `JOIN`; mais `hbclass.ch:576` (`ASSOCIATE`) e
`hbtest.ch:50`. O repositório já se contradizia desde a B4g (`tests/fixb4g/forja.ch:25`).
**Escrito por raciocínio, nunca medido** — é o pecado que o [README.md](README.md) proíbe,
cometido no documento que o proíbe. **Só a medição pega isso** (cicatriz ⓬).

## Por que importa ao programador Harbour

No `MENU TO nEscolha` do `std.ch`, o core recebe a string `"nEscolha"` e faz
`__mvPublic( cVariable )` (**cria um memvar com aquele nome**) e
`ReadVar( Upper( cVariable ) )` — que qualquer bloco de `SET KEY` pode ler
(`src/rtl/menuto.prg:84`). **O nome da sua variável é dado do programa**, não rótulo do
compilador.

## Lacunas

> Regra: PROVE, MARQUE e SIGA ([README.md](README.md)).

- **[BUG — VERIFICADO, fase P15]** o `rename` a partir do **sítio da diretiva** atribui o
  nome ao MARKER e **perde o LOCAL do programador** (o `usages` o chama de *"marker name (no
  identifiable owner)"*); edita só o sítio da DSL, e o verificador reverte — **recusa falsa,
  e por resolução errada**. Causa: [src/hbrefactor.prg:2106](../../src/hbrefactor.prg#L2106)
  — `generates` *"vence QUALQUER binding homônimo"*, regra escrita para o local **fabricado**
  pela expansão, que não separa esse caso do local apenas **referenciado** (§1.2, gatilho 3).
  **O fato que separa já está no dump**, em dois eixos: (i) o recheio **clona**? (senão é
  dado — e este eixo a ferramenta já respeita); (ii) a declaração do símbolo **coincide** com
  o recheio (fabricado → o marker é dono) ou **não** (do programador → o local é dono).
  **Consumo, não core.**
- **[DECISÃO DE PRODUTO — do Diego]** resolvido o bug, o rename **muda o pcode** (a string
  derivada é outra) e o verificador reverte, **corretamente** — a string é **viva em runtime**.
  Rename cuja mudança de comportamento é **derivada, prevista e exibida** (`predicted string:
  "nEscolha" -> "nOpcao"`) é **recusa honesta** ou **opt-in explícito**? O §1 manda relatar e
  nunca editar o não-verificável — mas isto **não é** não-verificável: a derivação é FATO do
  ast-12. **Não decidido — não implementar antes da ordem.**
