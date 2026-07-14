<!-- guarda: corpus_instrument -->
# Família O PP COMO INSTRUMENTO — os canais do core, e o que cada um dá

Índice: [README.md](README.md). Ensina: **o pp não é só uma fonte de fato — é um
motor que já roda em todo build.** Esta família cataloga os canais pelos quais o
core te deixa *usar* o pp, o que cada um entrega e **o que cada um destrói**.
Registro de fase: [spec-p § P7](../spec-p-pp-refatoracao.md).

> **Aviso de método (a lição mais cara desta fase):** eu **recusei** "o pp como
> motor de reescrita" olhando só um canal (`.ppo`) e declarei impossibilidade —
> veredito ERRADO, publicado. O Diego apontou `tests/hbpp/hbpptest.prg` e o
> `__pp_process` derrubou a premissa. **Antes de dizer "o pp não consegue X",
> varra a superfície inteira:** `--help` do `harbour`/`hbmk2`, a API pública
> (`include/hbpp.h`), e sobretudo os **`tests/` do core** — é lá que a API viva
> aparece.

---

## Catálogo dos canais

| canal | o que dá | o que DESTRÓI / limita |
|---|---|---|
| `-p` → **`.ppo`** | o módulo **inteiro** expandido | **comentários, `#include`, formatação** — irreversível |
| `-p+` → **`.ppt`** | o **traço** passo a passo, anotado por linha-fonte | é TEXTO, sem identidade estável de token |
| `-u` | **isola**: aplica só as SUAS regras, deixa o resto da linguagem em paz | ainda passa pelo `.ppo` (mesma destruição) |
| `-gd` (+ `-sm`) | **lista de dependências** (`.d`): quais includes o módulo usou, com o **caminho onde achou**, fecho transitivo | grava o `.d` no **CWD** (não ao lado do fonte) — use `-o<dir>` |
| `-x` → **dump AST** | o rastro estruturado (`ppRules`/`ppApplications`/`from`) | é o canal do hbrefactor; descreve o que **casou**, não o que casaria |
| **`__pp_init` / `__pp_process`** | o pp **vivo, em processo, LINHA A LINHA**, dirigido por código Harbour | destrói **o que você ALIMENTA** (comentário da linha entra no pp e não volta) — nada mais |

---

## 1. `.ppo` — o expandido. Ótimo oráculo, **péssimo escritor**

```
$ harbour app.prg -p -u -I.      # -u: só as MINHAS regras
```

Com `-u` o isolamento é real: `ANTIGO Alfa COM nX` vira `MODERNO Alfa VALOR nX`,
e `? "oi"` **não** vira `QOut( "oi" )` — o resto da linguagem passa intacto.

Mas o `.ppo` guarda **o código e só o código**. Medido num fonte de 11 linhas com
4 comentários:

| | fonte | `.ppo` (mesmo com `-u`) |
|---|---|---|
| comentários | 4 | **0** |
| `#include` | sim | **destruído** |
| formatação | do autor | normalizada |

