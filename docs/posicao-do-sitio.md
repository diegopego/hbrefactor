# Como a posição de um sítio viaja — do lexer até o relato

*(escrito em 2026-08-06, na entrega da [P21](roadmap.md) / `ast-21`)*

Este documento explica **um mecanismo**, não uma fase. Ele existe porque a
pergunta *"de onde vem a coluna que o `usages` imprime?"* tem uma resposta longa,
e porque a resposta ERRADA para ela já foi implementada uma vez — de boa fé, e
com cara de fato. Quem for mexer nos canais de sítio do dump lê isto antes.

O **contrato** (o que o JSON diz, quais chaves são opcionais) mora em
[ast-schema.md](ast-schema.md) § `col` e `tokLine`. Aqui é o **porquê**.

---

## 1. O que é um sítio

Quando a ferramenta responde

```
p.prg:6: write (local) in MAIN  | nTotal := nTotal + nTotal
```

cada linha dessas é um **sítio**: uma ocorrência do nome no seu código. Quem sabe
que ela existe é o **compilador** — enquanto gera pcode, toda vez que resolve uma
variável ele anota um registro no dump. São três canais, um por natureza:

| canal | o que registra |
|---|---|
| `occurrences[]` | uso de variável (leitura, escrita, referência) |
| `calls[]` | chamada de função |
| `sends[]` | envio de mensagem (`o:Metodo`) |

Até o `ast-19`, os três traziam só a **linha**. E uma linha pode ter o mesmo nome
várias vezes:

```
   nTotal := nTotal + nTotal
   ^3        ^13      ^22
```

Três tokens, três colunas. Com só a linha, o consumidor não sabia qual registro
era qual, e resolvia todos pelo primeiro: um *find all references* apontava três
vezes para o mesmo lugar.

---

## 2. A armadilha: **ordem de redução ≠ ordem de escrita**

O `ast-20` tentou consertar por **contagem**: *"o K-ésimo registro deste nome
nesta linha é o K-ésimo token deste nome nesta linha."*

Parece razoável, e é o erro. Os dois lados dessa igualdade vêm de mundos
diferentes:

- **a ordem dos tokens** é a ordem em que o programador escreveu — esquerda para
  direita;
- **a ordem dos registros** é a ordem em que o compilador **anda na árvore**
  gerando código. Para gerar `a := b`, ele empilha o valor de `b` primeiro e só
  depois guarda em `a`. **O alvo da atribuição é o ÚLTIMO.**

Elas não têm nenhuma obrigação de coincidir. Medido:

```
nTotal := 0 + Eval( {| x | nTotal += x }, 1 ) + nTotal
   ^3                       ^30                  ^51
```

| ordem do registro | o que é | token de verdade |
|---|---|---|
| 1º `use` | a captura pelo codeblock | col **30** |
| 2º `ref` | a mesma captura, 2º registro | col **30** |
| 3º `read` | a leitura da ponta direita | col **51** |
| 4º `write` | o alvo da atribuição | col **3** |

Aplicando a contagem: 1º→col 3, 2º→col 30, 3º→col 51, e o 4º registro não acha um
4º token, então caía numa janela para trás e pegava o último visto (col 51).
Publicado: **3, 30, 51, 51** — dois de quatro errados, e o `write` (justamente o
lugar que um rename precisa tocar) apontando a leitura do outro extremo.

