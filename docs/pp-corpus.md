# Corpus do PP — o que o preprocessador do Harbour REALMENTE faz

Fonte de conhecimento viva (fase P, P-DOC). Cada entrada casa uma **diretiva
REAL** do Harbour com os **QUATRO oráculos** — `.ppo` (saída expandida), `.ppt`
(traço passo a passo), **ast dump** (o fato estruturado, os `mkind`) e uma
**fixture `.prg` COMPILÁVEL** (o corpus sempre se baseia em código provado) — e
explica, para o técnico E para o programador Harbour, o que o pp faz e o que o
hbrefactor refatora ali. Método, formato e critério:
[spec-pdoc-corpus-pp.md](spec-pdoc-corpus-pp.md). Os artefatos colados aqui são
FATO ancorado por uma guarda executável SEPARADA do contrato: **`make ppcorpus`**
(exploratória de propósito — o core será estendido durante a exploração; o
`make test` fica byte-idêntico). Se o core mudar a expansão, `make ppcorpus`
quebra e o doc é corrigido — nunca apodrece.

## A tese (o achado que motiva o corpus)

**Grande parte do que parece "a linguagem Harbour" é COMANDO criado por DIRETIVA
de preprocessador.** `SET EXACT ON`, `@ 1,1 SAY x GET y`, `REPLACE`, `DEFAULT …
TO`, e o dialeto OO inteiro (`CLASS`/`METHOD`/`VAR`) não são gramática do
compilador — são regras `#command`/`#xcommand`/`#translate` nas `.ch` (std.ch,
hbclass.ch, contribs). Quem escreve `SET EXACT ON` acha que usa uma palavra da
linguagem; na verdade dispara uma diretiva que expande para `Set( 1, "ON" )`.
Entender o pp é entender o que a maioria do código Harbour É — e é a mesma camada
universal (o FATO de derivação) em que o hbrefactor age.

### Vocabulário (do próprio core — `doc/pp_prg.txt`)

- **diretiva de pp** = a linha `#command`/`#xcommand`/`#translate`/`#define` que
  DEFINE (o compilador chama de *rule*, regra).
- **comando** = o que o programador ESCREVE (`SET EXACT ON`), criado por `#command`.
- **marker** `<x>` = o coringa do padrão; **match** = o que casa; **result** = o
  que emite.

Como ler o `.ppt`: cada par de linhas é `arquivo(linha) >entrada<` seguido de
`#tipo-da-regra >saída<`. Aplicações em CASCATA (uma regra sobre o resultado de
outra) aparecem em sequência — é o multi-passe visível.

---

## Família SET — `std.ch` (o comando mais universal)

Diretiva real ([include/std.ch:121](../../harbour-core/harbour/include/std.ch)):

```harbour
#command SET EXACT <x:ON,OFF,&> => Set( _SET_EXACT, <(x)> )
```

Uma linha, e dois mecanismos avançados do pp de uma vez.

### A fixture (`tests/ppc-set/setx.prg`) — compila limpo sob `-w3 -es2`

```harbour
PROCEDURE Main()
   LOCAL lFlag := .T.
   SET EXACT ON
   SET EXACT OFF
   SET EXACT (lFlag)
   RETURN
```

*(std.ch é AUTO-incluída pelo compilador — incluí-la explícito duplicaria os
`#define` e cairia em `W0002`/`-es2`.)*

### O `.ppo` (o que o compilador REALMENTE compila)

```
PROCEDURE Main()
   LOCAL lFlag := .T.
   Set( 1, "ON" )
   Set( 1, "OFF" )
   Set( 1, lFlag )
   RETURN
```

### O `.ppt` (o traço passo a passo — DOIS passes por linha)

```
setx.prg(7) >SET EXACT ON<
#command >Set( _SET_EXACT, "ON" )<
setx.prg(7) >_SET_EXACT<
#define >1<
setx.prg(8) >SET EXACT OFF<
#command >Set( _SET_EXACT, "OFF" )<
setx.prg(8) >_SET_EXACT<
#define >1<
setx.prg(9) >SET EXACT (lFlag)<
#command >Set( _SET_EXACT, lFlag )<
setx.prg(9) >_SET_EXACT<
#define >1<
```

### Os mkinds do dump (ast-5) — a ponte com P4/P5

```
match:   SET(literal)  EXACT(literal)  x(marker, mkind=restrict)
         + alternativas ON | OFF | &   (role=restrict)
result:  Set ( _SET_EXACT ,  x(marker, mkind=strsmart)  )
```

### Explicação

**Técnica.** A regra casa `SET EXACT` seguido de UM marker restrito
(`<x:ON,OFF,&>`, mkind `restrict`): o pp só aceita ali `ON`, `OFF` ou um macro
`&`. No result, `<(x)>` é o marker SMART-STRINGIFY (mkind `strsmart`): se o valor
for uma palavra "nua" ele a transforma em STRING (`ON` → `"ON"`); se vier entre
parênteses/expressão, passa o valor CRU (`(lFlag)` → `lFlag`). Depois, num
SEGUNDO passe, `_SET_EXACT` é um `#define` que vira `1` — por isso a saída final é
`Set( 1, "ON" )`. O `.ppt` mostra os dois passes empilhados.

**Para o programador Harbour.** Você escreve `SET EXACT ON` como se `ON` fosse
uma palavra-chave; na verdade o pp a captura como um valor restrito (só ON/OFF/&
são aceitos — escrever `SET EXACT TALVEZ` não casa a regra) e a converte na string
`"ON"`. Se você quiser passar uma variável em vez de ON/OFF, o idioma é o
parêntese: `SET EXACT (lMinhaFlag)` — aí o pp NÃO vira string, passa a variável.
É por isso que as duas formas existem: `SET EXACT ON` (palavra → string) e `SET
EXACT (expr)` (expressão → valor). O `_SET_EXACT` vira o número `1` porque é um
`#define` interno — o compilador nunca vê o nome, só o índice.

### Lente de refatoração (o que o hbrefactor faz aqui, por FATO)

`resolve-at` em cada posição de `SET EXACT ON`:

| posição | veredito do `resolve-at` | por quê |
|---|---|---|
| `SET` (7:4) | *palavra de regra de pp (#command SET, builtin)* | keyword do comando builtin |
| `EXACT` (7:8) | *palavra de regra de pp (#command SET, builtin)* | idem |
| `ON` (7:14) | *nome de marker (sem dona identificável)* | recheio do marker restrict |

A ferramenta identifica corretamente o papel de cada posição mesmo num comando
builtin do std.ch: as keywords `SET`/`EXACT` são palavras de uma regra builtin
(não se renomeiam — são do core, não do seu código); `ON` é recheio de marker.
Renomear qualquer uma não faz sentido aqui (é comando do core), e a ferramenta
não inventa uma ação — degrade honesto. O valor do corpus não é renomear std.ch;
é **provar que o FATO do dump descreve fielmente até as diretivas mais universais**
— o mesmo maquinário que refatora a SUA DSL lê o command-set do Clipper sem ajuste.