**Veredito: o `.ppo` NÃO pode ser a fonte de um arquivo que a ferramenta grava.**
Colide com o contrato do hbrefactor (o caso 107 exige *"comentário com o nome velho
INTACTO"*) e com a regra fundadora (**nunca editar o não-verificável**).

## 2. `.ppo` + `.hrb` como ORÁCULO DE EQUIVALÊNCIA — já em produção

O papel em que o `.ppo` é excelente é o de **juiz**, não de escriba. O padrão-ouro
do `rename-dsl` (e do `rename-rule-marker`):

> *edita → re-preprocessa → o `.ppo` e o `.hrb` de TODOS os módulos têm de sair
> **byte-idênticos**; qualquer diferença = **rollback**.*

Para um alpha-rename (trocar o nome de um marker, que é variável local da regra)
isso é a prova perfeita: a mudança **não pode** ser observável.

## 3. `-gd` — quais includes o projeto usa (a pergunta que o dump não responde bem)

```
$ harbour m.prg -sm -gd -Iinc
$ cat m.d
m.c: m.prg inc/far.ch          ← o caminho ONDE ACHOU, não o `far.ch` cru
```

- dá o **caminho resolvido** — a resolução é do **CORE**; quem consome não
  re-implementa a busca de include;
- dá o **fecho transitivo** (include de include entra);
- `-sm` = syntax check mínimo, sem codegen.

**Armadilha:** o `.d` vai para o **CWD**, não para o lado do fonte (ao contrário do
`.ppo`). Adivinhar o destino deixa lixo no projeto e devolve vazio para fonte em
subdiretório. Mande-o para onde você quer: **`-o<tmp>`**.

## 4. `__pp_init` / `__pp_process` — o pp VIVO (a fronteira)

Fonte: **`harbour-core/harbour/tests/hbpp/hbpptest.prg`**.

```harbour
pp := __pp_init()
__pp_process( pp, '#xtranslate AAA [A <a> [B <b>] ] => Qout([<a>][, <b>])' )
// ...e daí em diante cada LINHA alimentada volta TRANSFORMADA
```

É o pp do core **em processo**, alimentado linha a linha, com o conjunto de regras
que **você** registrar.

**Por que isso é grande:** derruba a premissa da recusa do § 1. O `.ppo` destrói
comentários porque é o canal de **arquivo** (`-p` despeja o módulo inteiro) — não
porque o pp destrói. Com `__pp_process` a ferramenta escolhe **o que** alimentar
(só a statement do site, cujas posições ela já tem do dump) e recebe **só aquilo**
transformado: o resto do arquivo **nunca passa pelo pp**, logo não pode ser
destruído.

"O pp calcula o QUE, a ferramenta escreve o ONDE" deixa de exigir o desenho
indireto `-u` + `.ppo` e vira uma **chamada direta ao motor do core**.

### A API, mapeada (P11)

| função | contrato |
|---|---|
| `__pp_init( [cIncPath], [cStdCh], [lArchDefs] ) --> pPP` | novo estado. `cStdCh = ""` → **nenhuma** regra padrão (só os defines dinâmicos); `lArchDefs = .F.` → nem esses. É o **isolamento total** |
| `__pp_addRule( pPP, cDiretiva ) --> lOK` | registra uma diretiva (tem de começar com `#`) |
| `__pp_process( pPP, cLinha ) --> cLinhaTransformada` | **uma linha** entra, a linha **transformada** sai. Diretiva também vai por aqui |
| `__pp_reset( pPP )` / `__pp_path( pPP, cPath )` | zera as regras / acrescenta caminho de include |

### EQUIVALÊNCIA com o pp do build — **PROVADA** (`make ppcorpus`)

Mesma regra, mesmo site: o pp vivo devolve `MODERNO Alfa VALOR nX` — **o mesmo
texto** que o `.ppo` do build produz. É o mesmo motor, não uma imitação.

### O limite honesto: o pp destrói **o que você ALIMENTA** (não "o arquivo")

Aqui a lição do P7 fica afiada. Alimentando a **linha inteira**:

```
'ANTIGO Alfa COM nX   // manter!'   -->   'MODERNO Alfa VALOR nX'
```

O comentário **morreu**. Ou seja: o pp *come comentário*, sim — mas só o da linha
que entra nele. O `.ppo` apaga o arquivo todo porque **alimenta o arquivo todo**.

Daí a **regra do escritor**, e é ela que separa o viável do recusado:

> **alimente o SPAN da statement** (as posições de byte a ferramenta já tem do
> dump) e **grave só aquele span**. Tudo que está fora — o comentário de fim de
> linha, o resto do arquivo — **nunca passa pelo pp**, logo não pode ser destruído.

Com isso, *"o pp calcula o QUE, a ferramenta escreve o ONDE"* deixa de ser desenho
indireto (`-u` + `.ppo`) e vira **chamada direta ao motor do core**.

### Consumidor #1 já em produção: a ambiguidade de cabeça (P11, caso 116)

*"O nome NOVO colidiria com a cabeça de outra regra sob abreviação dBase?"* é
predição de casamento **FUTURO** — o dump descreve o que **casou**, não o que
casaria. Era o último pedaço de **gramática replicada** na ferramenta
(`ppcore.c`, o `>= 4`). Agora **pergunta-se ao pp**: registra-se num pp isolado uma
**regra-sonda** com aquela cabeça e aquele tipo, alimenta-se a grafia e vê-se se
saiu transformada. Zero aritmética. Detalhes e o furo que isso fechou:
[abbreviation.md](abbreviation.md).

---

## Lacunas (VERIFICADO)

- **[Consumo futuro]** `hb_compileFromBuf` (fichado na
  [spec-b8](../spec-b8-macros.md)) segue sem consumidor: o P11 precisou do **pp**,
  não do compilador inteiro em buffer.
- **[Consumo futuro]** O que o pp vivo NÃO devolve: **posição** e **erro**. O
  `__pp_process` entrega texto — quem quiser *onde casou* usa o dump
  (`ppApplications`), não esta API. É o que a fatia **P12**
  ([pp-as-search.md](pp-as-search.md)) terá de resolver para virar busca.
- **[Fato, não lacuna]** `.ppt` é **traço**, não grafo: prova que a informação
  existe no pp, mas é texto sem identidade estável de token entre passes. Quem
  precisa de estrutura usa o `from` (ast-3), não re-roteia o `.ppt`.