> **A lição, e ela é o argumento inteiro:** a contagem não estava *sempre*
> errada. Em `Dobro( Dobro( 2 ) ) + Dobro( 3 )` ela acertava as três colunas.
> **Esse é o problema.** Acertava umas, errava outras, e carimbava todas de
> `certainty: "confirmed"`. Um fato que às vezes está certo não é um fato — é um
> palpite bem-comportado. (É [§1.2 gatilho 3](../CLAUDE.md) em estado puro: *"se
> não é X, então é Y"* sem um fato que separe X de Y.)

---

## 3. A saída que NÃO serve, e por quê

A ideia óbvia é: *"o lexer guarda o índice do último IDENTIFIER que entregou, e o
nó pega esse número quando nasce."*

Não funciona, e o motivo tem nome: **lookahead**. O bison frequentemente precisa
ler o token *seguinte* antes de decidir qual regra reduzir. No instante em que o
nó nasce, o "último token entregue" já pode ser o próximo.

Medido em `FOR i := 1 TO 3` / `nSoma += i`: o nó `VARIABLE I` nasce com o contador
de tokens no `:=` (o nome é o token anterior); o nó `VARIABLE NSOMA` nasce no
`+=`; e a leitura de `i` nasce **no próprio nome**. Ora +1, ora +0, conforme o que
o parser precisou espiar.

> É por isto que o `nBirthTok` do nó (o contador no nascimento) **não serve** como
> posição, e nem como âncora para "procurar o nome por perto": seria a mesma
> adivinhação com raio menor.

---

## 4. O fato: a pilha de localizações do bison

O bison mantém, opcionalmente (`%locations`), uma **pilha de localizações
paralela à pilha de valores semânticos**. Ela existe exatamente para responder
*"de onde veio este símbolo"* — normalmente para mensagem de erro.

A entrega foi usar essa pilha guardando, em vez de linha/coluna, **o índice do
token**:

```c
/* include/hbcompdf.h */
typedef struct { HB_SIZE nTok; } HB_COMP_YYLTYPE;
```

O índice basta porque o dump **já registra todo token que o lexer puxa**, em
ordem, com arquivo, linha, coluna e procedência. Um índice nessa lista já é uma
posição completa.

E aí a cadeia fecha, cada elo com dono claro:

```
  lexer            entrega o token nº 12 e CARIMBA o símbolo
    │              hb_compAstTokMark()            complex.c
    ▼
  bison            carrega o carimbo na pilha de localizações,
    │              em passo com os valores semânticos
    ▼
  ação da regra    Variable : IdentName   →   @1 é o token nº 12
    │              HB_AST_AT( ..., @1 )           harbour.y
    ▼
  nó               guarda "meu nome está no token 12"
    │              HB_ASTNODE.nNameTok            compast.c
    ▼
  geração          marca em qual nó está andando
    │              HB_EXPR_USE → hb_compAstExprUse()
    ▼
  registro         lê o token do nó marcado → linha, coluna, arquivo
                   hb_compAstSiteTok()
```

**Nenhuma etapa adivinha**: cada uma repassa o que a anterior lhe deu.

### O custo que se temia, e que não existe por este caminho

A alternativa era estender o `YYSTYPE` do identificador. Ela assusta porque
`IDENTIFIER` é `<string>` e aparece em dezenas de regras — mudar o tipo obrigaria
a mexer em todo `$N` que o consome.

Como a posição viaja pela pilha de **localizações** e não pela de **valores**,
**nenhum `$N` mudou de tipo**. O `YYLLOC_DEFAULT` vira uma atribuição só, e a
pilha cresce 8 bytes por símbolo.

*(E o `YYSTYPE` não serviria nem com o esforço: o identificador é `char *`
**internado** — a mesma string é compartilhada por todas as ocorrências do nome,
então pendurar posição nela não distingue ocorrência nenhuma.)*

---

## 5. Os três lugares onde a cadeia se rompe (e o conserto de cada um)

Todos foram encontrados pelo **silêncio**: onde o desenho antigo chutava, o novo
deixa o fato **ausente**. Aí é só seguir a ausência.

**(a) A geração lê o nome de OUTRO nó.** As otimizações de operador
(`x := x + y` → `x += y`, `x++`, …) leem o nome direto do operando esquerdo
enquanto a marca está no nó do operador. Conserto: aqueles pontos dizem de quem é
o sítio — `hb_compAstVarFind()`.

**(b) A chamada otimizada.** Mesmo padrão: o nó da chamada lê o nome do nó do
callee em vez de andar nele. Conserto: `HB_AST_SITE_BEGIN`/`_END`.

**(c) A mensagem escrita como atribuição.** `o:X := v` é registrada sob `_X` — um
nome que o **próprio compilador** inventa — enquanto o token do fonte diz `X`.
Desfazer esse prefixo é o compilador lendo o **próprio registro**, não chutando
sobre o código do usuário. (Comparação por ponteiro: identificadores são
internados.)

---

## 6. O operando que a otimização engolia

Caso à parte, e o mais sutil. O compilador reescreve

```
nTotal := nTotal + nB     →     nTotal += nB
```

e, para isso, **libera o nó do `nTotal` do meio** no reduce
(`hb_compExprUseAssign`, `HB_EA_REDUCE`). O pcode fica certo. Mas a geração nunca
vê aquele nó, então **nenhum sítio era anotado para ele** — e o registro do FONTE
ficava sem um nome que o programador escreveu.

Sob a contagem do `ast-20` isso ficava escondido: havia 3 registros e 3 tokens, e
casar um a um *parecia* certo. Não era — os dois primeiros registros descrevem o
alvo, e o token do meio não tinha registro nenhum.

**Decisão do Diego (2026-07-27): estender o core**, porque *perder uma ocorrência
escrita num find-all-references é regressão de produto* — quem renomeia precisa
dos três tokens. `hb_compAstFoldedRead()` anota a leitura antes do descarte:

```
read  col 13   ← o operando que a otimização dobra
use   col 3    ← o alvo, lido-e-escrito no lugar
ref   col 3    ← o mesmo token, segundo registro
read  col 22   ← a ponta direita
```

Quatro registros para três tokens. O alvo aparecendo **duas vezes no mesmo
token** é a mesma forma da captura por codeblock, que já era contrato.

---

## 7. Quando o fato é AUSENTE — e isso é comum

Sem token escrito **neste módulo**, não há posição, e a resposta certa é não ter
nenhuma (range de largura zero), nunca procurar "um token com este nome nesta
linha" — a linha pode ter um homônimo que nada tem a ver com aquele sítio.

Acontece em três situações:

- **nome vindo de diretiva/include** (`#xcommand … => nAcc += <v>`): o token
  existe, mas no `.ch`, e o core descarta coluna de outro arquivo. Medido no
  `tbrowse.prg` do core: **40,3% dos sítios** — não é canto, é quase metade da
  resposta, porque código Harbour real se constrói sobre DSL. É o assunto da
  **[P24](roadmap.md)**;
- **símbolo entregue por macro**, cuja posição o pp não tem (P18);
- **nome que o compilador inventa** (enumerador de `FOR EACH`, `Self` implícito),
  que ninguém escreveu.

---

## 8. Se você for mexer nisto

- **Achado de posição num canal é achado de CLASSE**: varra os outros dois no
  mesmo passo, e depois varra de novo procurando outra **natureza** de erro no
  mesmo lugar. Foram três achados em cascata na P20, e só o primeiro veio de um
  teste — os outros dois vieram de perguntar *"onde mais?"*.
- **`line` nunca muda de significado**: é a linha em que o compilador estava ao
  registrar. Quem correlaciona canais por ela continua funcionando. Quem quer o
  **lugar** lê `(hb_HGetDef(h,"tokLine",h["line"]), col)`.
- **Buildar o core é `make core`** — nunca incremental ([CLAUDE.md §2](../CLAUDE.md)).
  Mexer em header e rodar `make` sai **exit 0 sem recompilar nada**, e a medição
  seguinte responde do binário velho. Confira com `make core-check` antes de
  confiar em qualquer medida.
