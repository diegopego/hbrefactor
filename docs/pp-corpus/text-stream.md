# Família TEXT/ENDTEXT — a maquinaria de STREAM, e o DADO que ninguém via

Índice: [README.md](README.md). Ensina: dentro de um bloco de stream, **o seu
código-fonte deixa de ser código e vira DADO** — cada linha crua sai como string.
É a fronteira exata onde o refatorador tem de **parar de editar e começar a
relatar**. Guarda: `corpus_text`; fixture `tests/ppc-text/`. Irmã da família
[strdump.md](strdump.md) — é o **outro** caminho para o mesmo mkind.

## A diretiva (REAL, do core)

```harbour
// include/std.ch:221
#command TEXT              => text QOut, QQOut
#command TEXT TO FILE <(f)> => __TextSave( <(f)> ) ;; text QOut, __TextRestore
```

O `text <linefunc>,<endfunc>` **não é uma função** — é uma forma que o pp entende
por compatibilidade com o Clipper (`ppcore.c:5788`), e que liga o modo de stream.
E repare no que ele monta (`ppcore.c:5806`): `QOut( %s )` — o pp **FABRICA um marker
`strdump`**. Nenhum programador escreveu `%s` em lugar nenhum.

Os modos (`include/hbpp.h:62-68`): `__text` = **linha a linha** (compatível
Cl*pper); `__stream`/`__cstream` = o bloco inteiro vira **uma** string (o `c`
processa sequências de escape); e ainda `BEGINDUMP` (C embutido) e o
`hb_inLine(){…}`.

## A fixture — e a COLISÃO que ela força

```harbour
LOCAL cSaldo := "1.234,00"

TEXT
Relatorio mensal
cSaldo apurado no periodo     // <-- a palavra e' o nome do LOCAL... mas aqui e' DADO
ENDTEXT

? cSaldo
```

## O `.ppo` — o fonte virou string

```
QOut( "   Relatorio mensal" )
QOut( "   cSaldo apurado no periodo" )
QQOut( )
```

Cada linha, **com os espaços da margem**, virou uma string. O `cSaldo` de dentro do
bloco **não é** o local: é texto. O compilador nunca vê ali uma variável.

## O `.ppt` — o oráculo que fica CEGO

```
txt.prg(5) >TEXT<
#command   >text QOut, QQOut<
```

E **só**. As linhas do bloco **não aparecem no traço** — o `.ppt` mostra a diretiva
que ligou o stream e emudece sobre o que o stream engoliu. Fica registrado como
limite do oráculo: aqui, quem conta a verdade é o `.ppo` + o dump.

## A LACUNA REAL que a família achou (e o `ast-17` que a fechou)

Uma string comum do fonte chega ao dump **posicionada**:

```jsonc
{ "line": 3, "col": 20, "type": 41, "prov": "s", "text": "1.234,00" }
```

As do bloco chegavam **assim** — e este era o fato:

```jsonc
{ "line": 0, "col": null, "type": 41, "prov": "n", "text": "   cSaldo apurado no periodo" }
```

**Sem linha, sem coluna, sem origem.** O pp tinha lido aquilo de uma linha concreta
do arquivo do usuário e **descartava** a informação. Não era regra geral sobre
strings (a de cima prova o contrário): era a maquinaria de stream jogando fora.

**Por que isso importa, se o conteúdo é dado e a ferramenta não edita dado?**
Porque **relatar também é produto**. O CLAUDE.md §1 é explícito: conteúdo sem
verificação (strings, dados, comentários) recebe *"detecção e relato preciso,
jamais edição automática"*. Sem posição, a metade do "detecção e relato" era
**impossível**: você renomeia `cSaldo`, a ferramenta edita certo, verifica certo —
e o bloco `TEXT` continua imprimindo `cSaldo apurado no periodo`, **em silêncio**,
sem que nada no mundo pudesse te avisar. O fato que faltava não protegia uma
edição; protegia um **aviso**.

**Conserto no CORE** (`hb_pp_tokenAddStreamFunc`, `ppcore.c`), gated por `fTrackPos`,
expansão intacta (`lexdiff` 0, `make test` 990/0):

```jsonc
{ "line": 7, "col": 0, "type": 41, "prov": "s", "text": "   cSaldo apurado no periodo" }
```

## Lente de refatoração

- **A ferramenta NÃO edita, e está certa**: verificado — o `rename` de `cSaldo`
  edita a declaração e a leitura, **não toca o bloco**, e verifica byte-idêntico.
  O texto do bloco não tem `clone` nenhum ligando-o a símbolo (é a mesma régua da
  família [strdump.md](strdump.md): `clone` = símbolo; só dado = dado).
- **Com o `ast-17`, ela PODE relatar** — e é isso que falta consumir (abaixo).

## Lacunas (o que os oráculos NÃO mostram)

> Classificação por FATO (VERIFICADO rodando). Regra em [README.md](README.md).

- **[LACUNA REAL — RESOLVIDA no core, `ast-17`, 2026-07-13] A linha de stream chegava
  sem posição.** Evidência colada acima (o antes e o depois). Guarda: `corpus_text`.
- **[Consumo futuro — VERIFICADO] O `usages` ainda não relata a ocorrência em DADO.**
  O fato agora existe (posição + `prov: "s"`), e nenhum verbo o usa: o `usages` de
  `cSaldo` não menciona a linha do bloco. É **consumo**, não core — e é o relato que
  o §1 do CLAUDE.md manda existir. Registrado no roadmap (fase P16); **não
  implementado** (spec antes de código, ordem do Diego).
- **[Limite honesto, não-lacuna] Os modos `__stream`/`__cstream` juntam o bloco numa
  string só** — a posição é a do terminador, não a de cada linha. Para relatar
  "linha N do bloco" nesses modos seria preciso um canal por-linha; o `TEXT` do
  Cl*pper (o que a linguagem expõe) **não** tem esse problema. Não vale core novo
  sem consumidor pedindo.
